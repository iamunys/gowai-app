class ApiEndpoints {
  static const claudeMessages = 'https://api.anthropic.com/v1/messages';
  // Used by the legacy direct-call fallback only; the deployed Edge Function
  // reads its model from the CLAUDE_MODEL Supabase secret instead.
  static const claudeModel = 'claude-haiku-4-5-20251001';

  static const anthropicVersion = '2023-06-01';

  static const placesTextSearch =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';
  static const placesPhoto = 'https://maps.googleapis.com/maps/api/place/photo';
  static const directions =
      'https://maps.googleapis.com/maps/api/directions/json';

  static String placesPhotoUrl(String photoRef, String apiKey) =>
      '$placesPhoto?maxwidth=800&photo_reference=$photoRef&key=$apiKey';

  static const shareBaseUrl = 'https://Gowai.app/trip';
}
