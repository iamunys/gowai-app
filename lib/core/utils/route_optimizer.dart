import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip_stop.dart';

/// Reorders [stops] so consecutive stops are geographically close, instead
/// of leaving them in whatever order the AI happened to generate them in
/// (which can zigzag across a whole district).
///
/// Uses a nearest-neighbor heuristic: the first stop with coordinates is
/// kept as the day's starting point, then each following stop is the
/// nearest not-yet-visited stop to the previous one.
///
/// The original time/duration "schedule slots", in their original order,
/// are reassigned positionally to the new order — so the day still
/// progresses from the original start time to the original end time, only
/// WHICH place is visited at each point changes, not when.
///
/// Stops without coordinates keep their relative order, appended at the
/// end. If fewer than 2 stops have coordinates, [stops] is returned
/// unchanged.
List<TripStop> optimizeStopOrder(List<TripStop> stops) {
  final withCoords = <int>[
    for (var i = 0; i < stops.length; i++)
      if (stops[i].latLng != null) i,
  ];
  if (withCoords.length < 2) return stops;

  final visited = List<bool>.filled(stops.length, false);
  final order = <int>[];

  var current = withCoords.first;
  order.add(current);
  visited[current] = true;

  while (order.length < withCoords.length) {
    int? nearest;
    var bestDist = double.infinity;
    for (final i in withCoords) {
      if (visited[i]) continue;
      final d = _distanceMeters(stops[current].latLng!, stops[i].latLng!);
      if (d < bestDist) {
        bestDist = d;
        nearest = i;
      }
    }
    order.add(nearest!);
    visited[nearest] = true;
    current = nearest;
  }

  for (var i = 0; i < stops.length; i++) {
    if (!visited[i]) order.add(i);
  }

  final schedule = [
    for (final s in stops) (time: s.time, duration: s.durationMinutes),
  ];

  return [
    for (var pos = 0; pos < order.length; pos++)
      stops[order[pos]].copyWith(
        stopNumber: pos + 1,
        time: schedule[pos].time,
        durationMinutes: schedule[pos].duration,
      ),
  ];
}

double _distanceMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _deg2rad(b.latitude - a.latitude);
  final dLng = _deg2rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(a.latitude)) *
          math.cos(_deg2rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return earthRadius * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180);
