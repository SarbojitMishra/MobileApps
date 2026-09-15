import 'package:shared_preferences/shared_preferences.dart';

/// Small typed wrapper around SharedPreferences for the handful of settings
/// this app needs: which location to use, and whether the sunrise / sunset
/// alarms are switched on. Mirrors the original Android app's Prefs object.
class Prefs {
  Prefs._();

  // Bhubaneswar, Odisha, India — the documented default location.
  static const double defaultLat = 20.2961;
  static const double defaultLon = 85.8245;
  static const String defaultLocationName = 'Bhubaneswar, Odisha (default)';

  static const _keyLat = 'lat';
  static const _keyLon = 'lon';
  static const _keyLocationName = 'location_name';
  static const _keyUseDeviceLocation = 'use_device_location';
  static const _keySunriseEnabled = 'sunrise_enabled';
  static const _keySunsetEnabled = 'sunset_enabled';

  // Snooze cap (ALM-FR-010): at most 3 snoozes per event *instance*, reset
  // the next time that event's base (non-snooze) alarm fires.
  static const maxSnoozeCount = 3;
  static const _keySnoozeCountPrefix = 'snooze_count_';
  static const _keySchedulingWarningPrefix = 'scheduling_warning_';

  static Future<double> getLatitude() async =>
      (await SharedPreferences.getInstance()).getDouble(_keyLat) ?? defaultLat;

  static Future<double> getLongitude() async =>
      (await SharedPreferences.getInstance()).getDouble(_keyLon) ?? defaultLon;

  static Future<String> getLocationName() async =>
      (await SharedPreferences.getInstance()).getString(_keyLocationName) ?? defaultLocationName;

  static Future<void> setLocation(double lat, double lon, String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_keyLat, lat);
    await p.setDouble(_keyLon, lon);
    await p.setString(_keyLocationName, name);
  }

  static Future<void> resetToDefaultLocation() =>
      setLocation(defaultLat, defaultLon, defaultLocationName);

  static Future<bool> getUseDeviceLocation() async =>
      (await SharedPreferences.getInstance()).getBool(_keyUseDeviceLocation) ?? true;

  static Future<void> setUseDeviceLocation(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_keyUseDeviceLocation, value);

  static Future<bool> isSunriseEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_keySunriseEnabled) ?? true;

  static Future<void> setSunriseEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_keySunriseEnabled, value);

  static Future<bool> isSunsetEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_keySunsetEnabled) ?? true;

  static Future<void> setSunsetEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_keySunsetEnabled, value);

  static Future<int> getSnoozeCount(String eventType) async =>
      (await SharedPreferences.getInstance()).getInt('$_keySnoozeCountPrefix$eventType') ?? 0;

  static Future<void> setSnoozeCount(String eventType, int value) async =>
      (await SharedPreferences.getInstance()).setInt('$_keySnoozeCountPrefix$eventType', value);

  static Future<void> resetSnoozeCount(String eventType) => setSnoozeCount(eventType, 0);

  /// Set when [AndroidAlarmManager] refuses to (re)schedule an event (e.g. a
  /// `SecurityException` from a revoked exact-alarm permission), surfaced on
  /// the Home screen rather than failing silently (Design Principle 3).
  static Future<void> setSchedulingWarning(String eventType, String? message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keySchedulingWarningPrefix$eventType';
    if (message == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, message);
    }
  }

  static Future<String?> getSchedulingWarning(String eventType) async =>
      (await SharedPreferences.getInstance()).getString('$_keySchedulingWarningPrefix$eventType');
}
