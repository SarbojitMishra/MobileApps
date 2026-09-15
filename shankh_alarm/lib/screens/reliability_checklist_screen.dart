import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme.dart';

/// Consolidates the manual mitigations a device's OEM battery/background
/// management can require (Section 11.4, UI-FR-002) into one screen with
/// live status where Android exposes it, instead of leaving this only in
/// the README as v1 did.
class ReliabilityChecklistScreen extends StatefulWidget {
  const ReliabilityChecklistScreen({super.key});

  @override
  State<ReliabilityChecklistScreen> createState() => _ReliabilityChecklistScreenState();
}

class _ReliabilityChecklistScreenState extends State<ReliabilityChecklistScreen>
    with WidgetsBindingObserver {
  bool? _batteryExempt;
  bool? _exactAlarmAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user grants these in a system settings screen and comes straight
    // back here, so re-check on resume rather than making them back out.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final battery = await Permission.ignoreBatteryOptimizations.status;
    bool? exact;
    try {
      exact = (await Permission.scheduleExactAlarm.status).isGranted;
    } catch (_) {
      // Not applicable below Android 12 — treat as "not required" (shown as
      // granted) rather than a false warning.
      exact = true;
    }
    if (!mounted) return;
    setState(() {
      _batteryExempt = battery.isGranted;
      _exactAlarmAllowed = exact;
    });
  }

  Future<void> _requestBatteryExemption() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _refreshStatus();
  }

  Future<void> _openExactAlarmSettings() async {
    try {
      await const AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      ).launch();
    } on PlatformException {
      // Older Android versions don't have this settings screen.
    }
    await _refreshStatus();
  }

  Future<void> _openRecentsHelp() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lock the app in Recents'),
        content: const Text(
          'Open the recent-apps switcher, find Shankh Alarm\'s card, '
          'long-press it, and tap the lock icon. This stops the OS from '
          'sweeping it away when clearing recent apps.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  Future<void> _openAutostartHelp() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Autostart permission (VIVO / FunTouch / OriginOS)'),
        content: const Text(
          'VIVO devices hide a separate "Autostart" switch that Android '
          'itself has no API to check or flip, so it can\'t be automated:\n\n'
          'Settings → More settings → Permission manager → Autostart\n'
          '(or i Manager → App manager → Autostart manager)\n\n'
          'Enable it for Shankh Alarm so the alarm chain can restore itself '
          'after a reboot without you opening the app.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reliability Checklist')),
      backgroundColor: AppColors.cream,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'These are the switches most likely to stop the alarm from '
            'firing on an OEM (especially VIVO) that aggressively kills '
            'background apps. Fix every item below.',
            style: TextStyle(color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          _ChecklistTile(
            title: 'Battery optimization exemption',
            status: _batteryExempt,
            onFix: _requestBatteryExemption,
          ),
          _ChecklistTile(
            title: 'Exact alarm permission',
            status: _exactAlarmAllowed,
            onFix: _openExactAlarmSettings,
          ),
          _ChecklistTile(
            title: 'Autostart permission (VIVO-specific — please verify manually)',
            status: null,
            onFix: _openAutostartHelp,
          ),
          _ChecklistTile(
            title: 'Locked in Recents',
            status: null,
            onFix: _openRecentsHelp,
          ),
          const SizedBox(height: 16),
          const Text(
            'Note: some OEM "Total Silence" Do Not Disturb modes can still '
            'block alarm audio even with everything above granted — this is '
            'a known platform limitation, not a bug in this app.',
            style: TextStyle(color: AppColors.saffronDark, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final String title;
  final bool? status; // null = can't be detected, must verify manually
  final VoidCallback onFix;

  const _ChecklistTile({required this.title, required this.status, required this.onFix});

  @override
  Widget build(BuildContext context) {
    final Icon icon;
    if (status == true) {
      icon = const Icon(Icons.check_circle, color: Colors.green);
    } else if (status == false) {
      icon = const Icon(Icons.error, color: Colors.red);
    } else {
      icon = const Icon(Icons.help_outline, color: AppColors.saffronDark);
    }
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: icon,
        title: Text(title, style: const TextStyle(color: AppColors.ink)),
        subtitle: Text(
          status == true
              ? 'Granted'
              : status == false
                  ? 'Not granted'
                  : 'Cannot be checked automatically — verify manually',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: TextButton(onPressed: onFix, child: const Text('Fix this')),
      ),
    );
  }
}
