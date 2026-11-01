import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static const cardRadius = 24.0;

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final text = base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .apply(fontFamily: 'PlusJakartaSans');
    const cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
      side: BorderSide(color: AppColors.borderLine),
    );
    final button = FilledButton.styleFrom(
      backgroundColor: AppColors.charcoal,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: const StadiumBorder(),
      textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ).copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            primaryContainer: AppColors.lavenderSoft,
            onPrimaryContainer: AppColors.primaryDark,
            secondary: AppColors.peach,
            onSecondary: AppColors.charcoal,
            secondaryContainer: AppColors.peachSoft,
            onSecondaryContainer: AppColors.terracotta,
            surface: AppColors.surface,
            onSurface: AppColors.ink,
            onSurfaceVariant: AppColors.inkSecondary,
            outline: AppColors.borderLine,
            outlineVariant: AppColors.borderLine,
            surfaceContainerHighest: AppColors.surfaceSubtle,
          ),
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.charcoal,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.borderLine),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.borderLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.borderLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.lavenderSoft,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderLine),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.lavenderCard,
        side: const BorderSide(color: AppColors.borderLine),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
    );
  }
}
