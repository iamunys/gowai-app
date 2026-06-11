import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_stop.dart';
import '../utils/json_parser.dart';
import 'revenuecat_service.dart';

class ClaudeService {
  /// Generation of a 5-7 stop itinerary typically takes 5-15s; only abort
  /// when the request is clearly stuck. Without this, a dropped connection
  /// left the generating animation spinning forever.
  static const _timeout = Duration(seconds: 60);

  /// Server-side proxy (Supabase Edge Function). The Anthropic key lives in
  /// Supabase secrets, not the app bundle. See supabase/README.md.
  static const _edgeFunction = 'generate-itinerary';

  Future<List<TripStop>> generateItinerary({
    required String destination,
    required String date,
    required String startTime,
    required String budget,
    required String vibe,
    required String groupType,
    required String interests,
    required String transport,
  }) async {
    // The edge function re-verifies pro status server-side against the
    // profiles table before picking a model — this is just a hint so it
    // doesn't need a separate round trip in the common case.
    final isPro = await RevenueCatService().isPro();

    final response = await Supabase.instance.client.functions
        .invoke(_edgeFunction, body: {
          'destination': destination,
          'date': date,
          'startTime': startTime,
          'budget': budget,
          'vibe': vibe,
          'groupType': groupType,
          'interests': interests,
          'transport': transport,
          'is_pro': isPro,
        })
        .timeout(_timeout);

    final text =
        (response.data as Map<String, dynamic>)['itinerary'] as String?;
    if (text == null) {
      throw Exception('Proxy returned no itinerary');
    }
    return _parseStops(text);
  }

  List<TripStop> _parseStops(String text) {
    final stops = JsonParser.parseItinerary(text);
    return stops.map(TripStop.fromJson).toList();
  }
}
