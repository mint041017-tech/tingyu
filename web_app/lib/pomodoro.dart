import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'audio/nook_controller.dart';
import 'platform/pomodoro_platform.dart';

enum PomoPhase {
  focus('专注', '把眼前这一件事，做完就好。'),
  shortBreak('短休息', '起身走走，看看远处。'),
  longBreak('长休息', '这次多歇一会儿，别急着回来。');

  final String label;
  final String hint;
  const PomoPhase(this.label, this.hint);

  static PomoPhase parse(Object? value) => switch (value) {
    'shortBreak' => PomoPhase.shortBreak,
    'longBreak' => PomoPhase.longBreak,
    _ => PomoPhase.focus,
  };
}

class PomoSettings {
  int focusMinutes;
  int shortMinutes;
  int longMinutes;
  int longEvery;
  int chimeVolume;
  String chimeKind;
  bool autoStart;
  bool playWithFocus;
  bool pauseOnBreak;
  bool chime;
  bool notify;

  PomoSettings({
    this.focusMinutes = 25,
    this.shortMinutes = 5,
    this.longMinutes = 15,
    this.longEvery = 4,
    this.chimeVolume = 55,
    this.chimeKind = 'bell',
    this.autoStart = false,
    this.playWithFocus = true,
    this.pauseOnBreak = true,
    this.chime = true,
    this.notify = false,
  });

  factory PomoSettings.fromJson(Map<String, dynamic>? json) {
    final s = PomoSettings();
    if (json == null) return s;
    int pick(Object? value, int fallback, int min, int max) =>
        value is num ? value.round().clamp(min, max) : fallback;
    s.focusMinutes = pick(json['focus'], 25, 1, 180);
    s.shortMinutes = pick(json['short'], 5, 1, 60);
    s.longMinutes = pick(json['long'], 15, 1, 120);
    s.longEvery = pick(json['longEvery'], 4, 2, 8);
    s.chimeVolume = pick(json['chimeVolume'], 55, 0, 100);
    s.chimeKind = json['chimeKind'] == 'wood' ? 'wood' : 'bell';
    s.autoStart = json['autoStart'] == true;
    s.playWithFocus = json['playWithFocus'] != false;
    s.pauseOnBreak = json['pauseOnBreak'] != false;
    s.chime = json['chime'] != false;
    s.notify = json['notify'] == true;
    return s;
  }

  Map<String, dynamic> toJson() => {
    'focus': focusMinutes,
    'short': shortMinutes,
    'long': longMinutes,
    'longEvery': longEvery,
    'chimeVolume': chimeVolume,
    'chimeKind': chimeKind,
    'autoStart': autoStart,
    'playWithFocus': playWithFocus,
    'pauseOnBreak': pauseOnBreak,
    'chime': chime,
    'notify': notify,
  };

  PomoSettings copy() => PomoSettings.fromJson(toJson());
}

class PomoSession {
  final DateTime at;
  final int minutes;
  const PomoSession(this.at, this.minutes);

  Map<String, dynamic> toJson() => {
    't': at.millisecondsSinceEpoch,
    'm': minutes,
  };

  static PomoSession? fromJson(Object? value) {
    if (value is! Map) return null;
    final t = value['t'];
    final m = value['m'];
    if (t is! num || m is! num) return null;
    return PomoSession(
      DateTime.fromMillisecondsSinceEpoch(t.toInt()),
      m.round().clamp(1, 180),
    );
  }
}

/// 番茄钟状态机：真实结束时间驱动，刷新/切后台后仍能对齐；
/// 完成时优先用网页提示音与系统通知，二者都不可用时仍有页内提示。
class PomodoroController extends ChangeNotifier with WidgetsBindingObserver {
  final NookController nook;
  PomoSettings settings = PomoSettings();
  PomoPhase phase = PomoPhase.focus;
  Duration remaining = const Duration(minutes: 25);
  bool running = false;
  bool completed = false;
  int focusInCycle = 0;
  int completionTick = 0;
  String? lastEvent;
  List<PomoSession> sessions = [];
  String notificationPermission = 'default';
  DateTime? _endAt;
  Timer? _ticker;
  int _lastSecond = -1;
  bool _disposed = false;

  PomodoroController(this.nook) {
    WidgetsBinding.instance.addObserver(this);
    _restore();
    notificationPermission = PomodoroPlatform.permission;
  }

  Duration get phaseLength => Duration(
    minutes: switch (phase) {
      PomoPhase.focus => settings.focusMinutes,
      PomoPhase.shortBreak => settings.shortMinutes,
      PomoPhase.longBreak => settings.longMinutes,
    },
  );

  double get progress {
    final total = phaseLength.inMilliseconds;
    if (total <= 0) return 1;
    return (1 - remaining.inMilliseconds / total).clamp(0.0, 1.0);
  }

  String get clock => _clock(remaining.inSeconds);

  String get statusLabel {
    if (completed) return '${phase.label}完成';
    if (running) return '${phase.label}中';
    if (remaining < phaseLength) return '已暂停';
    return '准备开始';
  }

  String get cycleLabel {
    final current = phase == PomoPhase.longBreak
        ? settings.longEvery
        : (focusInCycle % settings.longEvery) + 1;
    return '第 $current / ${settings.longEvery} 轮';
  }

  String? get nextHint {
    final next = _nextAfter(phase);
    if (next == null) return null;
    final minutes = _minutesOf(next);
    return '下一阶段：${next.label} $minutes 分钟';
  }

  int get todayCount => _todaySessions.length;
  int get todayMinutes =>
      _todaySessions.fold<int>(0, (sum, s) => sum + s.minutes);

  List<PomoSession> get _todaySessions {
    final now = DateTime.now();
    return sessions
        .where(
          (s) =>
              s.at.year == now.year &&
              s.at.month == now.month &&
              s.at.day == now.day,
        )
        .toList();
  }

  List<int> get weekMinutes {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List<int>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return sessions
          .where(
            (s) =>
                s.at.year == day.year &&
                s.at.month == day.month &&
                s.at.day == day.day,
          )
          .fold<int>(0, (sum, s) => sum + s.minutes);
    });
  }

  int get streakDays {
    if (sessions.isEmpty) return 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    bool has(DateTime d) => sessions.any(
      (s) => s.at.year == d.year && s.at.month == d.month && s.at.day == d.day,
    );
    if (!has(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (has(day) && count < 365) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  String get nextButtonLabel {
    if (completed) {
      final next = _nextAfter(phase);
      return next == PomoPhase.focus ? '开始下一轮' : '开始休息';
    }
    if (running) return '暂停';
    if (remaining < phaseLength) return '继续${phase.label}';
    return phase == PomoPhase.focus ? '开始专注' : '开始休息';
  }

  VoidCallback get toggle => running ? pause : start;

  void _restore() {
    try {
      final raw = nook.readValue('pomodoro');
      if (raw.isEmpty) return;
      final value = jsonDecode(raw);
      if (value is! Map) return;
      final json = Map<String, dynamic>.from(value);
      settings = PomoSettings.fromJson(
        json['settings'] is Map
            ? Map<String, dynamic>.from(json['settings'] as Map)
            : null,
      );
      phase = PomoPhase.parse(json['phase']);
      focusInCycle = ((json['focusInCycle'] as num?) ?? 0).round().clamp(
        0,
        settings.longEvery,
      );
      final rawSessions = json['sessions'];
      if (rawSessions is List) {
        sessions = rawSessions
            .map(PomoSession.fromJson)
            .whereType<PomoSession>()
            .where(
              (s) => DateTime.now().difference(s.at).inDays <= 120,
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
      }
      completed = json['completed'] == true;
      final stored = (json['remaining'] as num?)?.round() ?? phaseLength.inSeconds;
      remaining = Duration(seconds: stored.clamp(0, phaseLength.inSeconds));
      if (json['running'] == true) {
        final end = json['endAt'];
        if (end is num) {
          final endAt = DateTime.fromMillisecondsSinceEpoch(end.toInt());
          final left = endAt.difference(DateTime.now());
          if (left > Duration.zero) {
            _endAt = endAt;
            remaining = left;
            running = true;
            completed = false;
            _startTicker();
            _updateTitle();
          } else {
            running = false;
            completed = true;
            remaining = Duration.zero;
          }
        }
      }
    } catch (_) {
      // 损坏的本地记录不阻塞计时器使用。
    }
  }

  void _persist() {
    if (_disposed) return;
    nook.persist('pomodoro', {
      'settings': settings.toJson(),
      'phase': phase.name,
      'remaining': remaining.inSeconds,
      'running': running,
      'endAt': _endAt?.millisecondsSinceEpoch,
      'completed': completed,
      'focusInCycle': focusInCycle,
      'sessions': sessions.take(400).map((s) => s.toJson()).toList(),
    });
  }

  void start() {
    if (running) return;
    if (remaining <= Duration.zero) {
      completed = false;
      remaining = phaseLength;
    }
    running = true;
    _endAt = DateTime.now().add(remaining);
    _lastSecond = -1;
    _startTicker();
    _updateTitle();
    if (phase == PomoPhase.focus) unawaited(_playForFocus());
    _scheduleNotification();
    _persist();
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    remaining = _left();
    running = false;
    _endAt = null;
    _ticker?.cancel();
    _ticker = null;
    unawaited(PomodoroPlatform.cancelScheduledNotification());
    _updateTitle();
    _persist();
    notifyListeners();
  }

  void reset() {
    running = false;
    completed = false;
    _endAt = null;
    _ticker?.cancel();
    _ticker = null;
    unawaited(PomodoroPlatform.cancelScheduledNotification());
    remaining = phaseLength;
    _updateTitle();
    _persist();
    notifyListeners();
  }

  void switchPhase(PomoPhase next, {bool silent = false}) {
    if (next == phase) return;
    running = false;
    completed = false;
    _endAt = null;
    _ticker?.cancel();
    _ticker = null;
    if (phase == PomoPhase.longBreak && next == PomoPhase.focus) {
      focusInCycle = 0;
    }
    phase = next;
    remaining = phaseLength;
    unawaited(PomodoroPlatform.cancelScheduledNotification());
    _updateTitle();
    if (!silent) {
      lastEvent = '已切换到${phase.label}';
      completionTick++;
    }
    _persist();
    notifyListeners();
  }

  void skip() {
    running = false;
    _endAt = null;
    _ticker?.cancel();
    _ticker = null;
    final next = _nextAfter(phase);
    if (next == null) return;
    if (phase == PomoPhase.longBreak) focusInCycle = 0;
    phase = next;
    completed = false;
    unawaited(PomodoroPlatform.cancelScheduledNotification());
    remaining = phaseLength;
    lastEvent = '已跳到${phase.label}';
    completionTick++;
    _updateTitle();
    _persist();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _sync());
  }

  void _sync() {
    if (_disposed) return;
    final left = _left();
    if (left <= Duration.zero) {
      remaining = Duration.zero;
      _finishPhase();
      return;
    }
    final second = left.inSeconds;
    if (second != _lastSecond) {
      _lastSecond = second;
      remaining = Duration(seconds: second);
      _updateTitle();
      notifyListeners();
    }
  }

  Duration _left() {
    final end = _endAt;
    if (!running || end == null) return remaining;
    final left = end.difference(DateTime.now());
    return left > Duration.zero ? left : Duration.zero;
  }

  void _finishPhase() {
    final finished = phase;
    running = false;
    completed = true;
    _endAt = null;
    _ticker?.cancel();
    _ticker = null;
    completionTick++;

    if (finished == PomoPhase.focus) {
      sessions.insert(0, PomoSession(DateTime.now(), settings.focusMinutes));
      sessions = sessions.take(400).toList();
      focusInCycle = (focusInCycle + 1).clamp(0, settings.longEvery);
      final long = focusInCycle >= settings.longEvery;
      phase = long ? PomoPhase.longBreak : PomoPhase.shortBreak;
      lastEvent = '专注完成，${long ? '好好休息一会儿' : '起来走一走'}。';
      if (settings.pauseOnBreak && nook.playing) unawaited(nook.send('pause'));
    } else {
      if (finished == PomoPhase.longBreak) focusInCycle = 0;
      phase = PomoPhase.focus;
      lastEvent = '休息结束，回来继续吧。';
    }
    remaining = phaseLength;
    completed = false;
    _alert(finished);
    _updateTitle();
    _persist();
    notifyListeners();

    if (settings.autoStart) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!_disposed && !running) start();
      });
    }
  }

  void _alert(PomoPhase finished) {
    if (settings.chime && settings.chimeVolume > 0) {
      unawaited(PomodoroPlatform.chime(settings.chimeKind, settings.chimeVolume));
    }
    unawaited(PomodoroPlatform.vibrate());
    if (settings.notify &&
        notificationPermission == 'granted' &&
        !PomodoroPlatform.supportsScheduling) {
      final body = finished == PomoPhase.focus
          ? '专注完成，休息一下。'
          : '休息结束，开始下一轮专注吧。';
      unawaited(
        PomodoroPlatform.notifyNow('听隅 · ${finished.label}结束', body),
      );
    }
  }

  void _scheduleNotification() {
    if (!settings.notify || notificationPermission != 'granted') return;
    final end = _endAt;
    if (end == null || !PomodoroPlatform.supportsScheduling) return;
    final body = phase == PomoPhase.focus ? '专注完成，休息一下。' : '休息结束，开始下一轮专注吧。';
    unawaited(
      PomodoroPlatform.scheduleNotification(
        end,
        '听隅 · ${phase.label}结束',
        body,
      ),
    );
  }

  Future<void> _playForFocus() async {
    if (!settings.playWithFocus || nook.tracks.isEmpty || nook.playing) return;
    await nook.send('play');
  }

  PomoPhase? _nextAfter(PomoPhase current) {
    if (current == PomoPhase.focus) {
      final long = focusInCycle + 1 >= settings.longEvery;
      return long ? PomoPhase.longBreak : PomoPhase.shortBreak;
    }
    return PomoPhase.focus;
  }

  int _minutesOf(PomoPhase p) => switch (p) {
    PomoPhase.focus => settings.focusMinutes,
    PomoPhase.shortBreak => settings.shortMinutes,
    PomoPhase.longBreak => settings.longMinutes,
  };

  Future<String> requestNotifications() async {
    final value = await PomodoroPlatform.requestNotificationPermission();
    notificationPermission = value;
    if (value == 'granted' && running) _scheduleNotification();
    notifyListeners();
    return value;
  }

  void setNotify(bool value) {
    settings.notify = value;
    if (value && notificationPermission == 'default') {
      unawaited(requestNotifications());
    }
    if (!value) {
      unawaited(PomodoroPlatform.cancelScheduledNotification());
    } else if (running) {
      _scheduleNotification();
    }
    _persist();
    notifyListeners();
  }

  void setChime(bool value) {
    settings.chime = value;
    _persist();
    notifyListeners();
  }

  void setChimeKind(String kind) {
    settings.chimeKind = kind == 'wood' ? 'wood' : 'bell';
    chimePreview();
    _persist();
    notifyListeners();
  }

  void setChimeVolume(int value) {
    settings.chimeVolume = value.clamp(0, 100);
    _persist();
    notifyListeners();
  }

  void chimePreview() {
    unawaited(PomodoroPlatform.chime(settings.chimeKind, settings.chimeVolume));
  }

  void setAutoStart(bool value) {
    settings.autoStart = value;
    _persist();
    notifyListeners();
  }

  void setPlayWithFocus(bool value) {
    settings.playWithFocus = value;
    _persist();
    notifyListeners();
  }

  void setPauseOnBreak(bool value) {
    settings.pauseOnBreak = value;
    _persist();
    notifyListeners();
  }

  void setLongEvery(int value) {
    settings.longEvery = value.clamp(2, 8);
    focusInCycle = focusInCycle.clamp(0, settings.longEvery);
    _persist();
    notifyListeners();
  }

  void setDuration(PomoPhase target, int minutes) {
    switch (target) {
      case PomoPhase.focus:
        settings.focusMinutes = minutes.clamp(1, 180);
        break;
      case PomoPhase.shortBreak:
        settings.shortMinutes = minutes.clamp(1, 60);
        break;
      case PomoPhase.longBreak:
        settings.longMinutes = minutes.clamp(1, 120);
        break;
    }
    if (phase == target && !running) {
      completed = false;
      remaining = phaseLength;
    }
    _persist();
    notifyListeners();
  }

  void clearHistory() {
    sessions = [];
    focusInCycle = 0;
    completionTick++;
    lastEvent = '专注记录已清空。';
    _persist();
    notifyListeners();
  }

  void _updateTitle() {
    unawaited(
      PomodoroPlatform.setTitle(
        running
            ? '听隅 · ${phase.label} $clock'
            : '听隅 · 给自己，留一小片安静',
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && running) _sync();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _updateTitle();
    super.dispose();
  }

  static String _clock(int seconds) {
    final n = seconds.clamp(0, 86399);
    final h = n ~/ 3600;
    final m = (n % 3600) ~/ 60;
    final s = n % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
