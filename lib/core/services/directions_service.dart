import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';

class DirectionsService {
  /// The route is decorative (the itinerary works without it), so fail fast
  /// rather than keep the "Drawing your route" pill up indefinitely.
  static const _timeout = Duration(seconds: 15);

  /// Never throws — on any error (timeout, HTTP failure, malformed
  /// response, ZERO_RESULTS…) falls back to straight lines connecting the
  /// given [coordinates], so the map always shows a route.
  Future<List<LatLng>> getRoutePoints(List<LatLng> coordinates) async {
    if (coordinates.length < 2) return coordinates;

    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;
      final origin = coordinates.first;
      final destination = coordinates.last;
      final waypoints = coordinates.length > 2
          ? coordinates
              .sublist(1, coordinates.length - 1)
              .map((c) => '${c.latitude},${c.longitude}')
              .join('|')
          : null;

      final params = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': apiKey,
      };
      if (waypoints != null) params['waypoints'] = waypoints;

      final uri = Uri.parse(ApiEndpoints.directions)
          .replace(queryParameters: params);
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[Directions] HTTP ${response.statusCode} — '
              'falling back to straight lines between stops');
        }
        return coordinates;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // The API reports failures (REQUEST_DENIED, OVER_QUERY_LIMIT,
      // ZERO_RESULTS…) inside a 200 response. Without this check those
      // errors silently degrade the route to straight stop-to-stop lines.
      final status = data['status'] as String?;
      if (status != 'OK' && kDebugMode) {
        debugPrint('[Directions] status=$status '
            '${data['error_message'] ?? ''} — '
            'falling back to straight lines between stops');
      }
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return coordinates;

      final overviewPolyline = (routes.first as Map<String, dynamic>)
          ['overview_polyline'] as Map<String, dynamic>?;
      final points = overviewPolyline?['points'] as String?;
      if (points == null) return coordinates;

      return _decodePolyline(points);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Directions] $e — '
            'falling back to straight lines between stops');
      }
      return coordinates;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result0 = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result0 & 1) != 0 ? ~(result0 >> 1) : result0 >> 1;
      lat += dLat;

      shift = 0;
      result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result0 & 1) != 0 ? ~(result0 >> 1) : result0 >> 1;
      lng += dLng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }
}
