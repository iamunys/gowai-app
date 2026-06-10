import 'trip_stop.dart';

class Trip {
  final String? id;
  final String? userId;
  final String destination;
  final DateTime? tripDate;
  final String vibe;
  final String budget;
  final String groupType;
  final List<TripStop> stops;
  final bool isPublic;
  final String? shareToken;
  final DateTime? createdAt;

  const Trip({
    this.id,
    this.userId,
    required this.destination,
    this.tripDate,
    required this.vibe,
    required this.budget,
    required this.groupType,
    required this.stops,
    this.isPublic = false,
    this.shareToken,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'trip_date': tripDate?.toIso8601String().split('T').first,
        'vibe': vibe,
        'budget': budget,
        'group_type': groupType,
        'itinerary_json': stops.map((s) => s.toJson()).toList(),
        'is_public': isPublic,
        'share_token': shareToken,
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    final stopsRaw = json['itinerary_json'] as List<dynamic>? ?? [];
    return Trip(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      destination: json['destination'] as String? ?? '',
      tripDate: json['trip_date'] != null
          ? DateTime.tryParse(json['trip_date'] as String)
          : null,
      vibe: json['vibe'] as String? ?? '',
      budget: json['budget'] as String? ?? '',
      groupType: json['group_type'] as String? ?? '',
      stops: stopsRaw
          .map((s) => TripStop.fromStoredJson(s as Map<String, dynamic>))
          .toList(),
      isPublic: json['is_public'] as bool? ?? false,
      shareToken: json['share_token'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Trip copyWith({
    String? id,
    bool? isPublic,
    String? shareToken,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId,
      destination: destination,
      tripDate: tripDate,
      vibe: vibe,
      budget: budget,
      groupType: groupType,
      stops: stops,
      isPublic: isPublic ?? this.isPublic,
      shareToken: shareToken ?? this.shareToken,
      createdAt: createdAt,
    );
  }
}
