import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'claude_service.dart';
import 'places_service.dart';
import 'supabase_service.dart';

/// App-wide service providers.
///
/// Widgets and notifiers should obtain services through these instead of
/// instantiating them inline (`SupabaseService()` was previously constructed
/// fresh in 7+ widgets). One place to construct, one place to mock in tests.
final supabaseServiceProvider =
    Provider<SupabaseService>((ref) => SupabaseService());

final claudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());

final placesServiceProvider = Provider<PlacesService>((ref) => PlacesService());
