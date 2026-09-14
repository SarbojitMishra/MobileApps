import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alarm_port.dart';
import 'alarm_scheduler.dart';
import 'notification_service.dart';
import 'screens/alarm_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AlarmScheduler.initialize();
  await NotificationService.init(
    onDidReceiveNotificationResponse: _onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: notificationBackgroundTapHandler,
  );

  // If the app process is already alive when a sunrise/sunset alarm fires,
  // the background isolate sends the event type straight to this listener
  // so the ringing screen appears immediately, without waiting for a
  // notification tap.
  AlarmPort.registerListener((eventType) => _navigateToAlarm(eventType));

  // Cold start via the alarm's full-screen intent notification (device was
  // locked, or the app had been killed): jump straight to the ringing
  // screen once the first frame is up.
  final launchDetails = await NotificationService.plugin.getNotificationAppLaunchDetails();
  final launchedFromAlarm = launchDetails?.didNotificationLaunchApp == true
      ? launchDetails!.notificationResponse?.payload
      : null;

  runApp(ShankhAlarmApp(initialAlarmEventType: launchedFromAlarm));

  await AlarmScheduler.scheduleAll();
}

void _onNotificationResponse(NotificationResponse response) {
  final eventType = response.payload ?? eventSunrise;
  if (response.actionId == NotificationService.actionSnoozeId) {
    AlarmScheduler.snooze(eventType);
    NotificationService.cancelAlarmNotification();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    return;
  }
  if (response.actionId == NotificationService.actionStopId) {
    NotificationService.cancelAlarmNotification();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    return;
  }
  _navigateToAlarm(eventType);
}

void _navigateToAlarm(String eventType) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(MaterialPageRoute(builder: (_) => AlarmScreen(eventType: eventType)));
}

class ShankhAlarmApp extends StatefulWidget {
  final String? initialAlarmEventType;
  const ShankhAlarmApp({super.key, this.initialAlarmEventType});

  @override
  State<ShankhAlarmApp> createState() => _ShankhAlarmAppState();
}

class _ShankhAlarmAppState extends State<ShankhAlarmApp> {
  @override
  void initState() {
    super.initState();
    final eventType = widget.initialAlarmEventType;
    if (eventType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToAlarm(eventType));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shankh Alarm',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
