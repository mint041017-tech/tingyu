import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:window_manager/window_manager.dart';
import 'audio/nook_controller.dart';
import 'brand.dart';
import 'models.dart';
import 'motion.dart';
import 'platform/pomodoro_platform.dart';
import 'pomodoro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await PomodoroPlatform.init();
  if ((defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 860),
      minimumSize: Size(820, 620),
      center: true,
      title: '听隅',
      backgroundColor: Color(0xfff7f4ed),
    );
    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }
  final controller = NookController();
  await controller.bootstrap();
  runApp(NookApp(controller: controller));
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(controller.initialize()),
  );
}

class Palette {
  final bool dark;
  const Palette(this.dark);
  static Palette of(BuildContext context) =>
      Palette(Theme.of(context).brightness == Brightness.dark);
  Color get bg => dark ? const Color(0xff191f1c) : const Color(0xfff7f4ed);
  Color get surface => dark ? const Color(0xff242d27) : const Color(0xfffffdf8);
  Color get subtle => dark ? const Color(0xff303a32) : const Color(0xffedefe5);
  Color get text => dark ? const Color(0xffe5ebde) : const Color(0xff35433e);
  Color get muted => dark ? const Color(0xffa8b5a6) : const Color(0xff647066);
  Color get accent => dark ? const Color(0xffaac4a2) : const Color(0xff4f6957);
  Color get onAccent =>
      dark ? const Color(0xff1e2b20) : const Color(0xfffffdf8);
  Color get soft => dark ? const Color(0xff354b39) : const Color(0xffe4eadd);
  Color get border => dark ? const Color(0xff465248) : const Color(0xffd7ded2);
  Color get warning => dark ? const Color(0xffd3b77e) : const Color(0xff82602f);
  Color get error => dark ? const Color(0xffe8a49b) : const Color(0xff9a4944);
}

Color categoryColor(String category, bool dark) => switch (category) {
  '雨声' => dark ? const Color(0xff9fb0bd) : const Color(0xff6d8090),
  '森林' => dark ? const Color(0xffa9bf9e) : const Color(0xff70896a),
  '水流' => dark ? const Color(0xffa3c0c3) : const Color(0xff78969a),
  '风铃' => dark ? const Color(0xffd8c58f) : const Color(0xffb39a5d),
  '水下' => dark ? const Color(0xff93a9b8) : const Color(0xff5c7180),
  '城市' => dark ? const Color(0xffc3b8a8) : const Color(0xff8e8579),
  '篝火' => dark ? const Color(0xffd9a582) : const Color(0xffb87a55),
  '噪声' => dark ? const Color(0xffb4bcae) : const Color(0xff7d857a),
  '本地' => dark ? const Color(0xffaac4a2) : const Color(0xff4f6957),
  _ => dark ? const Color(0xffaac4a2) : const Color(0xff4f6957),
};

IconData categoryIcon(String category) => switch (category) {
  '雨声' => Icons.water_drop_outlined,
  '森林' => Icons.forest_outlined,
  '水流' => Icons.waves_outlined,
  '风铃' => Icons.wind_power_outlined,
  '水下' => Icons.bubble_chart_outlined,
  '城市' => Icons.location_city_outlined,
  '篝火' => Icons.local_fire_department_outlined,
  '噪声' => Icons.graphic_eq_outlined,
  '本地' => Icons.audio_file_outlined,
  _ => Icons.graphic_eq_outlined,
};

Color pomoPhaseColor(Palette p, PomoPhase phase) => switch (phase) {
  PomoPhase.focus => p.accent,
  PomoPhase.shortBreak => p.warning,
  PomoPhase.longBreak => p.dark
      ? const Color(0xffa3c0c3)
      : const Color(0xff5d7b80),
};

IconData pomoPhaseIcon(PomoPhase phase) => switch (phase) {
  PomoPhase.focus => Icons.center_focus_strong_outlined,
  PomoPhase.shortBreak => Icons.local_cafe_outlined,
  PomoPhase.longBreak => Icons.nightlight_outlined,
};

class NookApp extends StatelessWidget {
  final NookController controller;
  const NookApp({super.key, required this.controller});

  ThemeData theme(bool dark) {
    final p = Palette(dark);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.accent,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: p.accent,
          onPrimary: p.onAccent,
          surface: p.surface,
          onSurface: p.text,
          outline: p.border,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: controller.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: p.text, fontSize: 16, height: 1.5),
        bodySmall: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
      ),
      dividerColor: p.border,
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NookPageTransitionsBuilder(),
          TargetPlatform.iOS: NookPageTransitionsBuilder(),
          TargetPlatform.macOS: NookPageTransitionsBuilder(),
          TargetPlatform.windows: NookPageTransitionsBuilder(),
          TargetPlatform.linux: NookPageTransitionsBuilder(),
          TargetPlatform.fuchsia: NookPageTransitionsBuilder(),
        },
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          overlayColor: p.onAccent.withValues(alpha: .12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: controller.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: p.text,
          overlayColor: p.accent.withValues(alpha: .08),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: TextStyle(
            fontFamily: controller.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: p.accent,
          overlayColor: p.accent.withValues(alpha: .08),
          textStyle: TextStyle(
            fontFamily: controller.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: p.muted,
          overlayColor: p.accent.withValues(alpha: .08),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: .1),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        hintStyle: TextStyle(color: p.muted, fontSize: 15),
        labelStyle: TextStyle(color: p.muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.text,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: p.bg,
          fontFamily: controller.fontFamily,
          fontSize: 12,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.border),
        ),
        textStyle: TextStyle(
          color: p.text,
          fontFamily: controller.fontFamily,
          fontSize: 15,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(
          color: p.bg,
          fontFamily: controller.fontFamily,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '听隅 · 给自己，留一小片安静。',
      theme: theme(false),
      darkTheme: theme(true),
      themeMode: switch (controller.theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      themeAnimationDuration: NookMotion.base,
      themeAnimationCurve: NookMotion.standard,
      builder: (context, child) {
        final p = Palette.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: p.bg,
            statusBarIconBrightness: p.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: p.dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: p.bg,
            systemNavigationBarIconBrightness: p.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: NookHome(controller: controller),
    ),
  );
}

class NookHome extends StatefulWidget {
  final NookController controller;
  const NookHome({super.key, required this.controller});
  @override
  State<NookHome> createState() => _NookHomeState();
}

class _NookHomeState extends State<NookHome> {
  NookController get c => widget.controller;
  late final PomodoroController pomo;
  int page = 0;
  int previousPage = 0;
  int _lastPomoTick = 0;
  bool _introVisible = true;
  bool _introMounted = true;
  String category = '全部';
  String query = '';
  final search = TextEditingController();
  static const nav = ['此刻', '专注', '声音', '收藏', '设置'];
  static const navIcons = [
    Icons.grid_view_outlined,
    Icons.timer_outlined,
    Icons.graphic_eq_outlined,
    Icons.bookmark_border_rounded,
    Icons.tune_rounded,
  ];

  @override
  void initState() {
    super.initState();
    pomo = PomodoroController(c);
    pomo.addListener(_onPomodoro);
    if (_introMounted) unawaited(_armNativeIntro());
  }

  Future<void> _armNativeIntro() async {
    if ((defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      for (var i = 0; i < 80; i++) {
        try {
          if (await windowManager.isVisible()) break;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _introVisible = false);
    });
  }

  void _onPomodoro() {
    if (!mounted) return;
    if (pomo.completionTick != _lastPomoTick) {
      _lastPomoTick = pomo.completionTick;
      final event = pomo.lastEvent;
      if (event != null) toast(event);
    }
  }

  void go(int next) {
    if (next == page) return;
    previousPage = page;
    setState(() => page = next);
  }

  @override
  void dispose() {
    pomo.removeListener(_onPomodoro);
    pomo.dispose();
    search.dispose();
    super.dispose();
  }

  void toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<bool> act(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final ok = await c.send(action, data);
    if (!ok) {
      final message = c.error ?? '操作没有完成，请再试一次。';
      if (message.contains('最多同时播放') && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: '调整混音',
              onPressed: () => go(0),
            ),
          ),
        );
      } else {
        toast(message);
      }
    }
    return ok;
  }

  Future<bool> setTrackVolume(String id, int value) async {
    final ok = await act('volume', {'id': id, 'value': value});
    if (ok && c.playing) {
      final silent =
          c.master == 0 ||
          (c.tracks.isNotEmpty &&
              c.tracks.every((t) => ((t['volume'] as num?) ?? 0) <= 0));
      if (silent) {
        await act('pause');
        toast('当前已静音。调高音量后，再点击播放。');
      }
    }
    return ok;
  }

  Future<bool> setMasterVolume(int value) async {
    final ok = await act('master', {'value': value});
    if (ok && value == 0 && c.playing) {
      await act('pause');
      toast('当前已静音。调高音量后，再点击播放。');
    }
    return ok;
  }

  void openLibrary() => setState(() {
    previousPage = page;
    page = 2;
    category = '全部';
  });

  void openPomodoro() => go(1);

  Future<bool> confirm(
    String title,
    String body, {
    String accept = '确认',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 20)),
          content: Text(body, style: const TextStyle(height: 1.7)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(accept),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> guardSwitch() async {
    if (!c.dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存这份声音配方？', style: TextStyle(fontSize: 21)),
        content: const Text('当前混音有未保存的调整。保存后，下次就能直接回来。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('不保存并切换'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('保存后切换'),
          ),
        ],
      ),
    );
    if (choice == 'save') return await saveMix();
    return choice == 'discard';
  }

  Future<void> loadScene(SceneSpec scene) async {
    if (!await guardSwitch()) return;
    final tracks = scene.tracks.entries
        .where((e) => c.available.contains(e.key))
        .map((e) => {'id': e.key, 'volume': e.value})
        .toList();
    if (tracks.length != scene.tracks.length) {
      toast('这个场景还有声音未就绪，请先试听其他声音。');
      return;
    }
    final keepTimer = c.hasTimer;
    if (await act('load', {
      'tracks': tracks,
      'title': scene.title,
      'autoplay': true,
    })) {
      if (!keepTimer) {
        await act('timer', {
          'seconds': scene.minutes * 60,
          'fadeSeconds': scene.fadeSeconds,
        });
      }
      c.markLoaded();
      if (keepTimer) toast('已切换场景，保留当前定时。');
    }
  }

  Future<void> loadFavorite(
    Map<String, dynamic> favorite, {
    bool autoplay = true,
  }) async {
    if (!await guardSwitch()) return;
    final all = validTracks(favorite['tracks']);
    final available = c.library.map((s) => s.id).toSet();
    final tracks = all.where((t) => available.contains(t['id'])).toList();
    if (tracks.isEmpty) {
      toast('组合中的声音已不可用，请先重新导入。');
      return;
    }
    if (tracks.length != all.length &&
        !await confirm(
          '有声音暂时不可用',
          '这份配方有 ${all.length - tracks.length} 个本地声音缺失。仅${autoplay ? '播放' : '载入'}其余可用声音？',
          accept: autoplay ? '播放可用声音' : '载入可用声音',
        )) {
      return;
    }
    final keepTimer = c.hasTimer;
    if (await act('load', {
      'tracks': tracks,
      'title': favorite['name'],
      'autoplay': autoplay,
    })) {
      await act('master', {
        'value': (favorite['master'] as num? ?? 70).clamp(0, 100),
      });
      if (!keepTimer && favorite['seconds'] is num) {
        await act('timer', {
          'seconds': favorite['seconds'],
          'fadeSeconds': favorite['fade'] ?? 30,
        });
      }
      c.markLoaded(favorite['id'] as String);
      c.touchFavorite(favorite['id'] as String);
      if (!autoplay) {
        toast('已载入“${favorite['name']}”，点击播放开始。');
      }
    }
  }

  Future<bool> saveMix() async {
    unawaited(c.loadFullFont());
    if (c.tracks.isEmpty) {
      toast('先加入至少一种声音，再保存配方。');
      return false;
    }
    final name = TextEditingController(text: c.title);
    var withTimer = false;
    var update = c.favoriteId != null;
    String? validation;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => sheet(ctx, '保存一份安静', [
          Text(
            '把喜欢的声音比例留下来，下次一键播放。',
            style: TextStyle(color: Palette.of(ctx).muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            autofocus: true,
            maxLength: 24,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: '混音名称',
              errorText: validation,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: c.tracks
                .map(
                  (t) => smallTag(
                    ctx,
                    '${c.sound(t['id']).name} ${t['volume']}%',
                    icon: c.sound(t['id']).icon,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (c.hasTimer)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('保存建议计时', style: TextStyle(fontSize: 16)),
              subtitle: Text(
                '保存时长与淡出，不保存剩余时间',
                style: TextStyle(fontSize: 14, color: Palette.of(ctx).muted),
              ),
              value: withTimer,
              onChanged: (v) => setLocal(() => withTimer = v),
            ),
          if (c.favoriteId != null)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('更新原组合', style: TextStyle(fontSize: 16)),
              subtitle: Text(
                '关闭后另存为新组合',
                style: TextStyle(fontSize: 14, color: Palette.of(ctx).muted),
              ),
              value: update,
              onChanged: (v) => setLocal(() => update = v),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.bookmark_add_outlined, size: 19),
              label: Text(update ? '更新组合' : '保存组合'),
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setLocal(() => validation = '给这份混音起个名字。');
                  return;
                }
                if (c.saveFavorite(
                  name.text,
                  withTimer: withTimer,
                  update: update,
                )) {
                  Navigator.pop(ctx, true);
                } else {
                  setLocal(() => validation = c.error);
                }
              },
            ),
          ),
        ]),
      ),
    );
    if (result == true) toast('已保存到收藏。');
    return result == true;
  }

  Widget sheet(BuildContext ctx, String title, List<Widget> children) {
    final p = Palette.of(ctx);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * .92,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭面板',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 21),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> timerSheet() async {
    final savedMinutes = c.hasTimer
        ? (c.remaining / 60).round().clamp(1, 720)
        : 30;
    var hours = savedMinutes ~/ 60;
    var minutes = savedMinutes % 60;
    var fade = c.hasTimer ? c.timerFade : c.defaultFade;
    final hourInput = TextEditingController(text: '$hours');
    final minuteInput = TextEditingController(text: '$minutes');
    String? validation;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final total =
              (int.tryParse(hourInput.text) ?? 0) * 60 +
              (int.tryParse(minuteInput.text) ?? 0);
          final safeFade = total < 1
              ? 0
              : math.min(fade, math.min(total * 30, 120));
          final adjusted = fade > safeFade;
          final end = total >= 1 ? endClockText(total * 60) : null;
          return sheet(ctx, '定时关闭', [
            Text(
              '让声音在合适的时候停下来。渐弱包含在总时长内，暂停后倒计时仍继续。',
              style: TextStyle(
                color: Palette.of(ctx).muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [10, 30, 60]
                  .map(
                    (m) => selectButton(
                      ctx,
                      '$m 分钟',
                      hours * 60 + minutes == m,
                      () => setLocal(() {
                        hours = m ~/ 60;
                        minutes = m % 60;
                        hourInput.text = '$hours';
                        minuteInput.text = '$minutes';
                        validation = null;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: hourInput,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(labelText: '小时'),
                    onChanged: (v) => setLocal(() {
                      hours = int.tryParse(v) ?? 0;
                      validation = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minuteInput,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(labelText: '分钟'),
                    onChanged: (v) => setLocal(() {
                      minutes = int.tryParse(v) ?? 0;
                      validation = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              '结束前渐弱',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 15, 30, 60, 120]
                  .map(
                    (s) => selectButton(
                      ctx,
                      s == 0 ? '关闭' : '$s 秒',
                      fade == s,
                      () => setLocal(() {
                        fade = s;
                        validation = null;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text(
              total < 1
                  ? '请选择 1 到 720 分钟的时长。'
                  : safeFade > 0
                  ? '最后 $safeFade 秒逐渐变轻，$end 结束。'
                  : '到点后直接停止，$end 结束。',
              style: TextStyle(
                fontSize: 14,
                color: validation != null
                    ? Palette.of(ctx).error
                    : Palette.of(ctx).muted,
                height: 1.5,
              ),
            ),
            if (adjusted)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '时长较短，渐弱已调整为 $safeFade 秒。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Palette.of(ctx).warning,
                    height: 1.5,
                  ),
                ),
              ),
            if (validation != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  validation!,
                  style: TextStyle(fontSize: 14, color: Palette.of(ctx).error),
                ),
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final h = int.tryParse(hourInput.text) ?? 0;
                  final m = int.tryParse(minuteInput.text) ?? 0;
                  final value = h * 60 + m;
                  if (h < 0 ||
                      h > 12 ||
                      m < 0 ||
                      m > 59 ||
                      value < 1 ||
                      value > 720) {
                    setLocal(
                      () => validation = m > 59
                          ? '分钟请在 0 到 59 之间。'
                          : '请输入 1 到 720 分钟的时长。',
                    );
                    return;
                  }
                  final fadeValue = math.min(fade, math.min(value * 30, 120));
                  Navigator.pop(ctx);
                  if (await act('timer', {
                    'seconds': value * 60,
                    'fadeSeconds': fadeValue,
                  })) {
                    toast(
                      c.playing
                          ? fadeValue > 0
                                ? '计时已开始，最后 $fadeValue 秒渐弱。'
                                : '计时已开始，到点后停止。'
                          : '计时已准备，播放后开始。',
                    );
                  }
                },
                child: Text(
                  c.hasTimer
                      ? '重新计时'
                      : c.playing
                      ? '开始计时'
                      : '播放后开始',
                ),
              ),
            ),
            if (c.hasTimer)
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    act('cancelTimer');
                    toast('已取消定时，声音不受影响。');
                  },
                  child: const Text('取消当前定时'),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget selectButton(
    BuildContext ctx,
    String text,
    bool selected,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    final p = Palette.of(ctx);
    return Tactile(
      enabled: enabled,
      pressedScale: .95,
      hoverScale: 1.015,
      child: AnimatedOpacity(
        duration: NookMotion.base,
        opacity: enabled ? 1 : .5,
        child: AnimatedContainer(
          duration: NookMotion.base,
          curve: NookMotion.enterCurve,
          decoration: BoxDecoration(
            color: selected ? p.soft : p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? p.accent : p.border),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    color: selected ? p.accent : p.text,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void breathe() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BreathingPage(reducedMotion: c.reducedMotion),
    ),
  );

  Future<void> importAudio() async {
    unawaited(c.loadFullFont());
    final before = c.locals.length;
    final ok = await act('import');
    if (!mounted) return;
    if (ok && c.locals.length > before) {
      setState(() {
        previousPage = page;
        page = 2;
        category = '本地';
      });
      toast('声音已保存在此设备，可以加入混音了。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || c.reducedMotion,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;
        final wide = constraints.maxWidth >= 1200;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desktop) sidebar(context),
                Expanded(
                  child: Column(
                    children: [
                      if (!desktop)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                          child: Row(
                            children: [
                              brand(context, compact: true),
                              const Spacer(),
                              pomoTicker(context, compact: true),
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: '切换明暗主题',
                                onPressed: () =>
                                    c.setTheme(p.dark ? 'light' : 'dark'),
                                icon: AnimatedSwitcher(
                                  duration: NookMotion.base,
                                  switchInCurve: NookMotion.enterCurve,
                                  transitionBuilder: (child, animation) =>
                                      RotationTransition(
                                        turns: Tween<double>(
                                          begin: -.12,
                                          end: 0,
                                        ).animate(animation),
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      ),
                                  child: Icon(
                                    p.dark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                    key: ValueKey(p.dark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: !c.ready
                            ? loadingView(context)
                            : PageSwap(
                                pageKey: page,
                                direction: page >= previousPage ? 1 : -1,
                                reduceMotion:
                                    c.reducedMotion ||
                                    (MediaQuery.maybeDisableAnimationsOf(
                                          context,
                                        ) ??
                                        false),
                                child: SingleChildScrollView(
                                  key: PageStorageKey('page-$page'),
                                  padding: EdgeInsets.fromLTRB(
                                    desktop ? 34 : 20,
                                    desktop ? 32 : 14,
                                    desktop ? 34 : 20,
                                    34,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1050,
                                    ),
                                    child: switch (page) {
                                      1 => pomodoroPage(context, wide),
                                      2 => libraryPage(context),
                                      3 => favoritesPage(context),
                                      4 => settingsPage(context),
                                      _ => homePage(context, wide),
                                    },
                                  ),
                                ),
                              ),
                      ),
                      if (desktop && !wide) miniPlayer(context),
                    ],
                  ),
                ),
                if (wide)
                  Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border(left: BorderSide(color: p.border)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                      child: mixContents(context),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: AnimatedBuilder(
                      animation: pomo,
                      builder: (context, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (page != 0 &&
                            !(page == 1 &&
                                MediaQuery.sizeOf(context).height < 700))
                          miniPlayer(context),
                          SizedBox(
                            height:
                                64 +
                                math.max(
                                      0.0,
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(12) /
                                          12 -
                                          1,
                                    ) *
                                    24,
                            child: Row(
                              children: List.generate(
                                nav.length,
                                (i) => Expanded(
                                  child: Semantics(
                                    selected: page == i,
                                    button: true,
                                    excludeSemantics: true,
                                    label: i == 1 && pomo.running
                                        ? '专注 ${pomo.clock}'
                                        : nav[i],
                                    child: Tactile(
                                      pressedScale: .94,
                                      hoverScale: 1,
                                      child: InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          go(i);
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AnimatedContainer(
                                              duration: NookMotion.base,
                                              curve: NookMotion.enterCurve,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 13,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: page == i
                                                    ? p.soft
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  AnimatedScale(
                                                    scale: page == i ? 1.05 : 1,
                                                    duration: NookMotion.base,
                                                    curve: NookMotion.enterCurve,
                                                    child: Icon(
                                                      navIcons[i],
                                                      size: 22,
                                                      color: page == i
                                                          ? p.accent
                                                          : p.muted,
                                                    ),
                                                  ),
                                                  if (i == 1 &&
                                                      (pomo.running ||
                                                          pomo.remaining <
                                                              pomo
                                                                  .phaseLength))
                                                    Positioned(
                                                      right: -7,
                                                      top: -3,
                                                      child: Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: pomo.running
                                                              ? p.accent
                                                              : p.muted,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              i == 1 && pomo.running
                                                  ? pomo.clock
                                                  : nav[i],
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: page == i
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: page == i
                                                    ? p.accent
                                                    : p.muted,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
          ),
          if (_introMounted)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _introVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: NookMotion.exit,
                  onEnd: () {
                    if (!_introVisible && mounted) {
                      setState(() => _introMounted = false);
                    }
                  },
                  child: const NativeLaunchOverlay(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget loadingView(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NookLogo(size: 48, semanticLabel: '听隅正在启动'),
        const SizedBox(height: 20),
        const Text('正在整理你的声音空间', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        const SizedBox(
          width: 140,
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ],
    ),
  );

  Widget brand(BuildContext context, {bool compact = false}) {
    final p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NookLogo(size: compact ? 36 : 40),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '听隅',
              style: TextStyle(
                fontSize: compact ? 22 : 25,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
                color: p.text,
              ),
            ),
            if (!compact)
              Text(
                'QUIET NOOK',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: p.muted,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget pomoTicker(BuildContext context, {bool compact = false}) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: pomo,
      builder: (context, _) {
        final active = pomo.running || pomo.remaining < pomo.phaseLength;
        if (!active) return const SizedBox.shrink();
        return AnimatedSwitcher(
          duration: NookMotion.base,
          switchInCurve: NookMotion.enterCurve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .92, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: Tooltip(
            key: const ValueKey('pomo-ticker'),
            message: '打开番茄钟',
            child: Tactile(
              child: Material(
                color: p.soft,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: openPomodoro,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 11 : 13,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pomo.running
                              ? Icons.timer_rounded
                              : Icons.timer_outlined,
                          size: 15,
                          color: p.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pomo.clock,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget sidebar(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: 194,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 33, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          brand(context),
          const SizedBox(height: 42),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < nav.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        selected: page == i,
                        button: true,
                        excludeSemantics: true,
                        label: i == 1 && pomo.running
                            ? '专注 ${pomo.clock}'
                            : nav[i],
                        child: Tactile(
                          pressedScale: .97,
                          hoverScale: 1,
                          child: AnimatedContainer(
                            duration: NookMotion.base,
                            curve: NookMotion.enterCurve,
                            decoration: BoxDecoration(
                              color: page == i ? p.soft : Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(13),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                go(i);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
                                ),
                                child: Row(
                                  children: [
                                    AnimatedScale(
                                      scale: page == i ? 1.05 : 1,
                                      duration: NookMotion.base,
                                      curve: NookMotion.enterCurve,
                                      child: Icon(
                                        navIcons[i],
                                        color: page == i ? p.accent : p.muted,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: AnimatedDefaultTextStyle(
                                        duration: NookMotion.base,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontFamily: c.fontFamily,
                                          fontWeight: page == i
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: page == i
                                              ? p.accent
                                              : p.muted,
                                        ),
                                        child: Text(nav[i]),
                                      ),
                                    ),
                                    if (i == 1 &&
                                        (pomo.running ||
                                            pomo.remaining < pomo.phaseLength))
                                      AnimatedBuilder(
                                        animation: pomo,
                                        builder: (context, _) => Text(
                                          pomo.clock,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: p.accent,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          pomoSideCard(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.eco_outlined, color: p.muted, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '此刻，不必着急。',
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      tooltip: '切换明暗主题',
                      onPressed: () => c.setTheme(p.dark ? 'light' : 'dark'),
                      icon: Icon(
                        p.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 20,
                      ),
                    ),
                    Text(
                      p.dark ? '夜色正好' : '日光正好',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget pomoSideCard(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: pomo,
      builder: (context, _) {
        final active = pomo.running || pomo.remaining < pomo.phaseLength;
        if (!active) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Tactile(
            child: Material(
              color: p.soft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: openPomodoro,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(
                        pomo.running
                            ? Icons.timer_rounded
                            : Icons.timer_outlined,
                        size: 19,
                        color: p.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pomo.phase.label,
                              style: TextStyle(fontSize: 11, color: p.muted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pomo.clock,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: p.accent,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: p.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget pageHeading(
    BuildContext context,
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: p.muted, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  String get homeStatus {
    final parts = <String>['${c.tracks.length} 种声音'];
    final silent =
        c.tracks.isNotEmpty &&
        (c.master == 0 ||
            c.tracks.every((t) => ((t['volume'] as num?) ?? 0) <= 0));
    if (c.timerStatus == 'expired') {
      parts.add('声音已按计划停止');
    } else if (c.timerStatus == 'fading') {
      parts.add('正在渐弱 · ${clockText(c.remaining)}');
    } else if (silent) {
      parts.add('当前已静音');
    } else if (c.hasTimer) {
      parts.add(
        c.timerStatus == 'armed'
            ? '播放后开始计时'
            : c.playing
            ? '正在播放'
            : '计时中',
      );
    } else if (c.playing) {
      parts.add('正在播放');
    } else if (c.tracks.isNotEmpty) {
      parts.add('准备好了，就从这里开始');
    } else {
      parts.add('先选一份安静');
    }
    if (c.dirty) parts.add('有未保存修改');
    return parts.join(' · ');
  }

  String? get timerCaption {
    if (c.timerStatus == 'expired') {
      return '声音已按计划停止；再次播放不会自动重新计时。';
    }
    if (!c.hasTimer) return null;
    final end = endClockText(c.remaining);
    final fade = c.timerFade;
    final fadeText = fade > 0 ? '最后 $fade 秒渐弱' : '到点直接停止';
    if (c.timerStatus == 'armed') {
      return '播放后开始 · ${(c.timerDuration / 60).round()} 分钟 · $fadeText';
    }
    if (c.timerStatus == 'fading') {
      return '正在渐弱 · $end 结束';
    }
    return '剩余 ${clockText(c.remaining)} · $end 结束 · $fadeText';
  }

  Widget pomodoroPage(BuildContext context, bool wide) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: pomo,
      builder: (context, _) {
        final timerCard = _pomoTimerCard(context);
        final settingsCard = _pomoSettingsCard(context);
        final statsCard = _pomoStatsCard(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pageHeading(
              context,
              '专注',
              '一段一段地做，把注意力放回此刻。',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: p.soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_outlined, size: 14, color: p.accent),
                    const SizedBox(width: 6),
                    Text(
                      '今日 ${pomo.todayMinutes} 分钟',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                if (box.maxWidth >= 680) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            timerCard,
                            const SizedBox(height: 2),
                            statsCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: settingsCard),
                    ],
                  );
                }
                return Column(
                  children: [
                    timerCard,
                    const SizedBox(height: 18),
                    settingsCard,
                    statsCard,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              '提示：计时在切换到其他页面或后台后仍会继续；系统仍可能因省电策略暂停音频，请勿将计时用作系统闹钟。',
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.7),
            ),
          ],
        );
      },
    );
  }

  Widget _pomoTimerCard(BuildContext context) {
    final p = Palette.of(context);
    final color = pomoPhaseColor(p, pomo.phase);
    final reduce =
        c.reducedMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          _pomoPhaseTabs(context),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, box) {
              final dimension = math
                  .min(330.0, math.max(206.0, box.maxWidth - 16))
                  .toDouble();
              return Center(
                child: BreathingHalo(
                  active: pomo.running && !reduce,
                  color: color,
                  child: SizedBox.square(
                    dimension: dimension,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: pomo.progress),
                      duration: reduce
                          ? Duration.zero
                          : pomo.running
                          ? const Duration(milliseconds: 980)
                          : NookMotion.slow,
                      curve: Curves.linear,
                      builder: (context, value, child) => CustomPaint(
                        painter: _PomoRingPainter(
                          progress: value,
                          color: color,
                          track: p.border,
                        ),
                        child: child,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pomo.clock,
                              style: TextStyle(
                                fontSize: dimension * .225,
                                height: 1.05,
                                fontWeight: FontWeight.w300,
                                letterSpacing: .5,
                                color: p.text,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: NookMotion.base,
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: pomo.running ? color : p.muted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  pomo.statusLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: p.muted,
                                    letterSpacing: .4,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              pomo.phase.hint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.muted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _pomoCycleRow(context, color),
          const SizedBox(height: 18),
          _pomoControls(context),
          const SizedBox(height: 13),
          Text(
            _pomoAudioHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.muted, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _pomoPhaseTabs(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        for (var i = 0; i < PomoPhase.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: pomo.phase == PomoPhase.values[i],
              button: true,
              excludeSemantics: true,
              label: PomoPhase.values[i].label,
              child: Tactile(
                pressedScale: .95,
                hoverScale: 1.01,
                child: AnimatedContainer(
                  duration: NookMotion.base,
                  curve: NookMotion.enterCurve,
                  decoration: BoxDecoration(
                    color: pomo.phase == PomoPhase.values[i]
                        ? pomoPhaseColor(
                            p,
                            PomoPhase.values[i],
                          ).withValues(alpha: p.dark ? .22 : .13)
                        : p.subtle.withValues(alpha: p.dark ? .55 : .45),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: pomo.phase == PomoPhase.values[i]
                          ? pomoPhaseColor(
                              p,
                              PomoPhase.values[i],
                            ).withValues(alpha: .55)
                          : Colors.transparent,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () =>
                          _requestPomodoroPhase(PomoPhase.values[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              pomoPhaseIcon(PomoPhase.values[i]),
                              size: 17,
                              color: pomo.phase == PomoPhase.values[i]
                                  ? pomoPhaseColor(p, PomoPhase.values[i])
                                  : p.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PomoPhase.values[i].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: pomo.phase == PomoPhase.values[i]
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: pomo.phase == PomoPhase.values[i]
                                    ? pomoPhaseColor(p, PomoPhase.values[i])
                                    : p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pomoCycleRow(BuildContext context, Color color) {
    final p = Palette.of(context);
    final done = pomo.phase == PomoPhase.longBreak
        ? pomo.settings.longEvery
        : pomo.focusInCycle;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < pomo.settings.longEvery; i++)
              AnimatedContainer(
                duration: NookMotion.base,
                curve: NookMotion.enterCurve,
                margin: const EdgeInsets.only(right: 5),
                width: i == done && pomo.phase == PomoPhase.focus ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i < done
                      ? color
                      : i == done && pomo.phase == PomoPhase.focus
                      ? color.withValues(alpha: .35)
                      : p.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
        Text(
          pomo.cycleLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: p.muted,
          ),
        ),
        if (pomo.todayCount > 0)
          Text(
            '今日完成 ${pomo.todayCount} 次',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
      ],
    );
  }

  String get _pomoAudioHint {
    if (pomo.phase == PomoPhase.focus) {
      if (!pomo.settings.playWithFocus) return '专注时不会自动播放声音。';
      if (c.tracks.isEmpty) return '还没有混音，可以在「声音」页挑几种陪着你。';
      if (c.playing) return '声音正在陪你专注。';
      return '开始后会播放当前混音。';
    }
    return pomo.settings.pauseOnBreak ? '休息时，声音会自动暂停。' : '休息时，声音会继续保持。';
  }

  Widget _pomoControls(BuildContext context) {
    final p = Palette.of(context);
    final icon = pomo.running ? Icons.pause_rounded : Icons.play_arrow_rounded;
    return Row(
      children: [
        _pomoRoundButton(
          context,
          icon: Icons.replay_rounded,
          tooltip: '重新开始本阶段',
          onPressed: pomo.reset,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Tactile(
            pressedScale: .98,
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: pomo.toggle,
                icon: AnimatedSwitcher(
                  duration: NookMotion.fast,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(icon, key: ValueKey(icon), size: 22),
                ),
                label: AnimatedSwitcher(
                  duration: NookMotion.base,
                  switchInCurve: NookMotion.enterCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    pomo.nextButtonLabel,
                    key: ValueKey(pomo.nextButtonLabel),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _pomoRoundButton(
          context,
          icon: Icons.skip_next_rounded,
          tooltip: '跳过本阶段',
          onPressed: _skipPomodoro,
        ),
      ],
    );
  }

  Widget _pomoRoundButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final p = Palette.of(context);
    return Tactile(
      pressedScale: .92,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, size: 22, color: p.muted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pomoSettingsCard(BuildContext context) {
    final p = Palette.of(context);
    final locked = pomo.running;
    final s = pomo.settings;
    return settingSection(context, '节奏', [
      _pomoDurationRow(
        context,
        '专注时长',
        PomoPhase.focus,
        const [15, 25, 45, 60],
        s.focusMinutes,
        locked,
      ),
      const SizedBox(height: 18),
      _pomoDurationRow(
        context,
        '短休息',
        PomoPhase.shortBreak,
        const [5, 10, 15],
        s.shortMinutes,
        locked,
      ),
      const SizedBox(height: 18),
      _pomoDurationRow(
        context,
        '长休息',
        PomoPhase.longBreak,
        const [15, 20, 30],
        s.longMinutes,
        locked,
      ),
      if (locked)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '暂停或结束后可以调整时长。',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ),
      const SizedBox(height: 6),
      Divider(height: 30, color: p.border),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '长休息间隔',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '每完成 ${s.longEvery} 轮专注，进入一次长休息。',
                  style: TextStyle(fontSize: 13, color: p.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: p.subtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '减少轮数',
                  onPressed: s.longEvery <= 2
                      ? null
                      : () => pomo.setLongEvery(s.longEvery - 1),
                  icon: const Icon(Icons.remove_rounded, size: 18),
                ),
                Text(
                  '${s.longEvery}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                IconButton(
                  tooltip: '增加轮数',
                  onPressed: s.longEvery >= 8
                      ? null
                      : () => pomo.setLongEvery(s.longEvery + 1),
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
      Divider(height: 30, color: p.border),
      _pomoSwitch(
        context,
        icon: Icons.autorenew_rounded,
        title: '自动开始下一阶段',
        subtitle: '专注和休息自动衔接，适合不想被打断的节奏。',
        value: s.autoStart,
        onChanged: pomo.setAutoStart,
      ),
      _pomoSwitch(
        context,
        icon: Icons.headphones_outlined,
        title: '专注时播放当前混音',
        subtitle: c.tracks.isEmpty
            ? '当前还没有混音。'
            : '${c.tracks.length} 种声音，开始专注时自动播放。',
        value: s.playWithFocus,
        onChanged: pomo.setPlayWithFocus,
      ),
      _pomoSwitch(
        context,
        icon: Icons.pause_circle_outline_rounded,
        title: '休息时暂停混音',
        subtitle: '让耳朵也一起休息。',
        value: s.pauseOnBreak,
        onChanged: pomo.setPauseOnBreak,
      ),
      Divider(height: 30, color: p.border),
      _pomoSwitch(
        context,
        icon: Icons.notifications_active_outlined,
        title: '结束提示音',
        subtitle: '一声轻轻的提示，不改变正在播放的声音。',
        value: s.chime,
        onChanged: pomo.setChime,
      ),
      if (s.chime) ...[
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            selectButton(
              context,
              '清铃',
              s.chimeKind == 'bell',
              () => pomo.setChimeKind('bell'),
            ),
            selectButton(
              context,
              '木鱼',
              s.chimeKind == 'wood',
              () => pomo.setChimeKind('wood'),
            ),
            IconButton(
              tooltip: '试听提示音',
              onPressed: pomo.chimePreview,
              icon: const Icon(Icons.volume_up_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.volume_down_outlined, size: 19, color: p.muted),
            Expanded(
              child: Slider(
                value: s.chimeVolume.toDouble(),
                max: 100,
                divisions: 20,
                label: '${s.chimeVolume}%',
                onChanged: (v) => pomo.setChimeVolume(v.round()),
                onChangeEnd: (_) => pomo.chimePreview(),
              ),
            ),
            SizedBox(
              width: 38,
              child: Text(
                '${s.chimeVolume}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  color: p.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ],
      _pomoSwitch(
        context,
        icon: Icons.notifications_outlined,
        title: '系统通知',
        subtitle: _notificationHint,
        value: s.notify && pomo.notificationPermission == 'granted',
        onChanged: _togglePomodoroNotifications,
      ),
      if (pomo.notificationPermission == 'denied')
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 2),
          child: Text(
            '通知被拒绝时，页内仍会显示完成提示。',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ),
    ]);
  }

  String get _notificationHint => switch (pomo.notificationPermission) {
    'granted' => pomo.settings.notify ? '完成时发送系统通知。' : '已允许，但当前没有开启。',
    'denied' => '系统已拒绝通知，页内提醒仍会显示。',
    'unsupported' => '当前环境不支持系统通知，页内提醒仍会显示。',
    _ => '首次开启时会请求系统权限。',
  };

  Widget _pomoDurationRow(
    BuildContext context,
    String label,
    PomoPhase target,
    List<int> presets,
    int current,
    bool locked,
  ) {
    final p = Palette.of(context);
    final custom = !presets.contains(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in presets)
              selectButton(
                context,
                '$minutes 分钟',
                current == minutes,
                () => pomo.setDuration(target, minutes),
                enabled: !locked,
              ),
            selectButton(
              context,
              custom ? '$current 分钟' : '自定义',
              custom,
              () => _editPomodoroDuration(target),
              enabled: !locked,
            ),
          ],
        ),
        if (custom)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '当前为自定义时长',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ),
      ],
    );
  }

  Widget _pomoSwitch(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final p = Palette.of(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 21, color: p.muted),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: p.muted, height: 1.5),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _pomoStatsCard(BuildContext context) {
    final p = Palette.of(context);
    final color = pomoPhaseColor(p, pomo.phase);
    return settingSection(context, '专注记录', [
      Row(
        children: [
          Expanded(
            child: _pomoStat(context, '${pomo.todayMinutes}', '今天分钟'),
          ),
          Container(width: 1, height: 38, color: p.border),
          Expanded(child: _pomoStat(context, '${pomo.todayCount}', '完成次数')),
          Container(width: 1, height: 38, color: p.border),
          Expanded(child: _pomoStat(context, '${pomo.streakDays}', '连续天数')),
        ],
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Text(
            '最近 7 天',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.muted,
            ),
          ),
          const Spacer(),
          Text(
            '本周 ${pomo.weekMinutes.fold<int>(0, (a, b) => a + b)} 分钟',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _pomoWeekChart(context, color),
      if (pomo.sessions.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '完成一次专注后，这里会留下记录。',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: pomo.sessions.isEmpty ? null : _clearPomodoroHistory,
          icon: const Icon(Icons.delete_sweep_outlined, size: 17),
          label: const Text('清空记录'),
          style: TextButton.styleFrom(foregroundColor: p.muted),
        ),
      ),
    ]);
  }

  Widget _pomoStat(BuildContext context, String value, String label) {
    final p = Palette.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: p.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
      ],
    );
  }

  Widget _pomoWeekChart(BuildContext context, Color color) {
    final p = Palette.of(context);
    final values = pomo.weekMinutes;
    final max = math.max(1, values.fold<int>(0, (a, b) => a > b ? a : b));
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final day = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: 6 - i));
        final minutes = values[i];
        final height = 6 + (minutes / max) * 54;
        return Expanded(
          child: Semantics(
            label: '${day.month} 月 ${day.day} 日，专注 $minutes 分钟',
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: NookMotion.slow,
                      curve: NookMotion.enterCurve,
                      width: 15,
                      height: height,
                      decoration: BoxDecoration(
                        color: minutes == 0
                            ? p.border
                            : i == 6
                            ? color
                            : color.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  i == 6 ? '今' : '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    color: i == 6 ? p.accent : p.muted,
                    fontWeight: i == 6 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _requestPomodoroPhase(PomoPhase next) async {
    if (next == pomo.phase) return;
    if (pomo.running || pomo.remaining < pomo.phaseLength) {
      final ok = await confirm(
        '切换到${next.label}？',
        '当前${pomo.phase.label}的进度会被放弃，计时不会计入记录。',
        accept: '切换',
      );
      if (!ok) return;
    }
    pomo.switchPhase(next);
  }

  Future<void> _skipPomodoro() async {
    if (pomo.running && pomo.progress > .1) {
      final ok = await confirm('跳过这一阶段？', '这一轮的进度不会计入专注记录。', accept: '跳过');
      if (!ok) return;
    }
    pomo.skip();
  }

  Future<void> _editPomodoroDuration(PomoPhase target) async {
    final current = switch (target) {
      PomoPhase.focus => pomo.settings.focusMinutes,
      PomoPhase.shortBreak => pomo.settings.shortMinutes,
      PomoPhase.longBreak => pomo.settings.longMinutes,
    };
    final max = switch (target) {
      PomoPhase.focus => 180,
      PomoPhase.shortBreak => 60,
      PomoPhase.longBreak => 120,
    };
    final input = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${target.label}时长', style: const TextStyle(fontSize: 20)),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '分钟',
            helperText: '1–$max 分钟',
          ),
          onSubmitted: (text) {
            final parsed = int.tryParse(text);
            if (parsed != null && parsed >= 1 && parsed <= max) {
              Navigator.pop(ctx, parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(input.text);
              if (parsed != null && parsed >= 1 && parsed <= max) {
                Navigator.pop(ctx, parsed);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    input.dispose();
    if (value != null) {
      pomo.setDuration(target, value);
      toast('${target.label}已设为 $value 分钟。');
    }
  }

  Future<void> _togglePomodoroNotifications(bool value) async {
    if (!value) {
      pomo.setNotify(false);
      return;
    }
    var permission = pomo.notificationPermission;
    if (permission == 'granted') {
      pomo.setNotify(true);
      return;
    }
    if (permission == 'denied') {
      toast('系统已拒绝通知，可以在系统设置里重新允许。');
      return;
    }
    if (permission == 'unsupported') {
      toast('当前环境不支持系统通知，页内提醒仍会显示。');
      return;
    }
    permission = await pomo.requestNotifications();
    if (!mounted) return;
    if (permission == 'granted') {
      pomo.setNotify(true);
      toast('系统通知已开启。');
    } else {
      pomo.setNotify(false);
      toast('没有获得通知权限，页内提醒仍会显示。');
    }
  }

  Future<void> _clearPomodoroHistory() async {
    final ok = await confirm(
      '清空专注记录？',
      '只会删除这台设备上的专注统计，不会影响收藏和声音。',
      accept: '清空记录',
    );
    if (ok) pomo.clearHistory();
  }

  Widget homePage(BuildContext context, bool wide) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageHeading(context, '为现在，留一点安静。', '给自己，留一小片安静。'),
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
                child: AspectRatio(
                  aspectRatio: MediaQuery.sizeOf(context).width < 600
                      ? 1.85
                      : 2.55,
                  child: Image.asset(
                    'assets/images/rain-nook.webp',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, .25),
                    color: p.dark ? const Color(0xffc6ccbd) : null,
                    colorBlendMode: p.dark ? BlendMode.modulate : null,
                    semanticLabel: '雨落在窗外，窗边放着书和一杯茶的水彩画',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      homeStatus,
                      style: TextStyle(
                        color: p.muted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    heroActions(context),
                    if (timerCaption != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 15,
                              color: p.muted,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                timerCaption!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.muted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!wide) ...[
          const SizedBox(height: 30),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '当前声音',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${c.tracks.length} / 6 种',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: mixContents(context, embedded: true),
          ),
        ],
        const SizedBox(height: 31),
        Row(
          children: [
            const Expanded(
              child: Text(
                '为此刻，选一套声音',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: openLibrary,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('全部声音', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 15),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        LayoutBuilder(
          builder: (ctx, box) {
            final scale = MediaQuery.textScalerOf(ctx).scale(16) / 16;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: box.maxWidth >= 590 ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 132.0 + math.max(0.0, scale - 1) * 80,
              ),
              itemCount: scenes.length,
              itemBuilder: (ctx, i) => sceneCard(context, scenes[i]),
            );
          },
        ),
        const SizedBox(height: 24),
        Tactile(
          hoverLift: true,
          pressedScale: .98,
          hoverScale: 1.004,
          child: Material(
            color: p.soft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: breathe,
              borderRadius: BorderRadius.circular(16),
              hoverColor: p.accent.withValues(alpha: .05),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.self_improvement_outlined,
                      size: 32,
                      color: p.accent,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '跟着呼吸一分钟',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '不用做得很好，舒服就好。',
                            style: TextStyle(fontSize: 14, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: p.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 15, color: p.muted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '锁屏或切到后台时，音频会尽量继续；系统仍可能因省电策略暂停，请勿将计时用作闹钟。',
                style: TextStyle(fontSize: 12, color: p.muted, height: 1.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget heroActions(BuildContext context) {
    final timer = timerAction(context);
    final save = OutlinedButton.icon(
      onPressed: saveMix,
      icon: const Icon(Icons.bookmark_border_rounded, size: 19),
      label: const Text('保存'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 15),
      ),
    );
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    if (scale > 1.2) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: timer),
              ),
              const SizedBox(width: 12),
              playButton(context, size: 58),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: save),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: timer),
        ),
        playButton(context, size: 58),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: save),
        ),
      ],
    );
  }

  Widget timerAction(BuildContext context) {
    final p = Palette.of(context);
    final active = c.hasTimer || c.timerStatus == 'expired';
    return OutlinedButton.icon(
      onPressed: timerSheet,
      icon: const Icon(Icons.timer_outlined, size: 19),
      label: Text(
        c.hasTimer
            ? clockText(c.remaining)
            : c.timerStatus == 'expired'
            ? '已结束'
            : '定时',
        style: TextStyle(
          fontSize: active ? 17 : 15,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: active ? p.soft : p.surface,
        foregroundColor: active ? p.accent : p.text,
        side: BorderSide(color: active ? p.accent : p.border),
      ),
    );
  }

  Widget sceneCard(BuildContext context, SceneSpec scene) {
    final p = Palette.of(context);
    return Tactile(
      hoverLift: true,
      pressedScale: .975,
      hoverScale: 1.012,
      child: Material(
        color: p.dark ? p.surface : scene.tint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => loadScene(scene),
          borderRadius: BorderRadius.circular(16),
          hoverColor: p.accent.withValues(alpha: .05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(scene.icon, color: p.accent, size: 25),
                    const Spacer(),
                    Text(
                      '${scene.minutes} 分钟',
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      scene.subtitle,
                      style: TextStyle(fontSize: 12, color: p.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget smallTag(BuildContext context, String text, {IconData? icon}) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.subtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: p.muted),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(fontSize: 12, color: p.muted)),
        ],
      ),
    );
  }

  Widget playButton(BuildContext context, {double size = 48}) {
    final p = Palette.of(context);
    final active = c.playing;
    final enabled = c.ready && !(c.busy && !active);
    return Tooltip(
      message: active ? '暂停声音' : '播放声音',
      excludeFromSemantics: true,
      child: Tactile(
        enabled: enabled,
        pressedScale: .9,
        hoverScale: 1.045,
        child: SizedBox(
          width: size,
          height: size,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
            ),
            onPressed: enabled ? () => act('toggle') : null,
            child: c.busy && !active
                ? Semantics(
                    label: '正在准备播放',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Semantics(
                    label: active ? '暂停声音' : '播放声音',
                    child: AnimatedSwitcher(
                      duration: NookMotion.fast,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                      child: Icon(
                        active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        key: ValueKey(active),
                        size: size * .52,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget mixContents(BuildContext context, {bool embedded = false}) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  '当前混音',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              playButton(context, size: 48),
              const SizedBox(width: 6),
              Icon(Icons.headphones_outlined, size: 22, color: p.muted),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (!embedded) ...[
          Row(
            children: [
              Text(
                '${c.tracks.length} / 6 种声音',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
              const Spacer(),
              if (c.dirty)
                Text(
                  '有未保存修改',
                  style: TextStyle(
                    color: p.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        if (c.tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Text(
              '还没有声音。\n选几种，调成自己的环境。',
              style: TextStyle(color: p.muted, fontSize: 14, height: 1.7),
            ),
          ),
        ...c.tracks.map((t) => trackRow(context, t)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: openLibrary,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('添加声音'),
          ),
        ),
        const SizedBox(height: 24),
        Divider(color: p.border),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.volume_down_outlined, size: 21, color: p.muted),
            const SizedBox(width: 9),
            const Text('总音量', style: TextStyle(fontSize: 15)),
            const Spacer(),
            Text(
              '${c.master}%',
              style: TextStyle(
                fontSize: 14,
                color: p.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Semantics(
          label: '总音量',
          child: Slider(
            value: c.master.toDouble(),
            min: 0,
            max: 100,
            label: '${c.master}%',
            onChanged: (v) => setMasterVolume(v.round()),
          ),
        ),
        if (!embedded) ...[
          const SizedBox(height: 15),
          Material(
            color: p.soft,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: timerSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 19, color: p.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.hasTimer ? clockText(c.remaining) : '定时关闭',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: p.accent,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (c.hasTimer)
                            Text(
                              '${endClockText(c.remaining)} 结束',
                              style: TextStyle(fontSize: 12, color: p.accent),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: p.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saveMix,
              icon: const Icon(Icons.bookmark_border_rounded, size: 18),
              label: const Text('保存混音'),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '不必很大声，刚刚好就好。',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ),
        ],
        if (c.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              c.error!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget trackRow(BuildContext context, Map<String, dynamic> track) {
    final p = Palette.of(context);
    final sound = c.sound(track['id']);
    final value = (track['volume'] as num).toDouble();
    final tint = categoryColor(sound.category, p.dark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.subtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(sound.icon, size: 21, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sound.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => trackVolumeSheet(sound, value),
                style: TextButton.styleFrom(
                  minimumSize: const Size(52, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: p.muted,
                ),
                child: Text(
                  '${value.round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: '移除${sound.name}',
                onPressed: () => act('remove', {'id': sound.id}),
                icon: const Icon(Icons.close_rounded, size: 17),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '${sound.name}音量',
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 100,
                    label: '${value.round()}%',
                    onChanged: (v) => setTrackVolume(sound.id, v.round()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> trackVolumeSheet(SoundSpec sound, double initial) async {
    var current = initial.round().clamp(0, 100);
    final input = TextEditingController(text: '$current');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final p = Palette.of(ctx);
          Future<void> apply(int value) async {
            current = value.clamp(0, 100);
            input.text = '$current';
            setLocal(() {});
            await setTrackVolume(sound.id, current);
          }

          return sheet(ctx, sound.name, [
            Text('精确调整这一轨的音量', style: TextStyle(color: p.muted, fontSize: 14)),
            const SizedBox(height: 22),
            Center(
              child: Text(
                '$current%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: p.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Slider(
              value: current.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$current%',
              onChanged: (v) => unawaited(apply(v.round())),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => unawaited(apply(current - 5)),
                  child: const Text('减 5'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: input,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(suffixText: '%'),
                    onSubmitted: (v) =>
                        unawaited(apply(int.tryParse(v) ?? current)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => unawaited(apply(current + 5)),
                  child: const Text('加 5'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final typed = int.tryParse(input.text);
                  if (typed != null) unawaited(apply(typed));
                  Navigator.pop(ctx);
                },
                child: const Text('完成'),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget miniPlayer(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: p.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => go(0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const NookLogo(size: 27),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${c.tracks.length} 种声音${c.hasTimer
                                      ? c.timerStatus == 'armed'
                                            ? ' · 播放后计时'
                                            : ' · 定时中'
                                      : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (c.hasTimer)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      clockText(c.remaining),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                playButton(context, size: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget libraryPage(BuildContext context) {
    final p = Palette.of(context);
    final barScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final barHeight = 48.0 + math.max(0.0, barScale - 1) * 18;
    final filtered = c.library
        .where(
          (s) =>
              (category == '全部' || s.category == category) &&
              ('${s.name}${s.category}${s.description}'.contains(query)),
        )
        .toList();
    final categories = [
      for (final name in categoryOrder)
        if (name == '全部' ||
            name == '本地' ||
            c.library.any((s) => s.category == name))
          name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageHeading(context, '声音', '选几种声音，调成自己的环境。'),
        TextField(
          controller: search,
          onTap: () => c.loadFullFont(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            hintText: '搜索雨声、森林、风铃…',
            labelText: '搜索声音',
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    tooltip: '清除搜索',
                    onPressed: () => setState(() {
                      query = '';
                      search.clear();
                    }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  )
                : null,
          ),
          onChanged: (v) => setState(() => query = v.trim()),
        ),
        const SizedBox(height: 19),
        SizedBox(
          height: barHeight,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final v in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(v, style: const TextStyle(fontSize: 14)),
                          selected: category == v,
                          showCheckmark: false,
                          selectedColor: p.soft,
                          backgroundColor: p.surface,
                          labelStyle: TextStyle(
                            color: category == v ? p.accent : p.muted,
                            fontWeight: category == v
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: category == v ? p.accent : p.border,
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          onSelected: (_) => setState(() => category = v),
                        ),
                      ),
                    const SizedBox(width: 26),
                  ],
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: 26,
                  height: barHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [p.bg.withValues(alpha: 0), p.bg],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (category == '本地') ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '把自己的声音，收进来。',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 9),
                Text(
                  '音频只保存在此设备，不会上传。支持 WAV、MP3、M4A、OGG 等常见格式，单个文件不超过 50 MB。',
                  style: TextStyle(fontSize: 14, color: p.muted, height: 1.6),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: c.busy ? null : importAudio,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(c.busy ? '正在处理音频' : '导入本地音频'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (filtered.isEmpty) ...[
          emptyState(
            context,
            query.isNotEmpty ? '没有找到这个声音' : '把喜欢的声音，收进这一页',
            query.isNotEmpty ? '试试搜索“雨”或“水流”，或者清除搜索。' : '导入一段喜欢的环境音，与内置声音一起播放。',
            Icons.search_rounded,
          ),
          if (query.isNotEmpty)
            Center(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  query = '';
                  search.clear();
                }),
                child: const Text('清除搜索'),
              ),
            ),
        ],
        LayoutBuilder(
          builder: (ctx, box) {
            final scale = MediaQuery.textScalerOf(ctx).scale(14) / 14;
            final columns = scale > 1.35 && box.maxWidth < 600
                ? 1
                : box.maxWidth >= 850
                ? 4
                : box.maxWidth >= 550
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 13,
                mainAxisSpacing: 13,
                mainAxisExtent: 258.0 + math.max(0.0, scale - 1) * 120,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => soundCard(ctx, filtered[i]),
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          '环境录音与合成音色已分别标注。试听会暂时暂停当前混音，8 秒后恢复。',
          style: TextStyle(fontSize: 12, color: p.muted, height: 1.6),
        ),
      ],
    );
  }

  Widget soundCard(BuildContext context, SoundSpec sound) {
    final p = Palette.of(context);
    final selected = c.contains(sound.id);
    final previewing = c.previewId == sound.id;
    final synthetic = sound.synthesized || c.kinds[sound.id] == 'synth';
    final tint = categoryColor(sound.category, p.dark);
    final source = sound.category == '本地'
        ? '本地音频'
        : synthetic
        ? '合成音色'
        : '环境录音';
    return Material(
      color: selected ? p.soft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? p.accent.withValues(alpha: .65) : p.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => soundDetailSheet(sound),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.subtle,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(sound.icon, size: 26, color: tint),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 19, color: p.accent),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                sound.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                sound.description,
                style: TextStyle(fontSize: 14, color: p.muted, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '$source · ${sound.category}',
                style: TextStyle(fontSize: 12, color: p.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => act(
                        previewing ? 'stopPreview' : 'preview',
                        {'id': sound.id},
                      ),
                      icon: Icon(
                        previewing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 18,
                      ),
                      label: Text(
                        previewing
                            ? c.previewRemaining > 0
                                  ? '${c.previewRemaining.ceil()}s'
                                  : '停止'
                            : '试听',
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () {
                      if (selected) {
                        go(0);
                        return;
                      }
                      act('add', {'id': sound.id, 'volume': 45});
                    },
                    icon: selected
                        ? null
                        : const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      selected ? '已加入' : '加入',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> soundDetailSheet(SoundSpec sound) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final p = Palette.of(ctx);
        final selected = c.contains(sound.id);
        final previewing = c.previewId == sound.id;
        final synthetic = sound.synthesized || c.kinds[sound.id] == 'synth';
        final tint = categoryColor(sound.category, p.dark);
        final source = sound.category == '本地'
            ? '本地音频'
            : synthetic
            ? '合成音色'
            : '环境录音';
        return sheet(ctx, '声音详情', [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: p.subtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(sound.icon, size: 38, color: tint),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${sound.category} · $source',
                      style: TextStyle(fontSize: 14, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            sound.description,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            '喜欢它，就让它加入当前的混音。',
            style: TextStyle(fontSize: 14, color: p.muted),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => act(previewing ? 'stopPreview' : 'preview', {
                    'id': sound.id,
                  }),
                  icon: Icon(
                    previewing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 19,
                  ),
                  label: Text(previewing ? '停止试听' : '单独试听'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (selected) {
                      Navigator.pop(ctx);
                      setState(() => page = 0);
                      return;
                    }
                    act('add', {'id': sound.id, 'volume': 45});
                  },
                  icon: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 19,
                  ),
                  label: Text(selected ? '已加入' : '加入混音'),
                ),
              ),
            ],
          ),
          if (selected)
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  act('remove', {'id': sound.id});
                },
                child: const Text('从混音中移除'),
              ),
            ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '单独试听 8 秒，不会加入混音。',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ),
        ]);
      },
    ),
  );

  Widget emptyState(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: p.accent),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget sortButton(BuildContext context) {
    final p = Palette.of(context);
    const labels = {'recent': '最近使用', 'created': '最近创建', 'name': '名称排序'};
    return PopupMenuButton<String>(
      initialValue: c.favoriteSort,
      tooltip: '收藏排序',
      position: PopupMenuPosition.under,
      onSelected: c.setFavoriteSort,
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'recent', child: Text('最近使用')),
        PopupMenuItem(value: 'created', child: Text('最近创建')),
        PopupMenuItem(value: 'name', child: Text('名称排序')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 18, color: p.muted),
            const SizedBox(width: 6),
            Text(
              labels[c.favoriteSort] ?? '最近使用',
              style: TextStyle(fontSize: 14, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget favoritesPage(BuildContext context) {
    final p = Palette.of(context);
    final favorites = c.sortedFavorites;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageHeading(
          context,
          '收藏',
          '你的声音配方，都在这里。',
          trailing: sortButton(context),
        ),
        if (favorites.isEmpty) ...[
          emptyState(
            context,
            '还没有声音配方',
            '调好一份混音，再把它留下来。',
            Icons.bookmark_border_rounded,
          ),
          Center(
            child: FilledButton.icon(
              onPressed: openLibrary,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('去选声音'),
            ),
          ),
        ],
        ...favorites.map((f) {
          final tracks = validTracks(f['tracks']);
          final ids = c.library.map((s) => s.id).toSet();
          final missing = tracks.where((t) => !ids.contains(t['id'])).length;
          final current = c.favoriteId == f['id'];
          final unavailable = tracks.isEmpty;
          final categories = <String>[];
          for (final t in tracks) {
            final name = c.sound(t['id']).category;
            if (!categories.contains(name)) categories.add(name);
            if (categories.length == 3) break;
          }
          final status = missing > 0
              ? '$missing 个声音不可用'
              : current && c.dirty
              ? '有未保存修改'
              : current
              ? c.playing
                    ? '正在播放'
                    : '当前组合'
              : '${tracks.length} 种声音${f['seconds'] is num ? ' · 建议 ${(f['seconds'] as num) ~/ 60} 分钟' : ''}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: current ? p.accent : p.border,
                  width: current ? 1.4 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: unavailable ? null : () => loadFavorite(f),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: p.subtle,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              tracks.isEmpty
                                  ? Icons.spa_outlined
                                  : c.sound(tracks.first['id']).icon,
                              color: tracks.isEmpty
                                  ? p.accent
                                  : categoryColor(
                                      c.sound(tracks.first['id']).category,
                                      p.dark,
                                    ),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: missing > 0
                                        ? p.warning
                                        : current && c.dirty
                                        ? p.accent
                                        : p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '更多操作',
                            position: PopupMenuPosition.under,
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              size: 22,
                            ),
                            onSelected: (value) async {
                              switch (value) {
                                case 'load':
                                  await loadFavorite(f, autoplay: false);
                                  break;
                                case 'rename':
                                  await renameFavorite(f);
                                  break;
                                case 'delete':
                                  if (await confirm(
                                    '删除这份声音配方？',
                                    '“${f['name']}”会从收藏中移除，声音文件不会被删除。',
                                    accept: '删除收藏',
                                  )) {
                                    if (!c.deleteFavorite(f['id'])) {
                                      toast(c.error!);
                                    }
                                  }
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'load', child: Text('仅载入')),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('重命名'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('删除收藏'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in categories)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: p.subtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    categoryIcon(category),
                                    size: 14,
                                    color: categoryColor(category, p.dark),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: unavailable ? null : () => loadFavorite(f),
                          icon: const Icon(Icons.play_arrow_rounded, size: 19),
                          label: Text(unavailable ? '声音不可用' : '加载并播放'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> renameFavorite(Map<String, dynamic> favorite) async {
    unawaited(c.loadFullFont());
    final input = TextEditingController(text: favorite['name'] as String);
    String? validation;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('重命名', style: TextStyle(fontSize: 21)),
          content: TextField(
            controller: input,
            autofocus: true,
            maxLength: 24,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: '混音名称',
              errorText: validation,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (input.text.trim().isEmpty) {
                  setLocal(() => validation = '给这份混音起个名字。');
                  return;
                }
                Navigator.pop(ctx, input.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (name != null && c.renameFavorite(favorite['id'] as String, name)) {
      toast('已重命名。');
    }
  }

  Widget settingsPage(BuildContext context) {
    final p = Palette.of(context);
    final size = c.locals.fold<num>(
      0,
      (sum, l) => sum + (l['size'] as num? ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageHeading(context, '设置', '一些简单的设置，让这里更像你。'),
        settingSection(context, '外观', [
          const Text('选择适合此刻的光线', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                [
                      ('system', '跟随系统', Icons.brightness_auto_outlined),
                      ('light', '浅色', Icons.light_mode_outlined),
                      ('dark', '深色', Icons.dark_mode_outlined),
                    ]
                    .map((item) {
                      final selected = c.theme == item.$1;
                      return Tactile(
                        pressedScale: .95,
                        hoverScale: 1.015,
                        child: AnimatedContainer(
                          duration: NookMotion.base,
                          curve: NookMotion.enterCurve,
                          decoration: BoxDecoration(
                            color: selected
                                ? p.accent.withValues(alpha: .12)
                                : p.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? p.accent : p.border,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => c.setTheme(item.$1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.$3,
                                      size: 18,
                                      color: selected ? p.accent : p.muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.$2,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: selected ? p.accent : p.text,
                                      ),
                                    ),
                                    if (selected) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: p.accent,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('减少动态效果', style: TextStyle(fontSize: 16)),
            subtitle: Text(
              '页面切换、按钮回弹与番茄钟呼吸光晕会收敛为静态呈现。',
              style: TextStyle(fontSize: 14, color: p.muted),
            ),
            value: c.reducedMotion,
            onChanged: c.setReducedMotion,
          ),
        ]),
        settingSection(context, '播放', [
          const Text(
            '默认渐弱',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '新建计时时默认使用，只影响新计时，不改变正在运行的计时。',
            style: TextStyle(fontSize: 14, color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0, 15, 30, 60, 120]
                .map(
                  (s) => selectButton(
                    context,
                    s == 0 ? '关闭' : '$s 秒',
                    c.defaultFade == s,
                    () => c.setDefaultFade(s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          infoRow(
            context,
            Icons.restore_rounded,
            '恢复上次混音',
            '打开时恢复上次的声音与音量，但不会自动发声。',
          ),
          const SizedBox(height: 20),
          infoRow(
            context,
            Icons.headphones_outlined,
            '后台与锁屏',
            '原生版会尽量保持后台播放；系统仍可能因省电策略暂停音频。',
          ),
        ]),
        settingSection(context, '专注', [
          Row(
            children: [
              const NookLogo(size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '番茄钟',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pomo.settings.focusMinutes} 分钟专注 · ${pomo.settings.shortMinutes} 分钟短休 · 今日 ${pomo.todayMinutes} 分钟',
                      style: TextStyle(
                        fontSize: 13,
                        color: p.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: openPomodoro,
                child: Text(pomo.running ? '查看计时' : '打开'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          infoRow(
            context,
            Icons.notifications_none_rounded,
            '完成提醒',
            '计时结束时会响提示音；也可以开启系统通知。关闭应用后，会按结束时间恢复，但不能替代系统闹钟。',
          ),
        ]),
        settingSection(context, '存储', [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.locals.length} 个本地文件，占用 ${sizeText(size)}',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              TextButton.icon(
                onPressed: c.busy ? null : importAudio,
                icon: const Icon(Icons.file_upload_outlined, size: 17),
                label: const Text('导入'),
              ),
            ],
          ),
          if (c.locals.isEmpty)
            Text(
              '还没有导入声音。你可以把自己的环境音收进来。',
              style: TextStyle(fontSize: 14, color: p.muted, height: 1.6),
            ),
          ...c.locals.map(
            (l) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.audio_file_outlined,
                color: categoryColor('本地', p.dark),
              ),
              title: Text(
                l['name'] as String? ?? '本地声音',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
              subtitle: Text(
                '${clockText(l['duration'] as num? ?? 0)} · ${sizeText(l['size'] as num? ?? 0)}',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: IconButton(
                tooltip: '删除本地声音${l['name']}',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: () async {
                  if (await confirm(
                    '删除本地声音？',
                    '删除“${l['name']}”的设备副本。正在播放的这一轨会被移除，关联收藏会标记缺失；原文件不会被改动。',
                    accept: '删除声音',
                  )) {
                    await act('deleteLocal', {'id': l['id']});
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '清除应用数据会删除收藏和导入副本，请谨慎操作。',
            style: TextStyle(fontSize: 12, color: p.muted, height: 1.6),
          ),
        ]),
        settingSection(context, '关于听隅', [
          Row(
            children: [
              const NookLogo(size: 44),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '听隅',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '版本 2.1.0 · 原生',
                    style: TextStyle(fontSize: 14, color: p.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          infoRow(
            context,
            Icons.offline_bolt_outlined,
            '不需要账号，也没有广告',
            '内置声音随安装包保存，无需联网；导入的个人音频只存入此设备，不会上传。',
          ),
          const SizedBox(height: 20),
          infoRow(
            context,
            Icons.water_drop_outlined,
            '录音与合成，分别标明',
            '自然录音做了循环处理；水下静域与三种噪声为合成音色，近水气泡是真实录音。本地导入自动处理接缝，仍建议试听，不保证所有文件都能无感循环。',
          ),
          const SizedBox(height: 20),
          infoRow(
            context,
            Icons.lock_outline_rounded,
            '数据留在这台设备',
            '收藏和设置都保存在此设备。清除应用数据会一并删除。',
          ),
        ]),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '听隅   /   给自己，留一小片安静。',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget settingSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final p = Palette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget infoRow(
    BuildContext context,
    IconData icon,
    String title,
    String content,
  ) {
    final p = Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: p.accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                content,
                style: TextStyle(fontSize: 14, color: p.muted, height: 1.7),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BreathingPage extends StatefulWidget {
  final bool reducedMotion;
  const BreathingPage({super.key, required this.reducedMotion});
  @override
  State<BreathingPage> createState() => _BreathingPageState();
}

class _BreathingPageState extends State<BreathingPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController animation;
  final stopwatch = Stopwatch();
  Timer? ticker;
  int minutes = 1;
  bool running = true;
  bool done = false;

  int get totalSeconds => minutes * 60;
  int get elapsedSeconds => stopwatch.elapsed.inSeconds.clamp(0, totalSeconds);
  double get sessionProgress => totalSeconds == 0
      ? 0
      : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
  bool get inhaling => animation.value < .4;
  double get phaseProgress => inhaling
      ? (animation.value / .4).clamp(0.0, 1.0)
      : ((animation.value - .4) / .6).clamp(0.0, 1.0);
  int get phaseSecondsLeft {
    final total = inhaling ? 4 : 6;
    return (total * (1 - phaseProgress)).ceil().clamp(1, total);
  }

  String get phaseTitle => done
      ? '这一轮结束了'
      : !running
      ? '随时开始'
      : inhaling
      ? '吸气'
      : '呼气';
  String get phaseHint => done
      ? '舒服就好，想再来一次随时开始。'
      : !running
      ? '按自己的节奏，准备好了再继续。'
      : inhaling
      ? '慢慢吸气，让肩膀松下来。'
      : '轻轻呼气，不用刻意用力。';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    stopwatch.start();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (stopwatch.elapsed.inSeconds >= totalSeconds) {
        stopwatch.stop();
        animation.stop();
        running = false;
        done = true;
      }
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && running) toggle();
  }

  void toggle() {
    setState(() {
      if (done) {
        done = false;
        stopwatch.reset();
        animation.value = 0;
      }
      running = !running;
      if (running) {
        stopwatch.start();
        animation.repeat();
      } else {
        stopwatch.stop();
        animation.stop();
      }
    });
  }

  void resetCycle() {
    setState(() {
      done = false;
      stopwatch.reset();
      animation.value = 0;
      if (running) {
        stopwatch.start();
        animation.repeat();
      } else {
        animation.stop();
      }
    });
  }

  void chooseMinutes(int value) {
    setState(() {
      minutes = value;
      done = false;
      stopwatch
        ..reset()
        ..start();
      animation
        ..value = 0
        ..repeat();
      running = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    stopwatch.stop();
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final reduce =
        widget.reducedMotion || MediaQuery.disableAnimationsOf(context);
    final accent = p.accent;
    final orbSize = math.min(
      MediaQuery.sizeOf(context).width - 64,
      MediaQuery.sizeOf(context).height < 720 ? 300.0 : 348.0,
    ).clamp(230.0, 348.0).toDouble();

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (reduce)
            CustomPaint(
              painter: _BreathBackdropPainter(
                breath: .55,
                accent: accent,
                background: p.bg,
                soft: p.soft,
                dark: p.dark,
              ),
            )
          else
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final breath = inhaling
                    ? Curves.easeInOutSine.transform(phaseProgress)
                    : 1 - Curves.easeInOutSine.transform(phaseProgress);
                return CustomPaint(
                  painter: _BreathBackdropPainter(
                    breath: breath,
                    accent: accent,
                    background: p.bg,
                    soft: p.soft,
                    dark: p.dark,
                  ),
                );
              },
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _BreathGlassButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: '返回',
                            color: p.text,
                            surface: p.surface,
                            border: p.border,
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '呼吸',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                    color: p.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '4 秒吸气 · 6 秒呼气 · 不必屏息',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.muted,
                                    letterSpacing: .2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: p.surface.withValues(alpha: .72),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$minutes 分钟',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: p.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Center(
                        child: AnimatedBuilder(
                          animation: animation,
                          builder: (context, _) {
                            final breath = inhaling
                                ? Curves.easeInOutSine.transform(phaseProgress)
                                : 1 -
                                      Curves.easeInOutSine.transform(
                                        phaseProgress,
                                      );
                            final scale = reduce ? 1.0 : .78 + .22 * breath;
                            return SizedBox.square(
                              dimension: orbSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: sessionProgress,
                                    ),
                                    duration: const Duration(seconds: 1),
                                    curve: Curves.linear,
                                    builder: (context, progress, _) =>
                                        CustomPaint(
                                          size: Size.square(orbSize),
                                          painter: _BreathSessionRingPainter(
                                            progress: done ? 1 : progress,
                                            color: accent,
                                            track: p.border.withValues(
                                              alpha: .65,
                                            ),
                                            tick: p.muted.withValues(
                                              alpha: .28,
                                            ),
                                          ),
                                        ),
                                  ),
                                  CustomPaint(
                                    size: Size.square(orbSize),
                                    painter: _BreathAuraPainter(
                                      breath: reduce ? .55 : breath,
                                      color: accent,
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: scale,
                                    child: SizedBox.square(
                                      dimension: orbSize * .72,
                                      child: CustomPaint(
                                        painter: _BreathCorePainter(
                                          breath: reduce ? .55 : breath,
                                          phase: phaseProgress,
                                          color: accent,
                                          surface: p.surface,
                                          soft: p.soft,
                                          border: p.border,
                                          dark: p.dark,
                                          active: running && !done,
                                        ),
                                        child: Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: orbSize * .11,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 420,
                                                  ),
                                                  switchInCurve: Curves.easeOutCubic,
                                                  switchOutCurve: Curves.easeInCubic,
                                                  transitionBuilder:
                                                      (child, anim) =>
                                                          FadeTransition(
                                                            opacity: anim,
                                                            child: SlideTransition(
                                                              position:
                                                                  Tween<Offset>(
                                                                    begin:
                                                                        const Offset(
                                                                          0,
                                                                          .12,
                                                                        ),
                                                                    end: Offset
                                                                        .zero,
                                                                  ).animate(anim),
                                                              child: child,
                                                            ),
                                                          ),
                                                  child: Text(
                                                    phaseTitle,
                                                    key: ValueKey(phaseTitle),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 28,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      letterSpacing: 4,
                                                      color: accent,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 9),
                                                Text(
                                                  done
                                                      ? '舒服就好'
                                                      : !running
                                                      ? clockText(
                                                          math.max(
                                                            0,
                                                            totalSeconds -
                                                                elapsedSeconds,
                                                          ),
                                                        )
                                                      : '$phaseSecondsLeft 秒',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    color: p.muted,
                                                    letterSpacing: 1,
                                                    fontFeatures: const [
                                                      FontFeature
                                                          .tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 14),
                                                Text(
                                                  phaseHint,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    height: 1.65,
                                                    color: p.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!running && !done)
                                    Positioned(
                                      bottom: orbSize * .035,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.surface.withValues(
                                            alpha: .8,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(color: p.border),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.touch_app_outlined,
                                              size: 13,
                                              color: p.accent,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '继续时从当前节奏开始',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: p.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          done
                              ? '这一轮呼吸已完成'
                              : '本次 $minutes 分钟 · 还剩 ${clockText(math.max(0, totalSeconds - elapsedSeconds))}',
                          style: TextStyle(
                            fontSize: 12,
                            color: p.muted,
                            letterSpacing: .3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: p.border),
                          boxShadow: [
                            BoxShadow(
                              color: p.dark
                                  ? Colors.black.withValues(alpha: .18)
                                  : p.accent.withValues(alpha: .05),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  '留一点时间',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: p.text,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '选择这一轮的长度',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                for (var i = 0; i < 3; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  Expanded(
                                    child: _BreathDurationButton(
                                      label: '${[1, 3, 5][i]} 分钟',
                                      selected: minutes == [1, 3, 5][i],
                                      color: p.accent,
                                      surface: p.surface,
                                      border: p.border,
                                      soft: p.soft,
                                      textColor: p.muted,
                                      onTap: () =>
                                          chooseMinutes([1, 3, 5][i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _BreathGlassButton(
                                  icon: Icons.replay_rounded,
                                  tooltip: '重新开始本轮',
                                  color: p.muted,
                                  surface: p.surface,
                                  border: p.border,
                                  onTap: resetCycle,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: p.accent,
                                        foregroundColor: p.onAccent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: toggle,
                                      icon: Icon(
                                        done
                                            ? Icons.refresh_rounded
                                            : running
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 21,
                                      ),
                                      label: Text(
                                        done
                                            ? '再呼吸一会儿'
                                            : running
                                            ? '暂停引导'
                                            : '继续引导',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '引导结束不会关闭混音。感到不适时，请停止。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.6,
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathGlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color surface;
  final Color border;
  final VoidCallback onTap;

  const _BreathGlassButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tactile(
      pressedScale: .92,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: surface.withValues(alpha: .72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, size: 21, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathDurationButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color surface;
  final Color border;
  final Color soft;
  final Color textColor;
  final VoidCallback onTap;

  const _BreathDurationButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.surface,
    required this.border,
    required this.soft,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tactile(
      pressedScale: .95,
      hoverScale: 1.01,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? soft : surface.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? color : border),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? color : textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathBackdropPainter extends CustomPainter {
  final double breath;
  final Color accent;
  final Color background;
  final Color soft;
  final bool dark;

  const _BreathBackdropPainter({
    required this.breath,
    required this.accent,
    required this.background,
    required this.soft,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            background,
            Color.lerp(background, soft, dark ? .45 : .65)!,
            background,
          ],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
      ..color = accent.withValues(alpha: dark ? .075 : .10);
    canvas.drawCircle(
      Offset(size.width * .24, size.height * (.25 - breath * .02)),
      size.width * .45,
      glow,
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * (.34 + breath * .03)),
      size.width * .34,
      glow..color = accent.withValues(alpha: dark ? .055 : .075),
    );
    final dot = Paint()..color = accent.withValues(alpha: dark ? .14 : .11);
    for (var i = 0; i < 30; i++) {
      final x =
          (i * 47.0) % size.width +
          math.sin(breath * math.pi * 2 + i) * 9;
      final y =
          (i * 83.0) % size.height +
          math.cos(breath * math.pi * 2 + i * .7) * 13;
      canvas.drawCircle(
        Offset(x, y),
        i % 7 == 0 ? 1.8 : 1.1,
        dot..color = accent.withValues(alpha: dark ? .14 : .09),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BreathBackdropPainter oldDelegate) =>
      oldDelegate.breath != breath ||
      oldDelegate.accent != accent ||
      oldDelegate.background != background ||
      oldDelegate.soft != soft ||
      oldDelegate.dark != dark;
}

class _BreathSessionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final Color tick;

  const _BreathSessionRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = track,
    );
    for (var i = 0; i < 72; i++) {
      final angle = i * math.pi / 36 - math.pi / 2;
      final start = radius - 6;
      final end = start - (i % 6 == 0 ? 4 : 2);
      canvas.drawLine(
        center + Offset(math.cos(angle) * start, math.sin(angle) * start),
        center + Offset(math.cos(angle) * end, math.sin(angle) * end),
        Paint()
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round
          ..color = tick,
      );
    }
    if (progress <= .0005) return;
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
        colors: [color.withValues(alpha: .35), color],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
    final angle = -math.pi / 2 + sweep;
    canvas.drawCircle(
      center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      3.2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _BreathSessionRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.tick != tick;
}

class _BreathAuraPainter extends CustomPainter {
  final double breath;
  final Color color;

  const _BreathAuraPainter({required this.breath, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width * .355;
    for (var i = 0; i < 3; i++) {
      final radius = base * (1 + i * .105 + breath * .012);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: .12 - i * .022),
      );
    }
    canvas.drawCircle(
      center,
      base * .98,
      Paint()
        ..color = color.withValues(alpha: .055)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
  }

  @override
  bool shouldRepaint(covariant _BreathAuraPainter oldDelegate) =>
      oldDelegate.breath != breath || oldDelegate.color != color;
}

class _BreathCorePainter extends CustomPainter {
  final double breath;
  final double phase;
  final Color color;
  final Color surface;
  final Color soft;
  final Color border;
  final bool dark;
  final bool active;

  const _BreathCorePainter({
    required this.breath,
    required this.phase,
    required this.color,
    required this.surface,
    required this.soft,
    required this.border,
    required this.dark,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    canvas.drawCircle(
      center,
      radius * .92,
      Paint()
        ..color = color.withValues(alpha: .10 + breath * .05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.28, -.34),
          radius: 1.15,
          colors: [
            Color.lerp(surface, Colors.white, dark ? .02 : .55)!,
            Color.lerp(soft, color, dark ? .18 : .10)!,
            Color.lerp(surface, color, dark ? .08 : .04)!,
          ],
          stops: const [0, .58, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = border.withValues(alpha: .8),
    );
    for (var i = 1; i <= 2; i++) {
      canvas.drawCircle(
        center,
        radius * (1 - i * .11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = color.withValues(alpha: .08),
      );
    }
    if (active) {
      final sweep = math.pi * 2 * phase.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * .84),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = color.withValues(alpha: .5),
      );
    }
    // A quiet leaf watermark, echoing the brand mark.
    canvas.save();
    canvas.translate(center.dx, center.dy + radius * .34);
    canvas.scale(radius / 1024);
    canvas.translate(-512, -512);
    final leaf = Path()
      ..moveTo(512, 184)
      ..cubicTo(666, 280, 732, 424, 688, 574)
      ..cubicTo(658, 678, 576, 752, 512, 792)
      ..cubicTo(448, 752, 366, 678, 336, 574)
      ..cubicTo(292, 424, 358, 280, 512, 184)
      ..close();
    canvas.drawPath(
      leaf,
      Paint()..color = color.withValues(alpha: dark ? .045 : .035),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BreathCorePainter oldDelegate) =>
      oldDelegate.breath != breath ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.active != active ||
      oldDelegate.dark != dark;
}

class _PomoRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  const _PomoRingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = track,
    );

    final tick = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = track;
    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30 - math.pi / 2;
      final long = i % 5 == 0;
      final start = radius + 11;
      final end = start + (long ? 5 : 2.5);
      canvas.drawLine(
        center + Offset(math.cos(angle) * start, math.sin(angle) * start),
        center + Offset(math.cos(angle) * end, math.sin(angle) * end),
        tick,
      );
    }

    if (progress <= .0005) return;
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13
      ..color = color.withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7
        ..color = color,
    );
    final angle = -math.pi / 2 + sweep;
    canvas.drawCircle(
      center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PomoRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class BreathingHalo extends StatefulWidget {
  final bool active;
  final Color color;
  final Widget child;

  const BreathingHalo({
    super.key,
    required this.active,
    required this.color,
    required this.child,
  });

  @override
  State<BreathingHalo> createState() => _BreathingHaloState();
}

class _BreathingHaloState extends State<BreathingHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant BreathingHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && oldWidget.active) {
      _controller.animateTo(0, duration: const Duration(milliseconds: 350));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = widget.active ? _curve.value : 0.0;
        return Transform.scale(
          scale: 1 + .012 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: .08 + .08 * t),
                  blurRadius: 30 + 8 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
