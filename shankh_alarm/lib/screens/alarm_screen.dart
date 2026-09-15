import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../alarm_history.dart';
import '../alarm_scheduler.dart';
import '../notification_service.dart';
import '../prefs.dart';
import '../theme.dart';

/// Ringing stops itself if nobody touches Stop/Snooze for this long
/// (ALM-FR-011) — elevates v1's wake-lock safety cap into an explicit,
/// user-facing, logged behaviour instead of a silent timeout.
const Duration autoStopAfter = Duration(minutes: 10);

/// The actual "alarm going off" screen — shown full-screen (over the lock
/// screen, over whatever the user was doing), like a stock alarm clock app.
/// Stop silences playback; Snooze re-rings in 5 minutes, capped at
/// [Prefs.maxSnoozeCount] uses (ALM-FR-010). Mirrors the original app's
/// AlarmActivity.
class AlarmScreen extends StatefulWidget {
  final String eventType;
  final int? scheduledAtMillis;
  const AlarmScreen({super.key, required this.eventType, this.scheduledAtMillis});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final _player = AudioPlayer();
  String _locationName = Prefs.defaultLocationName;
  late final Timer _clockTimer;
  Timer? _autoStopTimer;
  DateTime _now = DateTime.now();
  int _snoozeCount = 0;
  bool _resolved = false;

  bool get _sunrise => widget.eventType == eventSunrise;

  DateTime get _scheduledAt => widget.scheduledAtMillis != null
      ? DateTime.fromMillisecondsSinceEpoch(widget.scheduledAtMillis!, isUtc: true)
      : DateTime.now();

  @override
  void initState() {
    super.initState();
    _startRinging();
    _startVibrating();
    _autoStopTimer = Timer(autoStopAfter, _onAutoStop);
    Prefs.getLocationName().then((name) {
      if (mounted) setState(() => _locationName = name);
    });
    Prefs.getSnoozeCount(widget.eventType).then((count) {
      if (mounted) setState(() => _snoozeCount = count);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _startRinging() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
          stayAwake: true,
        ),
      ),
    );
    await _player.setVolume(1.0);
    await _player.play(AssetSource('audio/shankh_alarm.ogg'));
  }

  Future<void> _startVibrating() async {
    if (await Vibration.hasVibrator()) {
      // Slow, resonant pulses reminiscent of a temple conch call.
      Vibration.vibrate(pattern: [0, 1200, 600, 1200, 600], repeat: 0);
    }
  }

  Future<void> _stopEverything() async {
    _autoStopTimer?.cancel();
    await _player.stop();
    Vibration.cancel();
    await NotificationService.cancelAlarmNotification();
  }

  Future<void> _recordOutcome(AlarmOutcome outcome) async {
    await AlarmHistory.record(AlarmHistoryEntry(
      eventType: widget.eventType,
      scheduledAt: _scheduledAt,
      outcome: outcome,
      resolvedAt: DateTime.now(),
      snoozeCount: _snoozeCount,
    ));
    await Prefs.resetSnoozeCount(widget.eventType);
  }

  Future<void> _onStop() async {
    if (_resolved) return;
    _resolved = true;
    await _stopEverything();
    await _recordOutcome(
      _snoozeCount > 0 ? AlarmOutcome.snoozedThenDismissed : AlarmOutcome.dismissed,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onAutoStop() async {
    if (_resolved) return;
    _resolved = true;
    await _stopEverything();
    await _recordOutcome(AlarmOutcome.autoStopped);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onSnooze() async {
    if (_resolved) return;
    if (_snoozeCount >= Prefs.maxSnoozeCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 3 snoozes reached for this alarm.')),
      );
      return;
    }
    _resolved = true;
    final newCount = _snoozeCount + 1;
    await Prefs.setSnoozeCount(widget.eventType, newCount);
    await _stopEverything();
    await AlarmScheduler.snooze(widget.eventType, _scheduledAt.millisecondsSinceEpoch);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _autoStopTimer?.cancel();
    Vibration.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeText =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';
    final snoozeLabel = _snoozeCount >= Prefs.maxSnoozeCount
        ? 'Snooze limit reached'
        : 'Snooze 5 min ($_snoozeCount/${Prefs.maxSnoozeCount} used)';
    return PopScope(
      // An alarm shouldn't be dismissible by accident (mirrors the
      // original AlarmActivity swallowing the back press).
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.deepMaroon,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _sunrise ? 'SUNRISE' : 'SUNSET',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timeText,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _locationName,
                  style: const TextStyle(color: AppColors.gold, fontSize: 14),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.saffron,
                      foregroundColor: AppColors.ink,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: _onStop,
                    child: const Text('Stop'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _snoozeCount >= Prefs.maxSnoozeCount ? Colors.grey : AppColors.gold,
                      ),
                      foregroundColor: _snoozeCount >= Prefs.maxSnoozeCount ? Colors.grey : AppColors.gold,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _onSnooze,
                    child: Text(snoozeLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
