class ApiEndpoints {
  static const placesTextSearch =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';
  static const placesPhoto = 'https://maps.googleapis.com/maps/api/place/photo';
  static const directions =
      'https://maps.googleapis.com/maps/api/directions/json';

  static String placesPhotoUrl(String photoRef, String apiKey) =>
      '$placesPhoto?maxwidth=800&photo_reference=$photoRef&key=$apiKey';

  static const shareBaseUrl = 'https://Gowai.app/trip';
}
