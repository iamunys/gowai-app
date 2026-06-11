import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import '../models/trip_stop.dart';

class PlacesService {
  /// Bounded per-stop lookup: enrichStops awaits all stops in parallel, so
  /// one stalled request without a timeout would hang the whole generation
  /// flow after Claude had already succeeded.
  static const _timeout = Duration(seconds: 15);

  /// [destination] (e.g. "Wayanad") is used as a region hint for the
  /// fallback queries. Without it, a generic stop name like "Sunset Point"
  /// or a restaurant name that exists in many towns can resolve to a
  /// same-named place hundreds of km away in a different district.
  ///
  /// Tries up to three queries, most-specific first:
  /// 1. Claude's `search_query` (e.g. "Abbey Falls Coorg Karnataka India")
  /// 2. "<name>, <city or destination>"
  /// 3. "<name>" alone
  ///
  /// If none return a result, falls back to Claude's approximate
  /// coordinates (if provided) so the stop still has a map position.
  Future<TripStop> enrichStop(TripStop stop, {String? destination}) async {
    final queries = <String>{
      if (stop.searchQuery != null && stop.searchQuery!.trim().isNotEmpty)
        stop.searchQuery!,
      if ((stop.city ?? destination) != null)
        '${stop.name}, ${stop.city ?? destination}',
      stop.name,
    };

    for (final query in queries) {
      try {
        final place = await _searchPlace(query);
        if (place == null) continue;

        final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY']!;
        final geometry = place['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;

        LatLng? latLng;
        if (location != null) {
          latLng = LatLng(
            (location['lat'] as num).toDouble(),
            (location['lng'] as num).toDouble(),
          );
        }

        String? photoUrl;
        final photos = place['photos'] as List<dynamic>?;
        if (photos != null && photos.isNotEmpty) {
          final photoRef = (photos.first
              as Map<String, dynamic>)['photo_reference'] as String?;
          if (photoRef != null) {
            photoUrl = ApiEndpoints.placesPhotoUrl(photoRef, apiKey);
          }
        }

        return stop.copyWith(
          placeId: place['place_id'] as String?,
          latLng: latLng,
          rating: (place['rating'] as num?)?.toDouble(),
          photoUrl: photoUrl,
          address: place['formatted_address'] as String?,
        );
      } catch (_) {
        // Try the next, less specific query.
      }
    }

    // Places couldn't resolve any query — fall back to Claude's
    // approximate coordinates so the stop still appears on the map.
    if (stop.approximateLat != null && stop.approximateLng != null) {
      return stop.copyWith(
        latLng: LatLng(stop.approximateLat!, stop.approximateLng!),
      );
    }
    return stop;
  }

  Future<Map<String, dynamic>?> _searchPlace(String query) async {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY']!;
    final uri = Uri.parse(ApiEndpoints.placesTextSearch).replace(
      queryParameters: {
        'query': query,
        'region': 'in',
        'key': apiKey,
      },
    );
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    return results.first as Map<String, dynamic>;
  }

  Future<List<TripStop>> enrichStops(List<TripStop> stops,
      {String? destination}) async {
    final futures =
        stops.map((s) => enrichStop(s, destination: destination));
    return Future.wait(futures);
  }
}
