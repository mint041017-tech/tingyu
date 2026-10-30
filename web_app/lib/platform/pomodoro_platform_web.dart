import 'dart:js_interop';

@JS('tingyuChime')
external bool _chime(JSString kind, JSNumber volume);

@JS('tingyuNotify')
external bool _notify(JSString title, JSString body);

@JS('tingyuNotificationPermission')
external JSString _notificationPermission();

@JS('tingyuRequestNotification')
external JSPromise<JSString> _requestNotification();

@JS('tingyuSetTitle')
external void _setTitle(JSString title);

@JS('tingyuVibrate')
external void _vibrate(JSNumber milliseconds);

class PomodoroPlatform {
  static const bool supportsScheduling = false;

  static String get permission {
    try {
      return _notificationPermission().toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  static Future<void> init() async {}

  static Future<void> chime(String kind, int volumePercent) async {
    try {
      _chime(kind.toJS, (volumePercent / 100).toJS);
    } catch (_) {}
  }

  static Future<void> vibrate() async {
    try {
      _vibrate(18.toJS);
    } catch (_) {}
  }

  static Future<String> requestNotificationPermission() async {
    try {
      return (await _requestNotification().toDart).toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  static Future<void> scheduleNotification(
    DateTime when,
    String title,
    String body,
  ) async {}

  static Future<void> cancelScheduledNotification() async {}

  static Future<void> notifyNow(String title, String body) async {
    try {
      _notify(title.toJS, body.toJS);
    } catch (_) {}
  }

  static Future<void> setTitle(String title) async {
    try {
      _setTitle(title.toJS);
    } catch (_) {}
  }
}
