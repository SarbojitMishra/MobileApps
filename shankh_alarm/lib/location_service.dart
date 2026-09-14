import 'package:geolocator/geolocator.dart';

import 'prefs.dart';

/// Resolves "the local sunrise/sunset location". If location permission
/// isn't granted, GPS is off, or no fix can be obtained, callers fall back
/// to [Prefs.defaultLat] / [Prefs.defaultLon] — Bhubaneswar, Odisha.
class LocationService {
  LocationService._();

  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  static Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Figures out which lat/lon to use right now, per the app's spec: device
  /// location when available and permitted, otherwise Bhubaneswar. Persists
  /// whatever it resolves to as the active location.
  static Future<(double lat, double lon)> resolveActiveLocation({bool useFreshGps = false}) async {
    final useDevice = await Prefs.getUseDeviceLocation();
    if (useDevice && await hasPermission()) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          Position? position;
          if (useFreshGps) {
            try {
              position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 8),
                ),
              );
            } catch (_) {
              position = await Geolocator.getLastKnownPosition();
            }
          } else {
            position = await Geolocator.getLastKnownPosition();
          }
          if (position != null) {
            final name =
                'Current location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
            await Prefs.setLocation(position.latitude, position.longitude, name);
            return (position.latitude, position.longitude);
          }
        }
      } catch (_) {
        // Fall through to the stored/default location below.
      }
    }
    // No permission, GPS disabled, or no fix yet: fall back to the location
    // already stored in Prefs, which itself defaults to Bhubaneswar, Odisha.
    return (await Prefs.getLatitude(), await Prefs.getLongitude());
  }
}
