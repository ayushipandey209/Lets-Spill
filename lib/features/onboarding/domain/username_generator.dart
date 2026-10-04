import 'dart:math';

/// Generates anonymous handles like "QuietComet27".
///
/// Users can't type a username — they pick from these suggestions — so no
/// real names, emails or phone numbers can end up as a public handle.
class UsernameGenerator {
  UsernameGenerator([Random? random]) : _random = random ?? Random();

  final Random _random;

  static const adjectives = [
    'Quiet', 'Velvet', 'Midnight', 'Hidden', 'Paper', 'Amber', 'Silent',
    'Golden', 'Hollow', 'Gentle', 'Secret', 'Wild', 'Misty', 'Lunar', 'Ivory',
    'Rusty', 'Calm', 'Sleepy', 'Brave', 'Shy', 'Faded', 'Inky', 'Wandering',
    'Distant', 'Silver', 'Honey', 'Cosmic', 'Soft', 'Restless', 'Dusky',
  ];

  static const nouns = [
    'Comet', 'Moth', 'Sparrow', 'Willow', 'Echo', 'Lantern', 'Fox', 'Raven',
    'Harbor', 'Meadow', 'Ember', 'Pebble', 'River', 'Owl', 'Fern', 'Cloud',
    'Quill', 'Tide', 'Maple', 'Wren', 'Orchid', 'Ripple', 'Cedar', 'Pine',
    'Robin', 'Ghost', 'Lark', 'Petal', 'Atlas', 'Story',
  ];

  /// Allowed shape, mirrored in Firestore rules.
  static final pattern = RegExp(r'^[A-Za-z]{6,24}[0-9]{2}$');

  String next() {
    final a = adjectives[_random.nextInt(adjectives.length)];
    final n = nouns[_random.nextInt(nouns.length)];
    final digits = (10 + _random.nextInt(90)).toString();
    return '$a$n$digits';
  }

  /// [count] distinct suggestions, excluding any in [exclude].
  List<String> suggestions(int count, {Set<String> exclude = const {}}) {
    final result = <String>{};
    var guard = 0;
    while (result.length < count && guard < count * 50) {
      guard++;
      final name = next();
      if (!exclude.contains(name)) result.add(name);
    }
    return result.toList(growable: false);
  }
}
