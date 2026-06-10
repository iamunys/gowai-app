import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import '../models/trip_stop.dart';

class PlacesService {
  Future<TripStop> enrichStop(TripStop stop) async {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY']!;
    try {
      final uri = Uri.parse(ApiEndpoints.placesTextSearch).replace(
        queryParameters: {
          'query': stop.name,
          'key': apiKey,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return stop;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return stop;

      final place = results.first as Map<String, dynamic>;
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
        final photoRef =
            (photos.first as Map<String, dynamic>)['photo_reference'] as String?;
        if (photoRef != null) {
          photoUrl = ApiEndpoints.placesPhotoUrl(photoRef, apiKey);
        }
      }

      return stop.copyWith(
        placeId: place['place_id'] as String?,
        latLng: latLng,
        rating: (place['rating'] as num?)?.toDouble(),
        photoUrl: photoUrl,
      );
    } catch (_) {
      return stop;
    }
  }

  Future<List<TripStop>> enrichStops(List<TripStop> stops) async {
    final futures = stops.map(enrichStop);
    return Future.wait(futures);
  }
}
