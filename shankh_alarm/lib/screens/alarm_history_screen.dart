import 'package:flutter/material.dart';

import '../alarm_history.dart';
import '../theme.dart';

/// Last 30 fired/missed/auto-stopped events (ALM-FR-012, fixes G3/G5): lets
/// the user answer "did it actually ring yesterday?" instead of it being
/// invisible, as in v1.
class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({super.key});

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen> {
  List<AlarmHistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await AlarmHistory.all();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    await AlarmHistory.clear();
    await _load();
  }

  String _fmt(DateTime utc) {
    final local = utc.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${local.day} ${months[local.month - 1]}, $time';
  }

  Color _outcomeColor(AlarmOutcome outcome) => switch (outcome) {
        AlarmOutcome.dismissed => Colors.green,
        AlarmOutcome.snoozedThenDismissed => Colors.green,
        AlarmOutcome.autoStopped => AppColors.saffronDark,
        AlarmOutcome.missed => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm History'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear history',
              onPressed: _clear,
            ),
        ],
      ),
      backgroundColor: AppColors.cream,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No alarms recorded yet. Fired, missed, and '
                      'auto-stopped alarms will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.ink),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    final label = e.eventType == 'sunrise' ? 'Sunrise' : 'Sunset';
                    return ListTile(
                      leading: Icon(
                        e.eventType == 'sunrise' ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                        color: _outcomeColor(e.outcome),
                      ),
                      title: Text('$label — ${_fmt(e.scheduledAt)}', style: const TextStyle(color: AppColors.ink)),
                      subtitle: Text(
                        e.outcomeLabel + (e.snoozeCount > 0 ? ' (snoozed ${e.snoozeCount}x)' : ''),
                        style: TextStyle(color: _outcomeColor(e.outcome)),
                      ),
                    );
                  },
                ),
    );
  }
}
