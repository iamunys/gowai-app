import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/trip.dart';
import '../../core/services/service_providers.dart';

/// The signed-in user's saved trips.
///
/// AsyncNotifier gives the screen real loading / error / data states —
/// previously a network failure left the list empty and the UI showed the
/// "No trips yet" empty state, which was a lie.
///
/// autoDispose: refetches when the user re-enters the History tab, matching
/// the old initState-fetch behavior.
class TripsNotifier extends AutoDisposeAsyncNotifier<List<Trip>> {
  @override
  Future<List<Trip>> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    // Router guards keep unauthenticated users out of /history; this is
    // belt-and-suspenders so a race can't hang the screen in loading.
    if (user == null) return const [];
    return ref.read(supabaseServiceProvider).getUserTrips(user.id);
  }

  /// Deletes on the server first, then removes the trip from the loaded
  /// list — no full refetch needed. Errors propagate to the caller so the
  /// screen can show a snackbar while the list stays intact.
  Future<void> deleteTrip(Trip trip) async {
    final id = trip.id;
    if (id == null) return;
    await ref.read(supabaseServiceProvider).deleteTrip(id);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((t) => t.id != id).toList());
    }
  }
}

final tripsProvider =
    AsyncNotifierProvider.autoDispose<TripsNotifier, List<Trip>>(
        TripsNotifier.new);
