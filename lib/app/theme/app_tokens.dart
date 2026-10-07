import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Raw palettes. Only referenced from the theme layer; widgets read colours
/// through [AppTokens] so light and dark mode stay consistent.
abstract final class LightPalette {
  /// Warm beige page background.
  static const background = Color(0xFFF2E8D8);

  /// Cards sit slightly lighter than the page, like Reddit's post cards.
  static const card = Color(0xFFFAF4EA);

  /// Chips, inputs, segmented controls.
  static const surface = Color(0xFFE9DCC8);
  static const border = Color(0xFFD6C6AE);
  static const ink = Color(0xFF171717);

  /// Secondary text, about 6.3:1 on [background].
  static const inkMuted = Color(0xFF5C5246);
  static const skeleton = Color(0xFFE2D3BD);

  /// Muted oxblood used only for errors and destructive actions.
  static const error = Color(0xFF8A2E22);

  /// Terracotta for likes and highlights (about 4.8:1 on [card]).
  static const accent = Color(0xFFB4441E);
}

abstract final class DarkPalette {
  /// Warm near-black: easier on the eyes than pure black at night.
  static const background = Color(0xFF121110);
  static const card = Color(0xFF1B1A18);
  static const surface = Color(0xFF26231F);
  static const border = Color(0xFF36322D);

  /// Warm off-white body text (about 15:1 on [background]).
  static const ink = Color(0xFFEDE6DA);

  /// Secondary text (about 7.6:1 on [background]).
  static const inkMuted = Color(0xFFB1A898);
  static const skeleton = Color(0xFF2B2824);
  static const error = Color(0xFFF08A78);
  static const accent = Color(0xFFFF8A5C);
}

/// Spacing scale (4 pt grid).
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const xxl = 44.0;

  /// Max readable width for content columns on tablets, desktop and web.
  static const maxContentWidth = 680.0;
}

/// Corner radii shared across every component.
abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;

  static const button = BorderRadius.all(Radius.circular(md));
  static const card = BorderRadius.all(Radius.circular(lg));
  static const input = BorderRadius.all(Radius.circular(md));
}

/// Motion tokens.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}

/// Design tokens exposed through `Theme.of(context).extension<AppTokens>()`
/// (or the `context.tokens` shortcut).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.card,
    required this.surface,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.onInk,
    required this.skeleton,
    required this.error,
    required this.accent,
    required this.cardElevation,
  });

  static const light = AppTokens(
    brightness: Brightness.light,
    background: LightPalette.background,
    card: LightPalette.card,
    surface: LightPalette.surface,
    border: LightPalette.border,
    ink: LightPalette.ink,
    inkMuted: LightPalette.inkMuted,
    onInk: LightPalette.background,
    skeleton: LightPalette.skeleton,
    error: LightPalette.error,
    accent: LightPalette.accent,
    cardElevation: 0,
  );

  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: DarkPalette.background,
    card: DarkPalette.card,
    surface: DarkPalette.surface,
    border: DarkPalette.border,
    ink: DarkPalette.ink,
    inkMuted: DarkPalette.inkMuted,
    onInk: DarkPalette.background,
    skeleton: DarkPalette.skeleton,
    error: DarkPalette.error,
    accent: DarkPalette.accent,
    cardElevation: 0,
  );

  /// Kept for older call sites; same as [light].
  static const standard = light;

  final Brightness brightness;
  final Color background;
  final Color card;
  final Color surface;
  final Color border;
  final Color ink;
  final Color inkMuted;

  /// Text and icons placed on an [ink] fill (primary buttons, selected chips).
  final Color onInk;
  final Color skeleton;
  final Color error;
  final Color accent;
  final double cardElevation;

  bool get isDark => brightness == Brightness.dark;

  @override
  AppTokens copyWith({
    Brightness? brightness,
    Color? background,
    Color? card,
    Color? surface,
    Color? border,
    Color? ink,
    Color? inkMuted,
    Color? onInk,
    Color? skeleton,
    Color? error,
    Color? accent,
    double? cardElevation,
  }) {
    return AppTokens(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      card: card ?? this.card,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      onInk: onInk ?? this.onInk,
      skeleton: skeleton ?? this.skeleton,
      error: error ?? this.error,
      accent: accent ?? this.accent,
      cardElevation: cardElevation ?? this.cardElevation,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      error: Color.lerp(error, other.error, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;

  TextTheme get text => Theme.of(this).textTheme;
}
