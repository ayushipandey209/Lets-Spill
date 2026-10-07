import 'dart:math' as math;

/// Ranking and search helpers shared by the app, the security rules and the
/// seed script. Keep the constants in sync with `firebase/firestore.rules`
/// and `firebase/seed/seed.mjs`.
abstract final class Ranking {
  /// Seconds since this moment are used for the time part of the hot score
  /// (keeps the numbers small). 2024-01-01T00:00:00Z.
  static const epochSeconds = 1704067200;

  /// Every 45,000 seconds (12.5 hours) of age is worth one order of magnitude
  /// of engagement, like Reddit's classic "hot" ranking.
  static const decaySeconds = 45000;

  /// Engagement used for ranking: likes plus reactions.
  static int score({required int likes, required int reactions}) =>
      math.max(0, likes) + math.max(0, reactions);

  /// Time-independent "hot" score. Newer posts start higher, and every
  /// 10x more engagement is worth the same as being 12.5 hours newer.
  /// Because it doesn't change as time passes, Firestore can sort by it.
  static double hotScore({
    required DateTime createdAt,
    required int likes,
    required int reactions,
  }) {
    final s = score(likes: likes, reactions: reactions);
    final order = math.log(math.max(s, 1)) / math.ln10;
    final seconds =
        createdAt.toUtc().millisecondsSinceEpoch / 1000 - epochSeconds;
    return _round(order + seconds / decaySeconds);
  }

  static double _round(double v) => (v * 1e7).roundToDouble() / 1e7;
}

/// Lower-cased keywords stored on each confession so Firestore can match a
/// search word with `array-contains`.
abstract final class SearchTokens {
  static const maxTokens = 60;
  static const minLength = 2;

  static final _split = RegExp(r"[^a-z0-9']+");

  /// Unique words in [text] (plus the category id), longest first so the
  /// most specific words survive the [maxTokens] cap.
  static List<String> fromText(String text, {String? categoryId}) {
    final words = <String>{
      for (final raw in text.toLowerCase().split(_split))
        if (_clean(raw) case final w? when w.length >= minLength) w,
      if (categoryId != null && categoryId.isNotEmpty) categoryId.toLowerCase(),
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return words.take(maxTokens).toList(growable: false);
  }

  /// Words typed into the search box, normalised the same way.
  static List<String> fromQuery(String query) => {
    for (final raw in query.toLowerCase().split(_split))
      if (_clean(raw) case final w? when w.length >= minLength) w,
  }.toList(growable: false);

  static String? _clean(String raw) {
    final w = raw.replaceAll("'", '');
    return w.isEmpty ? null : w;
  }
}
