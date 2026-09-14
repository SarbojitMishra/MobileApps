import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps flutter_local_notifications setup: the high-priority alarm channel
/// (full-screen intent, alarm-category, its own sound as a safety net) plus
/// the Stop / Snooze actions — mirroring the original app's notification
/// channels and AlarmService notification.
class NotificationService {
  NotificationService._();

  static const channelAlarmId = 'shankh_alarm_channel';
  static const channelAlarmName = 'Shankh Alarm';
  static const channelAlarmDesc = 'Sunrise and sunset conch alarm';

  static const actionStopId = 'stop';
  static const actionSnoozeId = 'snooze';

  static final _plugin = FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> init({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Shows the full-screen, ongoing "alarm ringing" notification. When the
  /// screen is off or the device is locked, Android auto-launches the
  /// [fullScreenIntent] (this app), landing the user on the alarm-ringing
  /// screen; otherwise it appears as a heads-up notification with Stop /
  /// Snooze actions.
  static Future<void> showAlarmNotification({required bool sunrise}) async {
    final label = sunrise ? 'Sunrise' : 'Sunset';
    const androidDetails = AndroidNotificationDetails(
      channelAlarmId,
      channelAlarmName,
      channelDescription: channelAlarmDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('shankh_alarm'),
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction(actionStopId, 'Stop', cancelNotification: true),
        AndroidNotificationAction(actionSnoozeId, 'Snooze 5 min', cancelNotification: true),
      ],
    );
    await _plugin.show(
      id: 42,
      title: '$label — Shankh Alarm',
      body: 'Tap to view, or Stop to silence.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: sunrise ? 'sunrise' : 'sunset',
    );
  }

  static Future<void> cancelAlarmNotification() => _plugin.cancel(id: 42);
}
