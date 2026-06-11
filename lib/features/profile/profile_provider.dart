import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/service_providers.dart';

/// The signed-in user's profile row (null when no row exists yet).
///
/// autoDispose: refetches when the user re-enters the Profile tab — so the
/// trips-used counter is fresh after a generation, same as the old
/// initState fetch.
class ProfileNotifier extends AutoDisposeAsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() => _fetch();

  Future<UserProfile?> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return ref.read(supabaseServiceProvider).getProfile(user.id);
  }

  /// Persists the new name, then quietly refreshes the profile (keeps
  /// showing current data instead of flashing the full-screen loader).
  /// Errors propagate to the caller for the snackbar.
  Future<void> updateName(String name) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await ref.read(supabaseServiceProvider).updateName(user.id, name);
    state = AsyncData(await _fetch());
  }
}

final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileNotifier, UserProfile?>(
        ProfileNotifier.new);
