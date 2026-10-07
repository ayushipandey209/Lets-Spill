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
    required Color color,
    double height = 1.4,
    double letterSpacing = 0,
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

  /// A compact, reading-first scale (body 15, metadata 12).
  static TextTheme textTheme(AppTokens t) {
    TextStyle s(
      double size,
      int weight, {
      double height = 1.4,
      double letterSpacing = 0,
      Color? color,
    }) => style(
      size: size,
      weight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? t.ink,
    );

    return TextTheme(
      // Wordmark / hero.
      displayLarge: s(42, 800, height: 1.05, letterSpacing: -1.1),
      displayMedium: s(34, 800, height: 1.08, letterSpacing: -0.8),
      displaySmall: s(26, 750, height: 1.15, letterSpacing: -0.5),
      // Screen titles.
      headlineLarge: s(24, 720, height: 1.18, letterSpacing: -0.4),
      headlineMedium: s(20, 700, height: 1.22, letterSpacing: -0.3),
      headlineSmall: s(18, 700, height: 1.25, letterSpacing: -0.2),
      // Section titles / app bar.
      titleLarge: s(17, 660, height: 1.3, letterSpacing: -0.1),
      titleMedium: s(15, 620, height: 1.35),
      titleSmall: s(13.5, 620, height: 1.35),
      // Reading text: comfortable line height for long confessions.
      bodyLarge: s(15.5, 420, height: 1.58),
      bodyMedium: s(14, 420, height: 1.5),
      bodySmall: s(12.5, 460, height: 1.45, color: t.inkMuted),
      // Buttons, chips, metadata.
      labelLarge: s(14, 650, height: 1.2, letterSpacing: 0.1),
      labelMedium: s(12.5, 600, height: 1.2, letterSpacing: 0.1),
      labelSmall: s(10.5, 700, height: 1.2, letterSpacing: 0.9),
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
  static ThemeData light() => build(AppTokens.light);

  static ThemeData dark() => build(AppTokens.dark);

  static ThemeData build(AppTokens t) {
    final text = AppTypography.textTheme(t);
    final isDark = t.isDark;

    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.ink,
      onPrimary: t.onInk,
      primaryContainer: t.surface,
      onPrimaryContainer: t.ink,
      secondary: t.accent,
      onSecondary: t.onInk,
      secondaryContainer: t.surface,
      onSecondaryContainer: t.ink,
      tertiary: t.inkMuted,
      onTertiary: t.onInk,
      error: t.error,
      onError: t.onInk,
      surface: t.background,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted,
      surfaceContainerLowest: t.background,
      surfaceContainerLow: t.card,
      surfaceContainer: t.card,
      surfaceContainerHigh: t.surface,
      surfaceContainerHighest: t.surface,
      outline: t.border,
      outlineVariant: t.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: t.ink,
      onInverseSurface: t.onInk,
      inversePrimary: t.onInk,
      surfaceTint: Colors.transparent,
    );

    final buttonShape = WidgetStateProperty.all<OutlinedBorder>(
      const RoundedRectangleBorder(borderRadius: AppRadii.button),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
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
      brightness: t.brightness,
      extensions: [t],
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.ink, size: 21),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: t.ink),
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: t.card,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                ),
        shape: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          padding: WidgetStateProperty.all(buttonPadding),
          textStyle: buttonText,
          minimumSize: WidgetStateProperty.all(const Size(64, 48)),
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
          minimumSize: WidgetStateProperty.all(const Size(64, 48)),
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
          minimumSize: WidgetStateProperty.all(const Size(64, 48)),
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
        color: t.card,
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
        fillColor: t.surface.withValues(alpha: isDark ? 0.8 : 0.55),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        backgroundColor: t.card,
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
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.card,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: t.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.card,
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onInk : t.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.ink : t.surface,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.ink : t.border,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.surface,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 23,
            color: s.contains(WidgetState.selected) ? t.ink : t.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium!.copyWith(
            fontSize: 11.5,
            color: s.contains(WidgetState.selected) ? t.ink : t.inkMuted,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: text.labelMedium!.copyWith(color: t.onInk),
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
