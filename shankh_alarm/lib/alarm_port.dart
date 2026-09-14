import 'dart:isolate';
import 'dart:ui';

/// Lets the background alarm isolate wake the live app instantly (no need to
/// wait for the user to tap the notification) when the app process is still
/// alive, via a named [SendPort] registered through [IsolateNameServer].
class AlarmPort {
  AlarmPort._();

  static const _portName = 'shankh_alarm_port';

  /// Call once from the main isolate, before any alarm can fire.
  static void registerListener(void Function(String eventType) onFired) {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(port.sendPort, _portName);
    port.listen((message) {
      if (message is String) onFired(message);
    });
  }

  /// Call from the background isolate when an alarm fires. Returns true if
  /// the message was delivered (i.e. the app process is alive).
  static bool notify(String eventType) {
    final send = IsolateNameServer.lookupPortByName(_portName);
    if (send == null) return false;
    send.send(eventType);
    return true;
  }
}
