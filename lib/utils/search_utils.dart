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

  /// Common typo corrections for better search tolerance
  static const Map<String, String> _typoCorrections = {
    // Common misspellings
    'wlak': 'walk',
    'waalk': 'walk',
    'walkin': 'walking',
    'runing': 'running',
    'hikking': 'hiking',
    'traill': 'trail',
    'mountian': 'mountain',
    'beatch': 'beach',
    'coffe': 'coffee',
    'freinds': 'friends',
    'familly': 'family',
    'senset': 'sunset',
    'sunrize': 'sunrise',
    'scenik': 'scenic',
    'eazy': 'easy',
    'beginer': 'beginner',
    'intermediat': 'intermediate',
    'relaxed': 'relaxing',
  };

  /// Phonetic/similar words mapping for better matching
  static const Map<String, List<String>> _similarWords = {
    'walk': ['stroll', 'hike', 'trek'],
    'run': ['jog', 'sprint'],
    'easy': ['beginner', 'relaxed', 'casual', 'gentle'],
    'hard': ['challenging', 'difficult', 'advanced'],
    'fast': ['quick', 'brisk', 'rapid'],
    'slow': ['leisurely', 'relaxed', 'casual'],
    'morning': ['sunrise', 'dawn', 'early'],
    'evening': ['sunset', 'dusk', 'late'],
    'city': ['urban', 'downtown', 'street'],
    'nature': ['trail', 'park', 'outdoor', 'scenic'],
  };

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

    // Add typo-corrected versions of tokens
    final correctedTokens = <String>{};
    for (final token in tokens) {
      if (_typoCorrections.containsKey(token)) {
        correctedTokens.add(_typoCorrections[token]!);
      }
    }

    // Add similar/phonetic words for better matching
    final similarTokens = <String>{};
    for (final token in tokens) {
      if (_similarWords.containsKey(token)) {
        similarTokens.addAll(_similarWords[token]!);
      }
    }

    return <String>{
      ...tokens,
      ...prefixes,
      ...correctedTokens,
      ...similarTokens,
    }.toList(growable: false);
  }

  /// Tokenize free-form search text so we can plug the pieces into
  /// arrayContainsAny queries (Firestore max 10 entries).
  /// Now includes fuzzy matching support with typo correction.
  static List<String> tokenizeQuery(String raw, {int minLength = 3}) {
    if (raw.trim().isEmpty) return const [];

    final basicTokens = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((chunk) => chunk.trim().length >= minLength)
        .map((chunk) => chunk.trim())
        .toList();

    // Apply typo corrections and add similar words
    final expandedTokens = <String>{};
    for (final token in basicTokens) {
      expandedTokens.add(token);

      // Add typo-corrected version
      if (_typoCorrections.containsKey(token)) {
        expandedTokens.add(_typoCorrections[token]!);
      }

      // Add similar words (helps with synonyms)
      if (_similarWords.containsKey(token)) {
        expandedTokens.addAll(_similarWords[token]!);
      }
    }

    // Limit to 10 tokens (Firestore arrayContainsAny limit)
    // Prioritize: original tokens first, then corrections, then similar words
    final result = <String>[];
    result.addAll(basicTokens);
    result.addAll(expandedTokens.where((t) => !basicTokens.contains(t)));

    return result.take(10).toList(growable: false);
  }

  /// Calculate Levenshtein distance between two strings (for fuzzy matching)
  /// Returns the minimum number of edits needed to transform one string into another
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    // Create distance matrix
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    // Initialize first row and column
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // Calculate distances
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Check if two strings are fuzzy matches (within edit distance threshold)
  static bool isFuzzyMatch(String query, String target, {int maxDistance = 2}) {
    if (query == target) return true;
    if (query.isEmpty || target.isEmpty) return false;

    // Quick check: length difference too large
    if ((query.length - target.length).abs() > maxDistance) return false;

    return levenshteinDistance(query.toLowerCase(), target.toLowerCase()) <=
        maxDistance;
  }
}
