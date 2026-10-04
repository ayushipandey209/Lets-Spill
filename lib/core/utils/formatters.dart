/// Display formatting without pulling in `intl` for an MVP.
abstract final class Formatters {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "just now", "5m ago", "3h ago", "2d ago", then "12 Mar" / "12 Mar 2024".
  static String relativeDate(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final local = date.toLocal();
    final diff = current.difference(local);
    if (diff.isNegative || diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return fullDate(local, now: current);
  }

  /// "12 Mar" in the current year, otherwise "12 Mar 2024".
  static String fullDate(DateTime date, {DateTime? now}) {
    final local = date.toLocal();
    final current = now ?? DateTime.now();
    final base = '${local.day} ${_months[local.month - 1]}';
    return local.year == current.year ? base : '$base ${local.year}';
  }

  /// 950 → "950", 1200 → "1.2K", 15300 → "15K", 2400000 → "2.4M".
  static String compactCount(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) return _compact(value / 1000, 'K');
    return _compact(value / 1000000, 'M');
  }

  static String _compact(double v, String suffix) {
    final text = v >= 10 ? v.floor().toString() : _oneDecimal(v);
    return '$text$suffix';
  }

  static String _oneDecimal(double v) {
    final floored = (v * 10).floor() / 10;
    final s = floored.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// "1,234".
  static String thousands(int value) {
    final s = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
