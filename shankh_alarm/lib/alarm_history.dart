import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How a rung/missed alarm instance was ultimately resolved. Mirrors the
/// v2 spec's `AlarmHistoryEntity.outcome` enum (Section 22).
enum AlarmOutcome { dismissed, snoozedThenDismissed, autoStopped, missed }

extension on AlarmOutcome {
  String get wireValue => switch (this) {
        AlarmOutcome.dismissed => 'dismissed',
        AlarmOutcome.snoozedThenDismissed => 'snoozed_then_dismissed',
        AlarmOutcome.autoStopped => 'auto_stopped',
        AlarmOutcome.missed => 'missed',
      };
}

/// One row of the local alarm log: fixes v1 gaps G3 (no missed-alarm
/// visibility) and G5 (no history surfaced to the user). Purely local,
/// capped at [AlarmHistory.maxEntries] — no server, no analytics.
class AlarmHistoryEntry {
  final String eventType; // 'sunrise' | 'sunset'
  final DateTime scheduledAt;
  final AlarmOutcome outcome;
  final DateTime resolvedAt;
  final int snoozeCount;

  const AlarmHistoryEntry({
    required this.eventType,
    required this.scheduledAt,
    required this.outcome,
    required this.resolvedAt,
    required this.snoozeCount,
  });

  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'scheduledAt': scheduledAt.toUtc().millisecondsSinceEpoch,
        'outcome': outcome.wireValue,
        'resolvedAt': resolvedAt.toUtc().millisecondsSinceEpoch,
        'snoozeCount': snoozeCount,
      };

  static AlarmHistoryEntry fromJson(Map<String, dynamic> json) {
    AlarmOutcome outcome;
    switch (json['outcome'] as String?) {
      case 'snoozed_then_dismissed':
        outcome = AlarmOutcome.snoozedThenDismissed;
      case 'auto_stopped':
        outcome = AlarmOutcome.autoStopped;
      case 'missed':
        outcome = AlarmOutcome.missed;
      default:
        outcome = AlarmOutcome.dismissed;
    }
    return AlarmHistoryEntry(
      eventType: (json['eventType'] as String?) ?? 'sunrise',
      scheduledAt: DateTime.fromMillisecondsSinceEpoch((json['scheduledAt'] as num).toInt(), isUtc: true),
      outcome: outcome,
      resolvedAt: DateTime.fromMillisecondsSinceEpoch((json['resolvedAt'] as num).toInt(), isUtc: true),
      snoozeCount: (json['snoozeCount'] as num?)?.toInt() ?? 0,
    );
  }

  String get outcomeLabel => switch (outcome) {
        AlarmOutcome.dismissed => 'Dismissed',
        AlarmOutcome.snoozedThenDismissed => 'Snoozed then dismissed',
        AlarmOutcome.autoStopped => 'Auto-stopped (unattended)',
        AlarmOutcome.missed => 'Missed',
      };
}

/// Local, capped alarm history log (fixes G3/G5, implements ALM-FR-012).
/// Stored as a JSON array in SharedPreferences — this app's whole dataset
/// is tiny (at most 30 rows), so a full Room-style database is unwarranted.
class AlarmHistory {
  AlarmHistory._();

  static const maxEntries = 30;
  static const _key = 'alarm_history_v1';

  static Future<List<AlarmHistoryEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((s) => AlarmHistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.resolvedAt.compareTo(a.resolvedAt));
  }

  static Future<void> record(AlarmHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final entries = raw
        .map((s) => AlarmHistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..add(entry)
      ..sort((a, b) => b.resolvedAt.compareTo(a.resolvedAt));
    final capped = entries.take(maxEntries).map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, capped);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
