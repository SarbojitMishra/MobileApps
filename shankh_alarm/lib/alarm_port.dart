import 'dart:isolate';
import 'dart:ui';

/// Lets the background alarm isolate wake the live app instantly (no need to
/// wait for the user to tap the notification) when the app process is still
/// alive, via a named [SendPort] registered through [IsolateNameServer].
class AlarmPort {
  AlarmPort._();

  static const _portName = 'shankh_alarm_port';

  /// Call once from the main isolate, before any alarm can fire.
  static void registerListener(void Function(String eventType, int? scheduledAtMillis) onFired) {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(port.sendPort, _portName);
    port.listen((message) {
      if (message is! String) return;
      final parts = message.split('|');
      final eventType = parts.first;
      final scheduledAtMillis = parts.length > 1 ? int.tryParse(parts[1]) : null;
      onFired(eventType, scheduledAtMillis);
    });
  }

  /// Call from the background isolate when an alarm fires. Returns true if
  /// the message was delivered (i.e. the app process is alive).
  static bool notify(String eventType, int? scheduledAtMillis) {
    final send = IsolateNameServer.lookupPortByName(_portName);
    if (send == null) return false;
    send.send(scheduledAtMillis == null ? eventType : '$eventType|$scheduledAtMillis');
    return true;
  }
}
