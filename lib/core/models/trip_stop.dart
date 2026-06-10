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
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      stopNumber: json['stop_number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
      entryFeeInr: (json['entry_fee_inr'] as num?)?.toInt() ?? 0,
      bestFor: json['best_for'] as String? ?? '',
    );
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
      stopNumber: json['stop_number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
      entryFeeInr: (json['entry_fee_inr'] as num?)?.toInt() ?? 0,
      bestFor: json['best_for'] as String? ?? '',
      placeId: json['place_id'] as String?,
      latLng: latLng,
      rating: (json['rating'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
    );
  }

  TripStop copyWith({
    String? placeId,
    LatLng? latLng,
    double? rating,
    String? photoUrl,
  }) {
    return TripStop(
      stopNumber: stopNumber,
      name: name,
      time: time,
      durationMinutes: durationMinutes,
      category: category,
      description: description,
      tip: tip,
      entryFeeInr: entryFeeInr,
      bestFor: bestFor,
      placeId: placeId ?? this.placeId,
      latLng: latLng ?? this.latLng,
      rating: rating ?? this.rating,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
