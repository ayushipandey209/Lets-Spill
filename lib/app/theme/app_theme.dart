import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

/// Figtree is bundled as a *variable* font. Flutter does not reliably map
/// `fontWeight` onto the `wght` axis of a single variable file, so every style
/// sets both `fontWeight` (semantics/fallback) and an explicit `wght` variation.
abstract final class AppTypography {
  static const family = 'Figtree';

  static TextStyle style({
    required double size,
    required int weight,
    double height = 1.4,
    double letterSpacing = 0,
    Color color = AppPalette.ink,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  static FontWeight _weight(int w) {
    final index = ((w.clamp(100, 900) / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  static TextTheme textTheme() {
    return TextTheme(
      // Wordmark / hero.
      displayLarge: style(size: 48, weight: 800, height: 1.05, letterSpacing: -1.2),
      displayMedium: style(size: 38, weight: 800, height: 1.08, letterSpacing: -0.9),
      displaySmall: style(size: 30, weight: 750, height: 1.12, letterSpacing: -0.6),
      // Screen titles.
      headlineLarge: style(size: 28, weight: 700, height: 1.15, letterSpacing: -0.5),
      headlineMedium: style(size: 24, weight: 700, height: 1.2, letterSpacing: -0.4),
      headlineSmall: style(size: 20, weight: 700, height: 1.25, letterSpacing: -0.2),
      // Section titles / app bar.
      titleLarge: style(size: 18, weight: 650, height: 1.3, letterSpacing: -0.1),
      titleMedium: style(size: 16, weight: 600, height: 1.35),
      titleSmall: style(size: 14, weight: 600, height: 1.35),
      // Reading text — generous line height for long confessions.
      bodyLarge: style(size: 17, weight: 420, height: 1.6),
      bodyMedium: style(size: 15, weight: 420, height: 1.55),
      bodySmall: style(size: 13, weight: 450, height: 1.45, color: AppPalette.inkMuted),
      // Buttons, chips, metadata.
      labelLarge: style(size: 15, weight: 650, height: 1.2, letterSpacing: 0.1),
      labelMedium: style(size: 13, weight: 600, height: 1.2, letterSpacing: 0.2),
      labelSmall: style(size: 11, weight: 700, height: 1.2, letterSpacing: 1.1),
    );
  }
}

extension TextStyleWeightX on TextStyle {
  /// Changes weight *and* the variable-font axis together.
  TextStyle withWeight(int weight) => copyWith(
    fontWeight: AppTypography._weight(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}

abstract final class AppTheme {
  static ThemeData light() {
    const t = AppTokens.standard;
    final text = AppTypography.textTheme();

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.ink,
      onPrimary: AppPalette.beige,
      primaryContainer: AppPalette.beigeDeep,
      onPrimaryContainer: AppPalette.ink,
      secondary: AppPalette.ink,
      onSecondary: AppPalette.beige,
      secondaryContainer: AppPalette.beigeDeep,
      onSecondaryContainer: AppPalette.ink,
      tertiary: AppPalette.inkMuted,
      onTertiary: AppPalette.beige,
      error: AppPalette.error,
      onError: AppPalette.beige,
      surface: AppPalette.beige,
      onSurface: AppPalette.ink,
      onSurfaceVariant: AppPalette.inkMuted,
      surfaceContainerLowest: AppPalette.beige,
      surfaceContainerLow: AppPalette.beige,
      surfaceContainer: AppPalette.beigeDeep,
      surfaceContainerHigh: AppPalette.beigeDeep,
      surfaceContainerHighest: AppPalette.beigeDeep,
      outline: AppPalette.beigeGrey,
      outlineVariant: AppPalette.beigeGrey,
      shadow: AppPalette.ink,
      scrim: AppPalette.ink,
      inverseSurface: AppPalette.ink,
      onInverseSurface: AppPalette.beige,
      inversePrimary: AppPalette.beige,
      surfaceTint: Colors.transparent,
    );

    final buttonShape = WidgetStateProperty.all<OutlinedBorder>(
      const RoundedRectangleBorder(borderRadius: AppRadii.button),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 16);
    final buttonText = WidgetStateProperty.all(text.labelLarge);

    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadii.input,
      borderSide: BorderSide(color: t.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: const [t],
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.ink, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: t.ink),
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        shape: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          padding: WidgetStateProperty.all(buttonPadding),
          textStyle: buttonText,
          minimumSize: WidgetStateProperty.all(const Size(64, 52)),
          elevation: WidgetStateProperty.all(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? t.ink.withValues(alpha: 0.28)
                : t.ink,
          ),
          foregroundColor: WidgetStateProperty.all(t.onInk),
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? t.onInk.withValues(alpha: 0.14)
                : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
                    ? t.onInk.withValues(alpha: 0.08)
                    : null,
          ),
          animationDuration: AppMotion.fast,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          padding: WidgetStateProperty.all(buttonPadding),
          textStyle: buttonText,
          minimumSize: WidgetStateProperty.all(const Size(64, 52)),
          elevation: WidgetStateProperty.all(0),
          backgroundColor: WidgetStateProperty.all(t.ink),
          foregroundColor: WidgetStateProperty.all(t.onInk),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          padding: WidgetStateProperty.all(buttonPadding),
          textStyle: buttonText,
          minimumSize: WidgetStateProperty.all(const Size(64, 52)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? t.ink.withValues(alpha: 0.38)
                : t.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled)
                  ? t.border
                  : t.ink,
              width: 1.2,
            ),
          ),
          overlayColor: WidgetStateProperty.all(t.ink.withValues(alpha: 0.06)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          textStyle: WidgetStateProperty.all(text.labelLarge),
          foregroundColor: WidgetStateProperty.all(t.ink),
          overlayColor: WidgetStateProperty.all(t.ink.withValues(alpha: 0.06)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(t.ink),
          overlayColor: WidgetStateProperty.all(t.ink.withValues(alpha: 0.06)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.ink,
        foregroundColor: t.onInk,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 1,
        extendedTextStyle: text.labelLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.background,
        selectedColor: t.ink,
        disabledColor: t.surface,
        checkmarkColor: t.onInk,
        side: BorderSide(color: t.border),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: t.onInk),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: t.background,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: t.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: text.bodyMedium!.copyWith(color: t.inkMuted),
        floatingLabelStyle: text.labelMedium!.copyWith(color: t.ink),
        hintStyle: text.bodyMedium!.copyWith(color: t.inkMuted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: t.error),
        errorMaxLines: 3,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: t.ink, width: 1.4),
        ),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: t.error)),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: t.error, width: 1.4),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.ink,
        selectionColor: t.ink.withValues(alpha: 0.18),
        selectionHandleColor: t.ink,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.ink,
        linearTrackColor: t.surface,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: t.onInk),
        actionTextColor: t.onInk,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: t.border),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.background,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: t.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.background,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.input,
          side: BorderSide(color: t.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.ink,
        textColor: t.ink,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(t.ink),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.ink : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(t.onInk),
        side: BorderSide(color: t.ink, width: 1.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
