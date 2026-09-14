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
}
