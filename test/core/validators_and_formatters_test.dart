import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:let_s_spill/core/config/app_config.dart';
import 'package:let_s_spill/core/utils/formatters.dart';
import 'package:let_s_spill/core/utils/validators.dart';
import 'package:let_s_spill/features/onboarding/domain/username_generator.dart';
import 'package:let_s_spill/features/profile/domain/user_profile.dart';

void main() {
  group('Validators', () {
    test('categories require at least one', () {
      expect(Validators.categories(const []), isNotNull);
      expect(Validators.categories(const ['life']), isNull);
    });

    test('confession length bounds use trimmed text', () {
      String? v(String s) => Validators.confession(s, min: 10, max: 20);
      expect(v('   '), isNotNull);
      expect(v('too short'), isNotNull);
      expect(v('   just right ok   '), isNull);
      expect(v('x' * 21), isNotNull);
    });
  });

  group('Formatters', () {
    final now = DateTime(2026, 10, 4, 12);

    test('relative dates', () {
      expect(Formatters.relativeDate(now, now: now), 'just now');
      expect(
        Formatters.relativeDate(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        Formatters.relativeDate(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        Formatters.relativeDate(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
      expect(Formatters.relativeDate(DateTime(2026, 3, 12), now: now), '12 Mar');
      expect(
        Formatters.relativeDate(DateTime(2024, 3, 12), now: now),
        '12 Mar 2024',
      );
    });

    test('compact counts', () {
      expect(Formatters.compactCount(950), '950');
      expect(Formatters.compactCount(1000), '1K');
      expect(Formatters.compactCount(1250), '1.2K');
      expect(Formatters.compactCount(15300), '15K');
      expect(Formatters.compactCount(2400000), '2.4M');
    });

    test('thousands separators', () {
      expect(Formatters.thousands(0), '0');
      expect(Formatters.thousands(999), '999');
      expect(Formatters.thousands(2000), '2,000');
      expect(Formatters.thousands(1234567), '1,234,567');
    });
  });

  group('AppConfig', () {
    test('defaults: 15 s view threshold, 2,000 chars, bounded pages', () {
      const config = AppConfig();
      expect(config.viewThreshold, const Duration(seconds: 15));
      expect(config.maxConfessionLength, 2000);
      expect(config.feedPageSize, lessThanOrEqualTo(30));
    });
  });

  group('UsernameGenerator', () {
    test('generates distinct, anonymous handles matching the rules pattern', () {
      final gen = UsernameGenerator(Random(7));
      final names = gen.suggestions(20);
      expect(names.toSet(), hasLength(20));
      for (final n in names) {
        expect(UsernameGenerator.pattern.hasMatch(n), isTrue, reason: n);
        expect(n.contains(' '), isFalse);
      }
      final more = gen.suggestions(6, exclude: names.toSet());
      expect(more.where(names.contains), isEmpty);
    });
  });

  group('AgeRange', () {
    test('only 13 to 17 is treated as a minor', () {
      expect(AgeRange.teen.isMinor, isTrue);
      expect(AgeRange.values.where((r) => r.isMinor), [AgeRange.teen]);
      expect(AgeRange.parse('adult'), AgeRange.adult);
      expect(AgeRange.parse('nope'), isNull);
    });
  });
}
