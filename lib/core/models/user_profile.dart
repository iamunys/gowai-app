class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final int tripsUsedThisMonth;
  final DateTime? lastResetDate;
  final bool isPro;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.tripsUsedThisMonth = 0,
    this.lastResetDate,
    this.isPro = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      tripsUsedThisMonth: json['trips_used_this_month'] as int? ?? 0,
      lastResetDate: json['last_reset_date'] != null
          ? DateTime.tryParse(json['last_reset_date'] as String)
          : null,
      isPro: json['is_pro'] as bool? ?? false,
    );
  }
}
