import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme: Poppins for headings, Inter for body, 16px radii.
abstract final class AppTheme {
  static const radius = 16.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Soft shadow shared by every card of the app and of the catalog.
  static List<BoxShadow> cardShadow(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.35)
          : AppColors.primary.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final cardColor = isDark ? AppColors.darkCard : AppColors.card;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          // In dark mode the deep teal has no contrast, so the cyan leads.
          primary: isDark ? AppColors.accent : AppColors.primary,
          onPrimary: isDark ? AppColors.primary : Colors.white,
          secondary: AppColors.accent,
          onSecondary: AppColors.primary,
          error: AppColors.urgent,
          surface: isDark ? AppColors.darkBackground : AppColors.background,
          onSurface: ink,
          surfaceContainerLowest: cardColor,
          surfaceContainerLow: cardColor,
          surfaceContainer: isDark
              ? const Color(0xFF123030)
              : const Color(0xFFEFF9F8),
        );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final body = GoogleFonts.interTextTheme(base.textTheme);
    TextStyle? heading(TextStyle? s, FontWeight w) =>
        GoogleFonts.poppins(textStyle: s, fontWeight: w);

    final textTheme = body
        .copyWith(
          displayLarge: heading(body.displayLarge, FontWeight.w700),
          displayMedium: heading(body.displayMedium, FontWeight.w700),
          displaySmall: heading(body.displaySmall, FontWeight.w700),
          headlineLarge: heading(body.headlineLarge, FontWeight.w700),
          headlineMedium: heading(body.headlineMedium, FontWeight.w600),
          headlineSmall: heading(body.headlineSmall, FontWeight.w600),
          titleLarge: heading(body.titleLarge, FontWeight.w600),
          titleMedium: heading(body.titleMedium, FontWeight.w600),
          titleSmall: heading(body.titleSmall, FontWeight.w600),
        )
        .apply(bodyColor: ink, displayColor: ink);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: shape,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: shape,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: cardColor,
        labelStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
    );
  }
}
