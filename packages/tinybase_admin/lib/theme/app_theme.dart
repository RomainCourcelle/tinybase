import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Thème unique dark — Lexend pour l'UI, lisible et un cran plus character
/// qu'un Inter/Roboto par défaut.
ThemeData buildAppTheme() {
  final baseText = GoogleFonts.lexendTextTheme(ThemeData.dark().textTheme);

  final textTheme = baseText.copyWith(
    displaySmall: baseText.displaySmall?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600, letterSpacing: -0.5),
    headlineMedium: baseText.headlineMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600, letterSpacing: -0.4),
    headlineSmall: baseText.headlineSmall?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    titleLarge: baseText.titleLarge?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
    titleMedium: baseText.titleMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w500),
    titleSmall: baseText.titleSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w500),
    bodyLarge: baseText.bodyLarge?.copyWith(color: AppColors.text),
    bodyMedium: baseText.bodyMedium?.copyWith(color: AppColors.textMuted),
    bodySmall: baseText.bodySmall?.copyWith(color: AppColors.textFaint),
    labelLarge: baseText.labelLarge?.copyWith(color: AppColors.text, fontWeight: FontWeight.w500),
  );

  final scheme = ColorScheme.dark(
    surface: AppColors.surface,
    onSurface: AppColors.text,
    primary: AppColors.accent,
    onPrimary: const Color(0xFF062016),
    secondary: AppColors.accentDim,
    onSecondary: AppColors.text,
    error: AppColors.danger,
    onError: AppColors.text,
    outline: AppColors.border,
    surfaceContainerHighest: AppColors.surfaceHover,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.borderSubtle,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.borderSubtle, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textMuted,
      textColor: AppColors.text,
      selectedColor: AppColors.accent,
      selectedTileColor: AppColors.accentMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgElevated,
      hintStyle: const TextStyle(color: AppColors.textFaint),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF062016),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHover,
      side: const BorderSide(color: AppColors.borderSubtle),
      labelStyle: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.bgElevated),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return AppColors.surfaceHover;
        return AppColors.surface;
      }),
      headingTextStyle: textTheme.labelLarge?.copyWith(color: AppColors.textMuted, fontSize: 12),
      dataTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.text, fontSize: 13),
      dividerThickness: 1,
      headingRowHeight: 44,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHover,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textFaint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.accentMuted : AppColors.border),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: AppColors.text),
    ),
  );
}
