import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A light, neutral canvas with a clear blue accent, plus a slate dark mode.
class VeyroTheme {
  static const blue = Color(0xFF1D57D6);
  static const font = 'Manrope';

  static final light = _build(
    ColorScheme.fromSeed(seedColor: blue).copyWith(
      primary: blue,
      primaryContainer: const Color(0xFFE6EFFF),
      onPrimaryContainer: const Color(0xFF163D83),
      surface: const Color(0xFFF0F2F5),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF5F6F8),
      surfaceContainerHigh: const Color(0xFFEAEDF2),
      surfaceContainerHighest: const Color(0xFFE1E6EE),
      onSurface: const Color(0xFF182230),
      onSurfaceVariant: const Color(0xFF525E71),
      outline: const Color(0xFF8490A1),
      outlineVariant: const Color(0xFFDCE1E8),
    ),
  );

  static final dark = _build(
    ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark).copyWith(
      primary: const Color(0xFF96BEFF),
      onPrimary: const Color(0xFF102447),
      primaryContainer: const Color(0xFF233B60),
      onPrimaryContainer: const Color(0xFFD9E7FF),
      surface: const Color(0xFF171C24),
      surfaceContainerLowest: const Color(0xFF12161E),
      surfaceContainerLow: const Color(0xFF222933),
      surfaceContainer: const Color(0xFF262F3A),
      surfaceContainerHigh: const Color(0xFF2F3946),
      surfaceContainerHighest: const Color(0xFF3A4656),
      onSurface: const Color(0xFFF0F3F8),
      onSurfaceVariant: const Color(0xFFB8C2D0),
      outline: const Color(0xFF748196),
      outlineVariant: const Color(0xFF384453),
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final rounding = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outline),
    );
    const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      fontFamily: font,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      iconTheme: IconThemeData(color: scheme.onSurface),
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      appBarTheme: AppBarThemeData(
        toolbarHeight: 56,
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontFamily: font,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.55,
        ),
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: scheme.surface,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: buttonText,
          shape: rounding,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: buttonText,
          shape: rounding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: buttonText,
          shape: rounding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonText, shape: rounding),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: scheme.onSurface, fontFamily: font),
        actionTextColor: scheme.primary,
        shape: rounding,
        width: 480,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: .28),
        selectionHandleColor: scheme.primary,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          height: 1.15,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.45,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.22,
        ),
        bodySmall:
            base.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

extension VeyroThemeContext on BuildContext {
  ColorScheme get veyroColors => Theme.of(this).colorScheme;
  TextTheme get veyroText => Theme.of(this).textTheme;
}
