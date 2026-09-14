import 'dart:math';

/// Fully offline sunrise / sunset calculator.
///
/// Implements the NOAA "General Solar Position Calculations" formulas (the
/// same math behind NOAA's published sunrise/sunset spreadsheet and most
/// sunrise-sunset libraries). No network call, no external API — everything
/// is derived from latitude, longitude and the calendar date.
///
/// Accuracy is typically within about a minute of the true sunrise/sunset
/// for non-polar latitudes.
class SunTimes {
  final DateTime? sunriseUtc;
  final DateTime? sunsetUtc;
  const SunTimes({this.sunriseUtc, this.sunsetUtc});
}

class SunCalculator {
  /// Standard solar elevation angle (degrees) used for the official
  /// sunrise/sunset moment: -50 arc-minutes to account for atmospheric
  /// refraction plus the sun's apparent radius.
  static const double _zenithDegrees = 90.833;

  /// [date] is treated as a local calendar date (only year/month/day used).
  /// [latitude] degrees, north positive. [longitude] degrees, east positive.
  static SunTimes calculate(DateTime date, double latitude, double longitude) {
    final localMidnight = DateTime(date.year, date.month, date.day);
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = localMidnight.difference(startOfYear).inDays + 1;
    final isLeap = (date.year % 4 == 0 && date.year % 100 != 0) || date.year % 400 == 0;
    final daysInYear = isLeap ? 366.0 : 365.0;

    // Fractional year gamma (radians), evaluated at local noon (hour = 12)
    // as in NOAA's simplified single-pass formula.
    final gamma = 2.0 * pi / daysInYear * (dayOfYear - 1 + (12.0 - 12.0) / 24.0);

    // Equation of time, in minutes.
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * cos(gamma) -
            0.032077 * sin(gamma) -
            0.014615 * cos(2 * gamma) -
            0.040849 * sin(2 * gamma));

    // Solar declination, in radians.
    final decl = 0.006918 -
        0.399912 * cos(gamma) +
        0.070257 * sin(gamma) -
        0.006758 * cos(2 * gamma) +
        0.000907 * sin(2 * gamma) -
        0.002697 * cos(3 * gamma) +
        0.00148 * sin(3 * gamma);

    final latRad = latitude * pi / 180.0;
    final zenithRad = _zenithDegrees * pi / 180.0;

    final cosHourAngle = (cos(zenithRad) / (cos(latRad) * cos(decl))) - (tan(latRad) * tan(decl));

    // Outside [-1, 1] means the sun never rises or never sets that day
    // (polar night / midnight sun).
    if (cosHourAngle > 1.0 || cosHourAngle < -1.0) {
      return const SunTimes(sunriseUtc: null, sunsetUtc: null);
    }

    final haRad = acos(cosHourAngle);
    final haDegrees = haRad * 180.0 / pi;

    // True solar noon, in minutes from 00:00 UTC on this date.
    final solarNoonUtcMinutes = 720.0 - 4.0 * longitude - eqTime;

    final sunriseUtcMinutes = solarNoonUtcMinutes - 4.0 * haDegrees;
    final sunsetUtcMinutes = solarNoonUtcMinutes + 4.0 * haDegrees;

    final startOfDayUtc = DateTime.utc(date.year, date.month, date.day);

    return SunTimes(
      sunriseUtc: startOfDayUtc.add(Duration(seconds: (sunriseUtcMinutes * 60).round())),
      sunsetUtc: startOfDayUtc.add(Duration(seconds: (sunsetUtcMinutes * 60).round())),
    );
  }

  /// Finds the next sunrise or sunset instant (in the device's local time
  /// zone, as a UTC-based [DateTime] that compares correctly with
  /// [DateTime.now]) strictly after [after], for event [type]. Searches
  /// forward day by day (bounded) since the NOAA formula is a per-day
  /// calculation.
  static DateTime? nextOccurrence({
    required DateTime after,
    required double latitude,
    required double longitude,
    required bool sunrise,
  }) {
    for (var offset = 0; offset <= 400; offset++) {
      final date = after.add(Duration(days: offset));
      final times = calculate(date, latitude, longitude);
      final candidate = sunrise ? times.sunriseUtc : times.sunsetUtc;
      if (candidate != null && candidate.isAfter(after)) {
        return candidate;
      }
    }
    return null;
  }
}
