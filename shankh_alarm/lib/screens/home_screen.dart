import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../alarm_scheduler.dart';
import '../location_service.dart';
import '../prefs.dart';
import '../sun_calculator.dart';
import '../theme.dart';

/// Settings screen: today's sunrise/sunset, enable toggles, location source,
/// and the "allow exact alarms" / "ignore battery optimization" helper
/// buttons. Mirrors the original app's MainActivity + activity_main.xml.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _sunriseEnabled = true;
  bool _sunsetEnabled = true;
  bool _useDeviceLocation = true;
  String _locationName = Prefs.defaultLocationName;

  String? _todaySunrise;
  String? _todaySunset;
  String? _nextAlarmText;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDisplayedTimes();
    }
  }

  Future<void> _bootstrap() async {
    _sunriseEnabled = await Prefs.isSunriseEnabled();
    _sunsetEnabled = await Prefs.isSunsetEnabled();
    _useDeviceLocation = await Prefs.getUseDeviceLocation();
    _locationName = await Prefs.getLocationName();
    setState(() => _loading = false);

    await _requestNotificationPermissionIfNeeded();
    await _requestPermissionsIfNeededThenRefresh();
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    await Permission.notification.request();
  }

  Future<void> _requestPermissionsIfNeededThenRefresh() async {
    final wantsDeviceLocation = await Prefs.getUseDeviceLocation();
    if (wantsDeviceLocation && !await LocationService.hasPermission()) {
      await LocationService.requestPermission();
      await _refreshAndReschedule(useFreshGps: true);
    } else {
      await _refreshAndReschedule(useFreshGps: wantsDeviceLocation);
    }
  }

  Future<void> _refreshAndReschedule({required bool useFreshGps}) async {
    // resolveActiveLocation persists lat/lon + a location name when device
    // location is used, falling back to the stored/default location.
    await LocationService.resolveActiveLocation(useFreshGps: useFreshGps);
    _locationName = await Prefs.getLocationName();
    if (mounted) setState(() {});
    await AlarmScheduler.scheduleAll();
    await _refreshDisplayedTimes();
  }

  Future<void> _rescheduleOnly() async {
    await AlarmScheduler.scheduleAll();
    await _refreshDisplayedTimes();
  }

  Future<void> _refreshDisplayedTimes() async {
    final lat = await Prefs.getLatitude();
    final lon = await Prefs.getLongitude();
    final today = SunCalculator.calculate(DateTime.now(), lat, lon);
    final (nextTime, nextLabel) = await AlarmScheduler.nextAlarm();

    String fmtLocal(DateTime? utc) {
      if (utc == null) return '—';
      final local = utc.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    }

    String fmtNext(DateTime? utc, String? label) {
      if (utc == null || label == null) return 'Next alarm: —';
      final local = utc.toLocal();
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final wd = weekdays[local.weekday - 1];
      final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
      return 'Next alarm: $label at $wd ${local.day} ${months[local.month - 1]}, $time';
    }

    if (!mounted) return;
    setState(() {
      _todaySunrise = 'Sunrise: ${fmtLocal(today.sunriseUtc)}';
      _todaySunset = 'Sunset: ${fmtLocal(today.sunsetUtc)}';
      _nextAlarmText = fmtNext(nextTime, nextLabel);
    });
  }

  Future<void> _openExactAlarmSettings() async {
    try {
      await const AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      ).launch();
    } on PlatformException {
      // Older Android versions don't have this settings screen; exact
      // alarms don't require the grant there anyway.
    }
  }

  Future<void> _requestIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shankh Alarm',
                style: TextStyle(color: AppColors.ink, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _locationName,
                style: const TextStyle(color: AppColors.saffronDark, fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Text('Today', style: TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_todaySunrise ?? 'Sunrise: —', style: const TextStyle(color: AppColors.ink, fontSize: 16)),
              Text(_todaySunset ?? 'Sunset: —', style: const TextStyle(color: AppColors.ink, fontSize: 16)),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sunrise', style: TextStyle(color: AppColors.ink)),
                value: _sunriseEnabled,
                onChanged: (v) async {
                  setState(() => _sunriseEnabled = v);
                  await Prefs.setSunriseEnabled(v);
                  await _rescheduleOnly();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sunset', style: TextStyle(color: AppColors.ink)),
                value: _sunsetEnabled,
                onChanged: (v) async {
                  setState(() => _sunsetEnabled = v);
                  await Prefs.setSunsetEnabled(v);
                  await _rescheduleOnly();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use my current location', style: TextStyle(color: AppColors.ink)),
                value: _useDeviceLocation,
                onChanged: (v) async {
                  setState(() => _useDeviceLocation = v);
                  await Prefs.setUseDeviceLocation(v);
                  if (!v) {
                    await Prefs.resetToDefaultLocation();
                    _locationName = await Prefs.getLocationName();
                  }
                  await _requestPermissionsIfNeededThenRefresh();
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.saffron, foregroundColor: AppColors.ink),
                  onPressed: _requestPermissionsIfNeededThenRefresh,
                  child: const Text('Refresh location & re-schedule'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepMaroon, foregroundColor: AppColors.cream),
                  onPressed: _openExactAlarmSettings,
                  child: const Text('Allow exact alarms (if prompted)'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepMaroon, foregroundColor: AppColors.cream),
                  onPressed: _requestIgnoreBatteryOptimizations,
                  child: const Text('Ignore battery optimization'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _nextAlarmText ?? 'Next alarm: —',
                style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
