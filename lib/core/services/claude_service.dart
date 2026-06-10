import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import '../models/trip_stop.dart';
import '../utils/json_parser.dart';

class ClaudeService {
  static const _systemPrompt = '''
You are Gowai, an expert travel planner AI specializing in Indian destinations.

Based on the user's preferences, generate a detailed full-day trip itinerary.

You MUST respond ONLY with a valid JSON array. No explanation, no markdown, no preamble.
Just the raw JSON array starting with [ and ending with ].

Each item in the array must have exactly these fields:
{
  "stop_number": 1,
  "name": "Place name as it appears on Google Maps",
  "time": "6:30 AM",
  "duration_minutes": 45,
  "category": "viewpoint" | "waterfall" | "trekking" | "food" | "culture" | "estate" | "beach" | "market" | "temple",
  "description": "2-3 sentence description of the place and why to visit",
  "tip": "One practical insider tip for the visitor",
  "entry_fee_inr": 20,
  "best_for": "what kind of traveler this stop is best for"
}

Rules:
- Generate exactly 5-7 stops for a full day
- Time the stops realistically from morning to evening
- Keep total estimated spend within the user\'s stated budget
- Use real place names that exist on Google Maps
- Tailor stops to the user\'s vibe (nature, culture, food, etc.) and group type
- For solo travelers, prefer safe and accessible locations
''';

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
    final apiKey = dotenv.env['ANTHROPIC_API_KEY']!;
    final userMessage = '''
Destination: $destination
Travel date: $date
Start time preference: $startTime
Budget for the day: $budget
Travel vibe: $vibe
Group type: $groupType
Interests: $interests
Transport mode: $transport
''';

    final body = jsonEncode({
      'model': ApiEndpoints.claudeModel,
      'max_tokens': 2000,
      'system': _systemPrompt,
      'messages': [
        {'role': 'user', 'content': userMessage}
      ],
    });

    final response = await _callClaude(apiKey, body);
    return _parseResponse(response);
  }

  Future<http.Response> _callClaude(String apiKey, String body) async {
    return http.post(
      Uri.parse(ApiEndpoints.claudeMessages),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': ApiEndpoints.anthropicVersion,
        'content-type': 'application/json',
      },
      body: body,
    );
  }

  List<TripStop> _parseResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(
          'Claude API error ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>;
    final text = (content.first as Map<String, dynamic>)['text'] as String;
    final stops = JsonParser.parseItinerary(text);
    return stops.map(TripStop.fromJson).toList();
  }
}
