import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:window_manager/window_manager.dart';

const _channelId = 'pomodoro';
const _notificationId = 1101;

class PomodoroPlatform {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final Map<String, AudioSource> _chimes = {};
  static bool _initialized = false;
  static String _permission = 'default';

  /// 桌面端应用进程在后台仍运行，完成时即时提示；
  /// Android/iOS 用系统定时通知覆盖锁屏与后台。
  static bool get supportsScheduling =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get permission => _permission;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await localNotifier.setup(appName: '听隅');
        _permission = 'granted';
        return;
      }
      final ok = await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_tingyu'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await android?.areNotificationsEnabled();
        _permission = enabled == true ? 'granted' : 'default';
      } else if (ok == true) {
        _permission = 'granted';
      }
    } catch (_) {
      _permission = 'unsupported';
    }
  }

  static Future<void> chime(String kind, int volumePercent) async {
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(
          sampleRate: 48000,
          bufferSize: 2048,
          channels: Channels.stereo,
        );
      }
      final wood = kind == 'wood';
      final asset = wood
          ? 'assets/audio/chime_wood.wav'
          : 'assets/audio/chime_bell.wav';
      final source = _chimes[asset] ??= await SoLoud.instance.loadAsset(asset);
      final volume = (volumePercent / 100).clamp(0.0, 1.0).toDouble();
      final handle = SoLoud.instance.play(source, volume: volume);
      Timer(Duration(milliseconds: wood ? 1100 : 2800), () {
        SoLoud.instance.stop(handle);
      });
    } catch (_) {}
  }

  static Future<void> vibrate() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<String> requestNotificationPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final ok = await android?.requestNotificationsPermission();
        _permission = ok == true ? 'granted' : 'denied';
        return _permission;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final ok = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permission = ok == true ? 'granted' : 'denied';
        return _permission;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final mac = _notifications
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        final ok = await mac?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permission = ok == true ? 'granted' : 'denied';
        return _permission;
      }
      _permission = _permission == 'unsupported' ? 'denied' : 'granted';
      return _permission;
    } catch (_) {
      _permission = 'unsupported';
      return _permission;
    }
  }

  static NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      '番茄钟',
      channelDescription: '专注与休息结束提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_tingyu',
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  static Future<void> scheduleNotification(
    DateTime when,
    String title,
    String body,
  ) async {
    if (!supportsScheduling || _permission != 'granted') return;
    try {
      await _notifications.zonedSchedule(
        _notificationId,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'pomodoro',
      );
    } catch (_) {}
  }

  static Future<void> cancelScheduledNotification() async {
    if (!supportsScheduling) return;
    try {
      await _notifications.cancel(_notificationId);
    } catch (_) {}
  }

  static Future<void> notifyNow(String title, String body) async {
    if (_permission == 'denied' || _permission == 'unsupported') return;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await localNotifier.notify(
          LocalNotification(title: title, body: body),
        );
        return;
      }
      await _notifications.show(
        _notificationId + 1,
        title,
        body,
        _details,
      );
    } catch (_) {}
  }

  static Future<void> setTitle(String title) async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        await windowManager.setTitle(title);
      } else if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // 移动端标题由系统任务卡片维护，不覆盖应用名。
      }
    } catch (_) {}
  }
}
