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

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    // On Android 14+, USE_FULL_SCREEN_INTENT is granted by default only to
    // apps the Play Store recognizes as having calling/alarm functionality
    // — otherwise it can be silently revoked, in which case the alarm
    // notification never auto-launches AlarmScreen (where the shankh sound
    // actually plays) when the phone is locked, and the alarm looks like it
    // "does nothing". This surfaces the OS grant dialog when needed; it's a
    // no-op if already granted. See Section 26 of the spec.
    await android?.requestFullScreenIntentPermission();
  }

  /// Re-checked from the Reliability Checklist screen: same call, exposed
  /// so it can be triggered from a "Fix this" button too, not just on
  /// cold start / alarm firing.
  static Future<bool?> requestFullScreenIntentPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestFullScreenIntentPermission();
  }

  /// Shows the full-screen, ongoing "alarm ringing" notification. When the
  /// screen is off or the device is locked, Android auto-launches the
  /// [fullScreenIntent] (this app), landing the user on the alarm-ringing
  /// screen; otherwise it appears as a heads-up notification with Stop /
  /// Snooze actions.
  static Future<void> showAlarmNotification({required bool sunrise, int? scheduledAtMillis}) async {
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
      payload: scheduledAtMillis == null
          ? (sunrise ? 'sunrise' : 'sunset')
          : '${sunrise ? 'sunrise' : 'sunset'}|$scheduledAtMillis',
    );
  }

  static Future<void> cancelAlarmNotification() => _plugin.cancel(id: 42);

  /// Payload is `eventType` or `eventType|scheduledAtEpochMillis` — kept as
  /// a single delimited string since notification payloads must be plain
  /// text, but callers need the original scheduled instant for history
  /// logging (Section 22).
  static (String eventType, int? scheduledAtMillis) decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return ('sunrise', null);
    final parts = payload.split('|');
    final eventType = parts.first;
    final scheduledAtMillis = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return (eventType, scheduledAtMillis);
  }
}
