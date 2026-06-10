import 'dart:convert';

class JsonParser {
  static List<Map<String, dynamic>> parseItinerary(String raw) {
    final cleaned = _stripMarkdownFences(raw.trim());
    final decoded = jsonDecode(cleaned);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw FormatException('Expected JSON array, got: ${decoded.runtimeType}');
  }

  static String _stripMarkdownFences(String input) {
    var s = input;
    if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) {
        s = s.substring(firstNewline + 1);
      }
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.lastIndexOf('```')).trim();
    }
    // Find the first [ and last ] to extract just the JSON array
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      s = s.substring(start, end + 1);
    }
    return s;
  }
}
