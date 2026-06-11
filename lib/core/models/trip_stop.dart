import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripStop {
  final int stopNumber;
  final String name;
  final String time;
  final int durationMinutes;
  final String category;
  final String description;
  final String tip;
  final int entryFeeInr;
  final String bestFor;
  // Populated by PlacesService
  final String? placeId;
  final LatLng? latLng;
  final double? rating;
  final String? photoUrl;
  final String? address;
  // Provided by Claude alongside name, for more accurate Places lookups
  // and as a last-resort map position if Places enrichment fails.
  final String? searchQuery;
  final String? city;
  final String? state;
  final double? approximateLat;
  final double? approximateLng;

  const TripStop({
    required this.stopNumber,
    required this.name,
    required this.time,
    required this.durationMinutes,
    required this.category,
    required this.description,
    required this.tip,
    required this.entryFeeInr,
    required this.bestFor,
    this.placeId,
    this.latLng,
    this.rating,
    this.photoUrl,
    this.address,
    this.searchQuery,
    this.city,
    this.state,
    this.approximateLat,
    this.approximateLng,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      stopNumber: _parseInt(json['stop_number']),
      name: _parseString(json['name']),
      time: _parseString(json['time']),
      durationMinutes: _parseInt(json['duration_minutes']),
      category: _parseString(json['category']),
      description: _parseString(json['description']),
      tip: _parseString(json['tip']),
      entryFeeInr: _parseInt(json['entry_fee_inr']),
      bestFor: _parseString(json['best_for']),
      searchQuery: json['search_query'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      approximateLat: _parseDouble(json['approximate_lat']),
      approximateLng: _parseDouble(json['approximate_lng']),
    );
  }

  /// Parses ints that Claude may return as numbers or numeric strings,
  /// without throwing.
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// Parses doubles that Claude may return as numbers or numeric strings,
  /// without throwing. Returns null if absent or unparsable.
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
        'stop_number': stopNumber,
        'name': name,
        'time': time,
        'duration_minutes': durationMinutes,
        'category': category,
        'description': description,
        'tip': tip,
        'entry_fee_inr': entryFeeInr,
        'best_for': bestFor,
        'place_id': placeId,
        'lat': latLng?.latitude,
        'lng': latLng?.longitude,
        'rating': rating,
        'photo_url': photoUrl,
        'address': address,
        if (searchQuery != null) 'search_query': searchQuery,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (approximateLat != null) 'approximate_lat': approximateLat,
        if (approximateLng != null) 'approximate_lng': approximateLng,
      };

  factory TripStop.fromStoredJson(Map<String, dynamic> json) {
    LatLng? latLng;
    if (json['lat'] != null && json['lng'] != null) {
      latLng = LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      );
    }
    return TripStop(
      stopNumber: _parseInt(json['stop_number']),
      name: _parseString(json['name']),
      time: _parseString(json['time']),
      durationMinutes: _parseInt(json['duration_minutes']),
      category: _parseString(json['category']),
      description: _parseString(json['description']),
      tip: _parseString(json['tip']),
      entryFeeInr: _parseInt(json['entry_fee_inr']),
      bestFor: _parseString(json['best_for']),
      placeId: json['place_id'] as String?,
      latLng: latLng,
      rating: (json['rating'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      address: json['address'] as String?,
      searchQuery: json['search_query'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      approximateLat: _parseDouble(json['approximate_lat']),
      approximateLng: _parseDouble(json['approximate_lng']),
    );
  }

  TripStop copyWith({
    int? stopNumber,
    String? time,
    int? durationMinutes,
    String? placeId,
    LatLng? latLng,
    double? rating,
    String? photoUrl,
    String? address,
  }) {
    return TripStop(
      stopNumber: stopNumber ?? this.stopNumber,
      name: name,
      time: time ?? this.time,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category,
      description: description,
      tip: tip,
      entryFeeInr: entryFeeInr,
      bestFor: bestFor,
      placeId: placeId ?? this.placeId,
      latLng: latLng ?? this.latLng,
      rating: rating ?? this.rating,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      searchQuery: searchQuery,
      city: city,
      state: state,
      approximateLat: approximateLat,
      approximateLng: approximateLng,
    );
  }
}
