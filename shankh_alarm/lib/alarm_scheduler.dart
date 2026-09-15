import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alarm_history.dart';
import 'alarm_port.dart';
import 'notification_service.dart';
import 'prefs.dart';
import 'sun_calculator.dart';

const String eventSunrise = 'sunrise';
const String eventSunset = 'sunset';

/// A firing more than this late after its intended instant is treated as a
/// missed alarm (device was off/killed through the instant) rather than a
/// real ring — it is logged, not sounded (ALM-FR-012, fixes G3).
const Duration missedAlarmThreshold = Duration(minutes: 3);

/// Owns the "one alarm scheduled per event type, reschedule-on-fire" chain.
///
/// Rather than trying to hand the OS hundreds of separate alarms, this
/// computes just the *next* sunrise and next sunset instant (offline, via
/// [SunCalculator]) and schedules those two using [AndroidAlarmManager],
/// which under the hood uses `AlarmManager.setAlarmClock` when `alarmClock:
/// true` is passed — the same mechanism real alarm-clock apps use, exempt
/// from Doze/App-Standby deferral. The moment an alarm fires it reschedules
/// its own following occurrence, so the chain is self-sustaining, and
/// `rescheduleOnReboot: true` restores it after the device restarts.
class AlarmScheduler {
  AlarmScheduler._();

  static const int sunriseAlarmId = 1001;
  static const int sunsetAlarmId = 1002;

  static Future<void> initialize() => AndroidAlarmManager.initialize();

  /// Recomputes and (re)schedules the next sunrise/sunset alarms, or cancels
  /// whichever event type is disabled.
  static Future<void> scheduleAll() async {
    final sunriseOn = await Prefs.isSunriseEnabled();
    final sunsetOn = await Prefs.isSunsetEnabled();
    if (sunriseOn) {
      await _scheduleNext(eventSunrise);
    } else {
      await AndroidAlarmManager.cancel(sunriseAlarmId);
    }
    if (sunsetOn) {
      await _scheduleNext(eventSunset);
    } else {
      await AndroidAlarmManager.cancel(sunsetAlarmId);
    }
  }

  static Future<void> _scheduleNext(String eventType) async {
    final lat = await Prefs.getLatitude();
    final lon = await Prefs.getLongitude();
    final next = SunCalculator.nextOccurrence(
      after: DateTime.now(),
      latitude: lat,
      longitude: lon,
      sunrise: eventType == eventSunrise,
    );
    if (next == null) return; // shouldn't happen outside polar latitudes
    final id = eventType == eventSunrise ? sunriseAlarmId : sunsetAlarmId;
    try {
      await AndroidAlarmManager.oneShotAt(
        next,
        id,
        alarmFired,
        alarmClock: true,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: {
          'eventType': eventType,
          'scheduledAtMillis': next.toUtc().millisecondsSinceEpoch,
        },
      );
      await Prefs.setSchedulingWarning(eventType, null);
    } catch (e) {
      // Fail loud, not silent (Design Principle 3): a revoked exact-alarm
      // permission or OEM restriction throws here rather than the alarm
      // just quietly never firing again.
      await Prefs.setSchedulingWarning(
        eventType,
        'Could not schedule the next $eventType alarm ($e). Check the '
        'Reliability Checklist for a blocked permission.',
      );
    }
  }

  /// Re-rings [eventType] in 5 minutes, replacing whatever was next
  /// scheduled for that event type (same id -> AlarmManager replaces it).
  /// [scheduledAtMillis] is carried through unchanged so the eventual
  /// Stop/dismiss is logged against the *original* instant, not the snooze.
  static Future<void> snooze(String eventType, int scheduledAtMillis) async {
    final id = eventType == eventSunrise ? sunriseAlarmId : sunsetAlarmId;
    await AndroidAlarmManager.oneShotAt(
      DateTime.now().add(const Duration(minutes: 5)),
      id,
      alarmFired,
      alarmClock: true,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {
        'eventType': eventType,
        'scheduledAtMillis': scheduledAtMillis,
        'isSnoozeReplay': true,
      },
    );
  }

  static Future<(DateTime? time, String? label)> nextAlarm() async {
    final sunriseOn = await Prefs.isSunriseEnabled();
    final sunsetOn = await Prefs.isSunsetEnabled();
    final lat = await Prefs.getLatitude();
    final lon = await Prefs.getLongitude();
    final now = DateTime.now();

    final candidates = <(DateTime, String)>[];
    if (sunriseOn) {
      final t = SunCalculator.nextOccurrence(after: now, latitude: lat, longitude: lon, sunrise: true);
      if (t != null) candidates.add((t, 'Sunrise'));
    }
    if (sunsetOn) {
      final t = SunCalculator.nextOccurrence(after: now, latitude: lat, longitude: lon, sunrise: false);
      if (t != null) candidates.add((t, 'Sunset'));
    }
    if (candidates.isEmpty) return (null, null);
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    return candidates.first;
  }
}

/// Runs in a background isolate spawned by AndroidAlarmManager when a
/// sunrise/sunset alarm fires — whether or not the app is running.
@pragma('vm:entry-point')
void alarmFired(int id, Map<String, dynamic> params) async {
  DartPluginRegistrant.ensureInitialized();

  final eventType = (params['eventType'] as String?) ?? eventSunrise;
  final sunrise = eventType == eventSunrise;
  final scheduledAtMillis = (params['scheduledAtMillis'] as num?)?.toInt();
  final isSnoozeReplay = params['isSnoozeReplay'] == true;

  // A firing this late means the device was off/Doze-killed through the
  // original instant (a snooze replay is deliberately +5 min "late" and is
  // never treated as missed). Log it and move straight to the next future
  // event instead of ringing at the wrong time (fixes G3).
  if (!isSnoozeReplay && scheduledAtMillis != null) {
    final scheduledAt = DateTime.fromMillisecondsSinceEpoch(scheduledAtMillis, isUtc: true);
    final lateness = DateTime.now().toUtc().difference(scheduledAt);
    if (lateness > missedAlarmThreshold) {
      await AlarmHistory.record(AlarmHistoryEntry(
        eventType: eventType,
        scheduledAt: scheduledAt,
        outcome: AlarmOutcome.missed,
        resolvedAt: DateTime.now(),
        snoozeCount: 0,
      ));
      await Prefs.resetSnoozeCount(eventType);
      await AlarmScheduler._scheduleNext(eventType);
      return;
    }
  }

  if (!isSnoozeReplay) {
    await Prefs.resetSnoozeCount(eventType);
  }

  // If the app process is alive, wake it directly so it can start ringing
  // immediately instead of waiting for a notification tap.
  AlarmPort.notify(eventType, scheduledAtMillis);

  // Always post the notification too: it's what launches the app (via its
  // full-screen intent) when the device is locked or the app was killed,
  // and it gives the user a way back to the ringing screen either way.
  await NotificationService.init();
  await NotificationService.showAlarmNotification(sunrise: sunrise, scheduledAtMillis: scheduledAtMillis);

  // Keep the chain alive: queue the following occurrence of this same event.
  await AlarmScheduler._scheduleNext(eventType);
}

/// Runs in a background isolate when the user taps a notification action
/// (Stop / Snooze) while the app isn't in the foreground.
@pragma('vm:entry-point')
void notificationBackgroundTapHandler(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  final (eventType, scheduledAtMillis) = NotificationService.decodePayload(response.payload);

  if (response.actionId == NotificationService.actionSnoozeId) {
    final count = await Prefs.getSnoozeCount(eventType);
    if (count < Prefs.maxSnoozeCount) {
      await Prefs.setSnoozeCount(eventType, count + 1);
      await AlarmScheduler.initialize();
      await AlarmScheduler.snooze(eventType, scheduledAtMillis ?? DateTime.now().millisecondsSinceEpoch);
    }
    // 4th+ attempt: refused silently here (no UI to show a message from a
    // background isolate) — the alarm keeps ringing via the still-open
    // full-screen AlarmActivity/AlarmScreen, same as ALM-FR-010 intends.
  }
  await NotificationService.cancelAlarmNotification();
}
