import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme following the Lébénam brand: cream and navy surfaces,
/// Newsreader (serif) headings, Hanken Grotesk text, pill buttons in
/// Lébénam blue, orange focus. No shadows: cards are separated by hairlines.
abstract final class AppTheme {
  static const radius = 20.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Transparent status and navigation bars with icons matching the theme.
  static SystemUiOverlayStyle systemBars(bool isDark) =>
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          );

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceHigh = isDark
        ? AppColors.darkSurfaceHigh
        : AppColors.lightSurfaceHigh;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.lightInkMuted;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.brand,
          onPrimary: AppColors.cream,
          secondary: AppColors.brand,
          onSecondary: Colors.white,
          error: AppColors.urgent,
          surface: background,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: surfaceHigh,
          surfaceContainerHighest: surfaceHigh,
          outline: muted,
          outlineVariant: hairline,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
    );
    final sans = GoogleFonts.hankenGroteskTextTheme(base.textTheme);
    // Headings: Newsreader, medium weight, tight tracking (as on the site).
    TextStyle? serif(TextStyle? s, double spacing) => GoogleFonts.newsreader(
      textStyle: s,
      fontWeight: FontWeight.w500,
      letterSpacing: spacing,
      height: 1.08,
    );
    TextStyle? tight(TextStyle? s, FontWeight w, double spacing) =>
        s?.copyWith(fontWeight: w, letterSpacing: spacing);

    final textTheme = sans
        .copyWith(
          displayLarge: serif(sans.displayLarge, -1.5),
          displayMedium: serif(sans.displayMedium, -1.2),
          displaySmall: serif(sans.displaySmall, -1),
          headlineLarge: serif(sans.headlineLarge, -0.8),
          headlineMedium: serif(sans.headlineMedium, -0.6),
          headlineSmall: serif(sans.headlineSmall, -0.4),
          titleLarge: tight(sans.titleLarge, FontWeight.w600, -0.3),
          titleMedium: tight(sans.titleMedium, FontWeight.w600, -0.2),
          titleSmall: tight(sans.titleSmall, FontWeight.w600, -0.1),
          labelLarge: tight(sans.labelLarge, FontWeight.w600, 0),
          bodyLarge: sans.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: sans.bodyMedium?.copyWith(height: 1.45),
          bodySmall: sans.bodySmall?.copyWith(color: muted),
          labelMedium: sans.labelMedium?.copyWith(color: muted),
          labelSmall: sans.labelSmall?.copyWith(color: muted),
        )
        .apply(bodyColor: ink, displayColor: ink);

    const pill = StadiumBorder();
    final buttonText = GoogleFonts.hankenGrotesk(
      fontWeight: FontWeight.w600,
      fontSize: 15,
      letterSpacing: -0.1,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: hairline, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        systemOverlayStyle: systemBars(isDark),
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 17),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
      // Also styles genui_catalog cards: their hard-coded elevation casts no
      // shadow, and they get the same hairline border as our TriageCard.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: pill,
          elevation: 0,
          textStyle: buttonText,
          disabledBackgroundColor: surfaceHigh,
          disabledForegroundColor: muted,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: pill,
          foregroundColor: ink,
          side: BorderSide(color: hairline),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: buttonText,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: BorderSide.none,
        backgroundColor: surfaceHigh,
        selectedColor: AppColors.brand.withValues(alpha: isDark ? 0.28 : 0.16),
        showCheckmark: false,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: textTheme.bodyLarge?.copyWith(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        // Hairline so fields stay visible on a card of the same colour
        // (genui_catalog forms).
        border: fieldBorder,
        enabledBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: hairline),
        ),
        disabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(
            color: AppColors.brandOrange,
            width: 1.5,
          ),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.urgent),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.urgent, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        showValueIndicator: ShowValueIndicator.onDrag,
        trackHeight: 4,
        inactiveTrackColor: surfaceHigh,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.darkSurfaceHigh : AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: hairline),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
