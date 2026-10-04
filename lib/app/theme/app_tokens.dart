import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Raw palette. Only referenced from the theme layer — widgets read colours
/// through [AppTokens] / [ColorScheme] so the design stays consistent.
abstract final class AppPalette {
  /// Warm beige page background. Never use pure white.
  static const beige = Color(0xFFF2E8D8);

  /// Slightly darker beige for secondary surfaces (chips, inputs, sheets).
  static const beigeDeep = Color(0xFFE7D8C3);

  /// Muted beige-grey for borders and dividers.
  static const beigeGrey = Color(0xFFCBBBA5);

  /// Deep black for text, icons, primary buttons and emphasis.
  static const ink = Color(0xFF171717);

  /// Warm, darkened grey-brown for secondary text. ~6.3:1 on [beige].
  static const inkMuted = Color(0xFF5C5246);

  /// Placeholder shimmer base for skeletons.
  static const skeleton = Color(0xFFDDCDB6);

  /// Functional error colour: a muted oxblood (~7:1 on [beige]). It is the
  /// single non-monochrome tone and is used *only* for validation/errors,
  /// always paired with text or an icon — never as decoration.
  static const error = Color(0xFF7A2E22);
}

/// Spacing scale (4-pt grid).
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Max readable width for content columns on tablets/desktop/web.
  static const maxContentWidth = 680.0;
}

/// Corner radii shared across every component.
abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
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
    required this.background,
    required this.surface,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.onInk,
    required this.skeleton,
    required this.error,
    required this.cardElevation,
  });

  static const standard = AppTokens(
    background: AppPalette.beige,
    surface: AppPalette.beigeDeep,
    border: AppPalette.beigeGrey,
    ink: AppPalette.ink,
    inkMuted: AppPalette.inkMuted,
    onInk: AppPalette.beige,
    skeleton: AppPalette.skeleton,
    error: AppPalette.error,
    cardElevation: 0,
  );

  final Color background;
  final Color surface;
  final Color border;
  final Color ink;
  final Color inkMuted;
  final Color onInk;
  final Color skeleton;
  final Color error;
  final double cardElevation;

  @override
  AppTokens copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? ink,
    Color? inkMuted,
    Color? onInk,
    Color? skeleton,
    Color? error,
    double? cardElevation,
  }) {
    return AppTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      onInk: onInk ?? this.onInk,
      skeleton: skeleton ?? this.skeleton,
      error: error ?? this.error,
      cardElevation: cardElevation ?? this.cardElevation,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      error: Color.lerp(error, other.error, t)!,
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.standard;

  TextTheme get text => Theme.of(this).textTheme;
}
