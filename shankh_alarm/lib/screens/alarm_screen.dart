import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../alarm_scheduler.dart';
import '../notification_service.dart';
import '../prefs.dart';
import '../theme.dart';

/// The actual "alarm going off" screen — shown full-screen (over the lock
/// screen, over whatever the user was doing), like a stock alarm clock app.
/// Stop silences playback; Snooze re-rings in 5 minutes. Mirrors the
/// original app's AlarmActivity.
class AlarmScreen extends StatefulWidget {
  final String eventType;
  const AlarmScreen({super.key, required this.eventType});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final _player = AudioPlayer();
  String _locationName = Prefs.defaultLocationName;
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  bool get _sunrise => widget.eventType == eventSunrise;

  @override
  void initState() {
    super.initState();
    _startRinging();
    _startVibrating();
    Prefs.getLocationName().then((name) {
      if (mounted) setState(() => _locationName = name);
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
    await _player.stop();
    Vibration.cancel();
    await NotificationService.cancelAlarmNotification();
  }

  Future<void> _onStop() async {
    await _stopEverything();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onSnooze() async {
    await _stopEverything();
    await AlarmScheduler.snooze(widget.eventType);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    Vibration.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeText =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';
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
                      side: const BorderSide(color: AppColors.gold),
                      foregroundColor: AppColors.gold,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _onSnooze,
                    child: const Text('Snooze 5 min'),
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
