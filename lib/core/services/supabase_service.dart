import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ─── Auth ───────────────────────────────────────────────────────────────────

  Future<AuthResponse> signUpWithEmail(
      String email, String password, String fullName) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async => _client.auth.signOut();

  Future<void> resetPassword(String email) async =>
      _client.auth.resetPasswordForEmail(email);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── Profile ─────────────────────────────────────────────────────────────────

  Future<UserProfile?> getProfile(String userId) async {
    final data =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<bool> canGenerateTrip(String userId) async {
    final profile = await getProfile(userId);
    if (profile == null) return false;
    if (profile.isPro) return true;

    final now = DateTime.now();
    final lastReset = profile.lastResetDate;
    if (lastReset == null ||
        now.month != lastReset.month ||
        now.year != lastReset.year) {
      await _client.from('profiles').update({
        'trips_used_this_month': 0,
        'last_reset_date': now.toIso8601String().split('T').first,
      }).eq('id', userId);
      return true;
    }

    return profile.tripsUsedThisMonth < 3;
  }

  Future<void> incrementTripCount(String userId) async {
    await _client.rpc('increment_trips_used', params: {'user_id': userId});
    // Fallback: direct update
    final profile = await getProfile(userId);
    if (profile != null) {
      await _client.from('profiles').update({
        'trips_used_this_month': profile.tripsUsedThisMonth + 1,
      }).eq('id', userId);
    }
  }

  Future<void> setProStatus(String userId, bool isPro) async {
    await _client.from('profiles').update({'is_pro': isPro}).eq('id', userId);
  }

  // ─── Trips ───────────────────────────────────────────────────────────────────

  Future<Trip> saveTrip(Trip trip, String userId) async {
    final data = trip.toJson();
    data['user_id'] = userId;
    final response = await _client.from('trips').insert(data).select().single();
    return Trip.fromJson(response);
  }

  Future<List<Trip>> getUserTrips(String userId) async {
    final data = await _client
        .from('trips')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Trip.fromJson(e)).toList();
  }

  Future<Trip?> getTripByShareToken(String token) async {
    final data = await _client
        .from('trips')
        .select()
        .eq('share_token', token)
        .eq('is_public', true)
        .maybeSingle();
    if (data == null) return null;
    return Trip.fromJson(data);
  }

  Future<Trip> makePublic(String tripId, String shareToken) async {
    final data = await _client
        .from('trips')
        .update({'is_public': true, 'share_token': shareToken})
        .eq('id', tripId)
        .select()
        .single();
    return Trip.fromJson(data);
  }

  Future<void> deleteTrip(String tripId) async {
    await _client.from('trips').delete().eq('id', tripId);
  }
}
