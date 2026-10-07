/// Pure validation helpers. Each returns `null` when valid, or a short,
/// user-facing message otherwise.
abstract final class Validators {
  static String? categories(Iterable<String> selected) {
    if (selected.isEmpty) return 'Pick at least one category.';
    return null;
  }

  /// Validates confession text against the configured length bounds.
  static String? confession(
    String? value, {
    required int min,
    required int max,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Write something before posting.';
    if (v.length < min) return 'Add a little more: at least $min characters.';
    if (v.length > max) return 'Keep it under $max characters.';
    return null;
  }
}
