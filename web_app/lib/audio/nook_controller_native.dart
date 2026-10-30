import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';


class _NativeTrack {
  _NativeTrack(this.id, this.volume);
  final String id;
  int volume;
  SoundHandle? handle;
}

/// 原生多轨引擎：一个 SoLoud 设备混 6 路循环，收藏/草稿/本地文件走原生存储。
/// UI 的公开 API 与 Web 版 NookController 保持一致。
class NookController extends ChangeNotifier {
  NookController() {
    available = sounds.map((sound) => sound.id).toSet();
    for (final sound in sounds) {
      if (sound.synthesized) kinds[sound.id] = 'synth';
    }
    _tracks.addAll([
      _NativeTrack('rain', 65),
      _NativeTrack('forest', 25),
      _NativeTrack('brown', 20),
    ]);
  }

  final SoLoud _audio = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};
  final Map<String, SoundHandle> _previewHandles = {};
  final List<_NativeTrack> _tracks = [];
  final List<Map<String, dynamic>> _localMeta = [];

  SharedPreferences? _prefs;
  Set<String> available = {};
  Map<String, String> kinds = {};
  List<Map<String, dynamic>> favorites = [];
  String theme = 'system';
  String favoriteSort = 'recent';
  int defaultFade = 30;
  bool reducedMotion = false;
  bool ready = false;
  String? error;
  String? favoriteId;
  bool fullFontLoaded = false;

  bool _playing = false;
  bool _busy = false;
  int _master = 70;
  String _title = '窗边一页';
  String? _previewId;
  double _previewRemaining = 0;
  String _timerStatus = 'off';
  int _timerDuration = 0;
  int _timerFade = 0;
  DateTime? _deadline;
  double _remaining = 0;
  String _baseline = '';
  Timer? _ticker;
  Timer? _previewTimer;
  int _generation = 0;
  bool _initialized = false;
  bool _loadingFullFont = false;

  String get fontFamily => fullFontLoaded ? 'NookFull' : 'NookUI';
  List<Map<String, dynamic>> get tracks =>
      _tracks.map((t) => {'id': t.id, 'volume': t.volume}).toList();
  List<Map<String, dynamic>> get locals => _localMeta
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
  bool get playing => _playing;
  bool get busy => _busy;
  int get master => _master;
  String get title => _title;
  String? get previewId => _previewId;
  num get previewRemaining => _previewRemaining;
  Map<String, dynamic> get timer => {
    'status': _timerStatus,
    'remaining': _remaining,
    'duration': _timerDuration,
    'fade': _timerFade,
  };
  String get timerStatus => _timerStatus;
  num get remaining => _remaining;
  int get timerDuration => _timerDuration;
  int get timerFade => _timerFade;
  bool get hasTimer => ['armed', 'running', 'fading'].contains(_timerStatus);
  String get signature => jsonEncode({'tracks': tracks, 'master': master});
  bool get dirty => ready && _baseline.isNotEmpty && signature != _baseline;
  String get timerLabel => switch (_timerStatus) {
    'armed' => '播放后计时',
    'running' => clockText(_remaining),
    'fading' => '渐弱 ${clockText(_remaining)}',
    'expired' => '已定时结束',
    _ => '定时关闭',
  };

  int _stamp(Map<String, dynamic> item, String key) =>
      item[key] is num ? (item[key] as num).toInt() : 0;

  List<Map<String, dynamic>> get sortedFavorites {
    final list = [...favorites];
    switch (favoriteSort) {
      case 'created':
        list.sort(
          (a, b) => _stamp(b, 'createdAt').compareTo(_stamp(a, 'createdAt')),
        );
        break;
      case 'name':
        list.sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
        );
        break;
      default:
        list.sort(
          (a, b) => math
              .max(_stamp(b, 'lastUsedAt'), _stamp(b, 'updatedAt'))
              .compareTo(
                math.max(_stamp(a, 'lastUsedAt'), _stamp(a, 'updatedAt')),
              ),
        );
    }
    return list;
  }

  List<SoundSpec> get library => [
    ...sounds.where((s) => available.contains(s.id)),
    ..._localMeta.map(
      (m) => SoundSpec(
        m['id'] as String,
        m['name'] as String? ?? '本地声音',
        '本地',
        '${clockText(m['duration'] as num? ?? 0)}，保存在此设备',
        Icons.audio_file_outlined,
      ),
    ),
  ];

  SoundSpec sound(String id) =>
      library.where((s) => s.id == id).firstOrNull ??
      sounds.where((s) => s.id == id).firstOrNull ??
      SoundSpec(id, '不可用的声音', '本地', '请重新导入音频', Icons.audio_file_outlined);

  bool contains(String id) => _tracks.any((t) => t.id == id);

  Future<void> loadFullFont() async {
    if (fullFontLoaded || _loadingFullFont) return;
    _loadingFullFont = true;
    try {
      final loader = FontLoader('NookFull')
        ..addFont(rootBundle.load('assets/fonts/nook.ttf'));
      await loader.load();
      fullFontLoaded = true;
      notifyListeners();
    } catch (_) {
      // 界面字体子集已覆盖所有内置文案。
    } finally {
      _loadingFullFont = false;
    }
  }

  Future<void> bootstrap() async {
    await loadFullFont();
    try {
      _prefs = await SharedPreferences.getInstance();
      theme = _readSetting('theme');
      if (!['light', 'dark', 'system'].contains(theme)) theme = 'system';
      reducedMotion = _readSetting('reducedMotion') == 'true';
      final fade = int.tryParse(_readSetting('defaultFade'));
      if (fade != null && [0, 15, 30, 60, 120].contains(fade)) {
        defaultFade = fade;
      }
      final sort = _readSetting('favoriteSort');
      if (['recent', 'created', 'name'].contains(sort)) favoriteSort = sort;
      final savedFavorites = _readJson('favorites');
      if (savedFavorites is List) {
        favorites = savedFavorites
            .whereType<Map>()
            .where((v) => v['id'] is String && v['name'] is String)
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
      }
      final savedLocals = _readJson('locals');
      if (savedLocals is List) {
        _localMeta
          ..clear()
          ..addAll(
            savedLocals
                .whereType<Map>()
                .where((m) => m['id'] is String && m['file'] is String)
                .map((m) => Map<String, dynamic>.from(m)),
          );
        await _removeMissingLocals();
      }
      final draft = _readJson('draft');
      if (draft is Map) {
        final parsed = validTracks(draft['tracks']);
        final availableIds = {
          ...sounds.map((s) => s.id),
          ..._localMeta.map((m) => m['id']),
        };
        final kept = parsed.where((t) => availableIds.contains(t['id'])).toList();
        if (draft['tracks'] is List) {
          _tracks
            ..clear()
            ..addAll(kept.map((t) => _NativeTrack(t['id'] as String, t['volume'] as int)));
        }
        if (draft['master'] is num) {
          _master = (draft['master'] as num).round().clamp(0, 100);
        }
        if (draft['title'] is String && (draft['title'] as String).trim().isNotEmpty) {
          _title = draft['title'] as String;
        }
      }
    } catch (_) {
      error = '本地设置没有读取成功，仍可使用内置声音。';
    }
  }

  Future<void> initialize() async {
    try {
      if (!_audio.isInitialized) {
        await _audio.init(
          sampleRate: 48000,
          bufferSize: 2048,
          channels: Channels.stereo,
          androidAAudioAttributes: AndroidAAudioAttributes.mediaMusic,
        );
      }
      _initialized = true;
      _baseline = signature;
      if (favorites.isNotEmpty || _localMeta.isNotEmpty) {
        unawaited(loadFullFont());
      }
    } catch (_) {
      error = '音频设备没有准备好，请检查系统声音设置后重试。';
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // 桌面端没有 audio_session 插件时仍使用系统默认输出。
    }
    ready = true;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  Future<bool> send(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    try {
      error = null;
      switch (action) {
        case 'init':
          return true;
        case 'toggle':
          if (_playing) {
            await _pause();
          } else {
            await _play();
          }
          return true;
        case 'play':
          await _play();
          return true;
        case 'pause':
          await _pause();
          return true;
        case 'load':
          await _load(payload);
          return true;
        case 'add':
          await _add(payload);
          return true;
        case 'remove':
          await _remove(payload['id']);
          return true;
        case 'volume':
          _setTrackVolume(payload['id'], payload['value']);
          return true;
        case 'master':
          _setMaster(payload['value']);
          return true;
        case 'preview':
          await _preview(payload['id']);
          return true;
        case 'stopPreview':
          await _stopPreview();
          return true;
        case 'timer':
          _setTimer(payload);
          return true;
        case 'cancelTimer':
          _cancelTimer();
          return true;
        case 'stop':
          await _pause();
          _cancelTimer();
          return true;
        case 'import':
          await _import();
          return true;
        case 'deleteLocal':
          await _deleteLocal(payload['id']);
          return true;
        default:
          error = '未知的音频操作。';
          return false;
      }
    } catch (e) {
      error = _messageFor(e);
      notifyListeners();
      return false;
    }
  }

  bool persist(String key, Object value) {
    final text = value is String ? value : jsonEncode(value);
    try {
      final prefs = _prefs;
      if (prefs == null) return false;
      unawaited(prefs.setString('tingyu.$key', text));
      return true;
    } catch (_) {
      error = '本地保存失败，请检查设备存储空间。';
      return false;
    }
  }

  String readValue(String key) => _prefs?.getString('tingyu.$key') ?? '';

  String _readSetting(String key) => _prefs?.getString('tingyu.$key') ?? '';

  dynamic _readJson(String key) {
    final raw = _readSetting(key);
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  void setTheme(String value) {
    theme = value;
    persist('theme', value);
    notifyListeners();
  }

  void setReducedMotion(bool value) {
    reducedMotion = value;
    persist('reducedMotion', value.toString());
    notifyListeners();
  }

  void setDefaultFade(int value) {
    defaultFade = [0, 15, 30, 60, 120].contains(value) ? value : 30;
    persist('defaultFade', '$defaultFade');
    notifyListeners();
  }

  void setFavoriteSort(String value) {
    if (!['recent', 'created', 'name'].contains(value)) return;
    favoriteSort = value;
    persist('favoriteSort', value);
    notifyListeners();
  }

  void markLoaded([String? id]) {
    favoriteId = id;
    _baseline = signature;
    notifyListeners();
  }

  void touchFavorite(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = favorites
        .map((f) => f['id'] == id ? {...f, 'lastUsedAt': now} : f)
        .toList();
    if (persist('favorites', next)) {
      favorites = next;
      notifyListeners();
    }
  }

  bool renameFavorite(String id, String name) {
    final title = name.trim();
    if (title.isEmpty) {
      error = '给这份混音起个名字。';
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = favorites
        .map((f) => f['id'] == id ? {...f, 'name': title, 'updatedAt': now} : f)
        .toList();
    if (!persist('favorites', next)) return false;
    favorites = next;
    notifyListeners();
    return true;
  }

  bool saveFavorite(
    String name, {
    bool withTimer = false,
    bool update = false,
  }) {
    if (name.trim().isEmpty || _tracks.isEmpty) {
      error = _tracks.isEmpty ? '先加入至少一种声音。' : '给这份混音起个名字。';
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic>? existing;
    for (final favorite in favorites) {
      if (favorite['id'] == favoriteId) {
        existing = favorite;
        break;
      }
    }
    final id = update && favoriteId != null ? favoriteId! : now.toString();
    final item = <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'tracks': tracks,
      'master': master,
      'seconds': withTimer && hasTimer ? _timerDuration : null,
      'fade': withTimer && hasTimer ? _timerFade : null,
      'createdAt': update && existing != null ? existing['createdAt'] ?? now : now,
      'updatedAt': now,
      'lastUsedAt': now,
    };
    final next = [item, ...favorites.where((f) => f['id'] != id)];
    if (!persist('favorites', next)) return false;
    favorites = next;
    markLoaded(id);
    return true;
  }

  bool deleteFavorite(String id) {
    final next = favorites.where((v) => v['id'] != id).toList();
    if (!persist('favorites', next)) return false;
    favorites = next;
    if (favoriteId == id) favoriteId = null;
    notifyListeners();
    return true;
  }

  Future<void> _play() async {
    if (_tracks.isEmpty) {
      error = '先加入至少一种声音，再播放。';
      notifyListeners();
      return;
    }
    if (_timerStatus == 'expired') _resetTimer();
    final generation = ++_generation;
    _busy = true;
    error = null;
    notifyListeners();
    try {
      for (final track in _tracks) {
        final source = await _sourceFor(track.id);
        if (generation != _generation) return;
        await _stopHandle(track);
        track.handle = _audio.play(
          source,
          volume: track.volume / 100,
          looping: true,
        );
      }
      _playing = true;
      if (_timerStatus == 'armed') {
        _timerStatus = 'running';
        _deadline = DateTime.now().add(Duration(seconds: _timerDuration));
      }
      _applyGlobal(immediate: true);
      if (_timerStatus == 'running') _startTicker();
      _saveDraft();
    } catch (_) {
      for (final track in _tracks) {
        await _stopHandle(track);
      }
      _playing = false;
      _applyGlobal(immediate: true);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _pause() async {
    _generation++;
    for (final track in _tracks) {
      await _stopHandle(track);
    }
    _playing = false;
    await _stopPreview();
    _applyGlobal(immediate: true);
    _saveDraft();
    notifyListeners();
  }

  Future<void> _load(Map<String, dynamic> payload) async {
    final parsed = validTracks(payload['tracks']);
    final availableIds = {
      ...sounds.map((s) => s.id),
      ..._localMeta.map((m) => m['id']),
    };
    final next = parsed.where((t) => availableIds.contains(t['id'])).toList();
    if (next.isEmpty) throw StateError('这份混音里的声音暂时不可用。');
    await _pause();
    _tracks
      ..clear()
      ..addAll(next.map((t) => _NativeTrack(t['id'] as String, t['volume'] as int)));
    if (payload['title'] is String && (payload['title'] as String).trim().isNotEmpty) {
      _title = (payload['title'] as String).trim();
    }
    if (payload['autoplay'] == true) {
      await _play();
    } else {
      _saveDraft();
      notifyListeners();
    }
  }

  Future<void> _add(Map<String, dynamic> payload) async {
    final id = payload['id'];
    if (id is! String) throw StateError('声音编号无效。');
    if (_tracks.length >= 6) throw StateError('最多同时播放 6 种声音，请先移除一种。');
    if (_tracks.any((t) => t.id == id)) return;
    final volume = (payload['volume'] as num? ?? 45).round().clamp(0, 100).toInt();
    final track = _NativeTrack(id, volume);
    _tracks.add(track);
    if (_playing) {
      final source = await _sourceFor(id);
      track.handle = _audio.play(source, volume: volume / 100, looping: true);
      _applyGlobal(immediate: true);
    }
    _saveDraft();
    notifyListeners();
  }

  Future<void> _remove(Object? id) async {
    final track = _tracks.where((t) => t.id == id).firstOrNull;
    if (track == null) return;
    await _stopHandle(track);
    _tracks.remove(track);
    _applyGlobal(immediate: true);
    _saveDraft();
    notifyListeners();
  }

  void _setTrackVolume(Object? id, Object? value) {
    final track = _tracks.where((t) => t.id == id).firstOrNull;
    if (track == null) throw StateError('此声音不在当前混音中。');
    final next = (value as num?)?.round().clamp(0, 100).toInt();
    if (next == null) throw StateError('轨道音量无效。');
    track.volume = next;
    final handle = track.handle;
    if (handle != null) _audio.setVolume(handle, next / 100);
    _applyGlobal();
    _saveDraft();
    notifyListeners();
  }

  void _setMaster(Object? value) {
    final next = (value as num?)?.round().clamp(0, 100).toInt();
    if (next == null) throw StateError('总音量无效。');
    _master = next;
    _applyGlobal();
    _saveDraft();
    notifyListeners();
  }

  Future<void> _preview(Object? id) async {
    if (id is! String) throw StateError('声音编号无效。');
    await _stopPreview();
    final source = await _sourceFor(id);
    final handle = _audio.play(source, volume: 0.7, looping: false);
    _previewHandles[id] = handle;
    _previewId = id;
    final length = _audio.getLength(source);
    _previewRemaining = length.inMilliseconds <= 0
        ? 8
        : math.min(8.0, length.inMilliseconds / 1000);
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _previewRemaining = math.max(0, _previewRemaining - .25);
      if (_previewRemaining <= 0) unawaited(_stopPreview());
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    for (final handle in _previewHandles.values) {
      try {
        await _audio.stop(handle);
      } catch (_) {}
    }
    _previewHandles.clear();
    _previewId = null;
    _previewRemaining = 0;
    notifyListeners();
  }

  void _setTimer(Map<String, dynamic> payload) {
    final seconds = (payload['seconds'] as num?)?.round() ?? 0;
    if (seconds <= 0) throw StateError('计时时长无效。');
    _timerDuration = seconds.clamp(1, 43200);
    _timerFade = ((payload['fadeSeconds'] as num?) ?? defaultFade).round().clamp(0, 120);
    _timerStatus = _playing ? 'running' : 'armed';
    _remaining = _timerDuration.toDouble();
    _deadline = _playing ? DateTime.now().add(Duration(seconds: _timerDuration)) : null;
    _startTicker();
    notifyListeners();
  }

  void _cancelTimer() {
    _resetTimer();
    notifyListeners();
  }

  void _resetTimer() {
    _timerStatus = 'off';
    _deadline = null;
    _remaining = 0;
    _timerDuration = 0;
    _timerFade = 0;
    if (_initialized) _applyGlobal(immediate: true);
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    var changed = false;
    if (_timerStatus == 'running' || _timerStatus == 'armed') {
      if (_timerStatus == 'running' && _deadline != null) {
        _remaining = _deadline!.difference(DateTime.now()).inMilliseconds / 1000;
        if (_remaining <= 0) {
          unawaited(_expireTimer());
          return;
        }
        if (_timerFade > 0 && _remaining <= _timerFade) {
          _timerStatus = 'fading';
        }
        _applyGlobal();
        changed = true;
      }
    } else if (_timerStatus == 'fading') {
      _remaining = (_deadline?.difference(DateTime.now()).inMilliseconds ?? 0) / 1000;
      if (_remaining <= 0) {
        unawaited(_expireTimer());
        return;
      }
      _applyGlobal();
      changed = true;
    }
    if ((_timerStatus == 'off' || _timerStatus == 'expired' || _timerStatus == 'armed') &&
        _previewTimer == null) {
      _ticker?.cancel();
      _ticker = null;
    }
    if (changed) notifyListeners();
  }

  Future<void> _expireTimer() async {
    _timerStatus = 'expired';
    _remaining = 0;
    _deadline = null;
    _generation++;
    for (final track in _tracks) {
      await _stopHandle(track);
    }
    _playing = false;
    if (_initialized) _audio.setGlobalVolume(0);
    notifyListeners();
  }

  void _applyGlobal({bool immediate = false}) {
    if (!_initialized) return;
    final sum = _tracks.fold<double>(0, (total, t) => total + t.volume / 100);
    final normalized = .85 / math.max(1, sum);
    var factor = 1.0;
    if (_timerStatus == 'fading' && _timerFade > 0) {
      factor = math.pow((_remaining / _timerFade).clamp(0.0, 1.0), 2).toDouble();
    }
    final target = _master / 100 * normalized * factor;
    if (immediate) {
      _audio.setGlobalVolume(target);
    } else {
      _audio.fadeGlobalVolume(target, const Duration(milliseconds: 300));
    }
  }

  Future<void> _stopHandle(_NativeTrack track) async {
    final handle = track.handle;
    track.handle = null;
    if (handle != null) {
      try {
        await _audio.stop(handle);
      } catch (_) {}
    }
  }

  Future<AudioSource> _sourceFor(String id) async {
    final cached = _sources[id];
    if (cached != null) return cached;
    final meta = _localMeta.where((m) => m['id'] == id).firstOrNull;
    late final AudioSource loaded;
    if (meta != null) {
      final file = File(await _localPath(meta));
      if (!await file.exists()) throw StateError('本地声音文件已不存在，请重新导入。');
      if (p.extension(file.path).toLowerCase() == '.wav') {
        loaded = await _audio.loadMem('$id.loop.wav', _loopWavBytes(await file.readAsBytes()));
      } else {
        loaded = await _audio.loadFile(file.path);
      }
    } else {
      loaded = await _audio.loadAsset('assets/audio/builtin/$id.flac');
    }
    _sources[id] = loaded;
    return loaded;
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result.isEmpty) return;
    final picked = result.first;
    final path = picked.path;
    if (path == null) throw StateError('无法读取这个文件，请换一个文件重试。');
    final source = File(path);
    if (!await source.exists()) throw StateError('文件不存在或没有读取权限。');
    final bytes = await source.length();
    if (bytes > 50 * 1024 * 1024) throw StateError('单个本地音频不能超过 50 MB。');
    _busy = true;
    notifyListeners();
    try {
      final dir = await getApplicationSupportDirectory();
      final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final ext = p.extension(picked.name).toLowerCase();
      final file = File(p.join(dir.path, 'imports', '$id$ext'));
      await file.parent.create(recursive: true);
      await source.copy(file.path);
      Duration duration = Duration.zero;
      try {
        final audioSource = p.extension(file.path) == '.wav'
            ? await _audio.loadMem('$id.loop.wav', _loopWavBytes(await file.readAsBytes()))
            : await _audio.loadFile(file.path);
        duration = _audio.getLength(audioSource);
        _sources[id] = audioSource;
      } catch (_) {
        await file.delete();
        throw StateError('这个音频格式无法播放，请尝试 WAV、MP3、M4A 或 OGG。');
      }
      _localMeta.insert(0, {
        'id': id,
        'name': picked.name,
        'file': p.basename(file.path),
        'size': bytes,
        'duration': duration.inMilliseconds / 1000,
      });
      persist('locals', _localMeta);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _deleteLocal(Object? id) async {
    final meta = _localMeta.where((m) => m['id'] == id).firstOrNull;
    if (meta == null) return;
    final track = _tracks.where((t) => t.id == id).firstOrNull;
    if (track != null) await _remove(id);
    await _stopPreview();
    final file = File(await _localPath(meta));
    if (await file.exists()) await file.delete();
    final source = _sources.remove(id);
    if (source != null) {
      try {
        await _audio.disposeSource(source);
      } catch (_) {}
    }
    _localMeta.remove(meta);
    persist('locals', _localMeta);
    notifyListeners();
  }

  Future<void> _removeMissingLocals() async {
    final missing = <Map<String, dynamic>>[];
    for (final meta in _localMeta) {
      try {
        final file = File(await _localPath(meta));
        if (!await file.exists()) missing.add(meta);
      } catch (_) {
        missing.add(meta);
      }
    }
    if (missing.isNotEmpty) {
      _localMeta.removeWhere(missing.contains);
      persist('locals', _localMeta);
    }
  }

  Future<String> _localPath(Map<String, dynamic> meta) async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'imports', meta['file'] as String);
  }

  void _saveDraft() {
    persist('draft', {'tracks': tracks, 'master': _master, 'title': _title});
    _baseline = signature;
  }

  String _messageFor(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
    if (message.contains('SocketException') || message.contains('TimeoutException')) {
      return '网络连接失败，请检查网络后重试。';
    }
    if (message.contains('SoLoud') || message.contains('Audio')) {
      return '音频设备暂时不可用，请检查系统声音后重试。';
    }
    if (RegExp(r'[\u3400-\u9fff]').hasMatch(message)) return message;
    return '音频操作没有完成，请重试。';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _previewTimer?.cancel();
    for (final track in _tracks) {
      _stopHandle(track);
    }
    for (final handle in _previewHandles.values) {
      unawaited(_audio.stop(handle));
    }
    super.dispose();
  }
}

// ---------- WAV loop / noise synthesis ----------

Uint8List _loopWavBytes(Uint8List input) {
  try {
    final data = ByteData.sublistView(input);
    if (String.fromCharCodes(input.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(input.sublist(8, 12)) != 'WAVE') {
      return input;
    }
    int offset = 12;
    int? format, channels, sampleRate, bits, blockAlign, dataOffset, dataLength;
    while (offset + 8 <= input.length) {
      final id = String.fromCharCodes(input.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (id == 'fmt ' && start + 16 <= input.length) {
        format = data.getUint16(start, Endian.little);
        channels = data.getUint16(start + 2, Endian.little);
        sampleRate = data.getUint32(start + 4, Endian.little);
        blockAlign = data.getUint16(start + 12, Endian.little);
        bits = data.getUint16(start + 14, Endian.little);
      } else if (id == 'data') {
        dataOffset = start;
        dataLength = math.min(size, input.length - start);
        break;
      }
      offset = start + size + (size & 1);
    }
    if (format != 1 || bits != 16 || channels == null || channels < 1 ||
        channels > 2 || sampleRate == null || sampleRate <= 0 ||
        blockAlign == null || blockAlign < 2 || dataOffset == null ||
        dataLength == null) {
      return input;
    }
    final frames = dataLength ~/ blockAlign;
    final cross = math.min(
      (sampleRate * .12).floor(),
      (frames / 10).floor(),
    );
    if (cross < 2) return input;
    final outputFrames = frames - cross;
    final output = Uint8List(44 + outputFrames * blockAlign);
    final out = ByteData.sublistView(output);
    output.setAll(0, 'RIFF'.codeUnits);
    out.setUint32(4, 36 + outputFrames * blockAlign, Endian.little);
    output.setAll(8, 'WAVE'.codeUnits);
    output.setAll(12, 'fmt '.codeUnits);
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little);
    out.setUint16(22, channels, Endian.little);
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, sampleRate * blockAlign, Endian.little);
    out.setUint16(32, blockAlign, Endian.little);
    out.setUint16(34, 16, Endian.little);
    output.setAll(36, 'data'.codeUnits);
    out.setUint32(40, outputFrames * blockAlign, Endian.little);
    for (var frame = 0; frame < outputFrames; frame++) {
      for (var channel = 0; channel < channels; channel++) {
        int sample;
        if (frame < outputFrames - cross) {
          sample = data.getInt16(
            dataOffset + (frame + cross) * blockAlign + channel * 2,
            Endian.little,
          );
        } else {
          final i = frame - (outputFrames - cross);
          final tail = data.getInt16(
            dataOffset + (frames - cross + i) * blockAlign + channel * 2,
            Endian.little,
          );
          final head = data.getInt16(
            dataOffset + i * blockAlign + channel * 2,
            Endian.little,
          );
          final mix = (1 - math.cos(math.pi * i / (cross - 1))) / 2;
          sample = (tail * (1 - mix) + head * mix).round();
        }
        out.setInt16(
          44 + frame * blockAlign + channel * 2,
          sample.clamp(-32768, 32767),
          Endian.little,
        );
      }
    }
    return output;
  } catch (_) {
    return input;
  }
}
