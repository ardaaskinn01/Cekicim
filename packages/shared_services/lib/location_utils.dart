import 'dart:math';

class LocationUtils {
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    var earthRadius = 6371.0; // In kilometers
    var dLat = _toRadians(endLatitude - startLatitude);
    var dLon = _toRadians(endLongitude - startLongitude);

    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(startLatitude)) *
            cos(_toRadians(endLatitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
