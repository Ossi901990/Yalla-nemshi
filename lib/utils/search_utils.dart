// lib/utils/search_utils.dart
// Utility helpers for building normalized keyword lists used by the advanced search filters.
class SearchUtils {
  static const List<String> defaultKeywordSeeds = [
    'sunrise walk',
    'sunset stroll',
    'trail run',
    'city loop',
    'coffee walk',
    'mindful pace',
    'women only',
    'family friendly',
    'dog friendly',
    'scenic views',
    'hiking',
    'weekend long walk',
  ];

  /// Builds a normalized set of keywords derived from multiple walk attributes.
  /// The output is de-duplicated, lowercase, and includes short prefixes so
  /// Firestore prefix queries and local autocomplete both behave reliably.
  static List<String> buildKeywords({
    required String title,
    String? description,
    String? city,
    Iterable<String>? tags,
    String? comfortLevel,
    String? experienceLevel,
    String? pace,
  }) {
    final tokens = <String>{};

    void addText(String? raw) {
      if (raw == null) return;
      final normalized = raw
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((chunk) => chunk.trim().isNotEmpty)
          .map((chunk) => chunk.trim());
      tokens.addAll(normalized);
    }

    addText(title);
    addText(description);
    addText(city);

    if (tags != null) {
      for (final tag in tags) {
        addText(tag);
      }
    }

    addText(comfortLevel);
    addText(experienceLevel);
    addText(pace);

    // Create short prefixes for lightweight autocomplete matching.
    final prefixes = <String>{};
    for (final token in tokens) {
      if (token.length < 3) continue;
      for (int i = 3; i <= token.length && i <= 10; i++) {
        prefixes.add(token.substring(0, i));
      }
    }

    return <String>{...tokens, ...prefixes}.toList(growable: false);
  }

  /// Tokenize free-form search text so we can plug the pieces into
  /// arrayContainsAny queries (Firestore max 10 entries).
  static List<String> tokenizeQuery(String raw, {int minLength = 3}) {
    if (raw.trim().isEmpty) return const [];
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((chunk) => chunk.trim().length >= minLength)
        .map((chunk) => chunk.trim())
        .toList(growable: false);
  }
}
