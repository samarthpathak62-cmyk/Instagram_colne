import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The orbital mark supplies the violet accent in both Midnight and Daylight.
class VeyroTheme {
  static const violet = Color(0xFF6832CB);
  static const midnight = Color(0xFF100D17);
  static const lilac = Color(0xFFD1B8FF);
  static const frost = Color(0xFFFBF7FF);
  static const font = 'Manrope';
  static const orbit = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0CCFF), Color(0xFFAD7BFA), Color(0xFF692FE0)],
  );

  static final light = _build(
    ColorScheme.fromSeed(seedColor: violet).copyWith(
      primary: violet,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFECE1FF),
      onPrimaryContainer: const Color(0xFF47217D),
      surface: const Color(0xFFF8F6FC),
      surfaceContainerLowest: const Color(0xFFF1EDF7),
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF5F0FB),
      surfaceContainerHigh: const Color(0xFFF0EAF8),
      surfaceContainerHighest: const Color(0xFFECE4F6),
      onSurface: const Color(0xFF20182B),
      onSurfaceVariant: const Color(0xFF685B77),
      outline: const Color(0xFF8A789B),
      outlineVariant: const Color(0xFFE7DDF0),
    ),
  );

  static final dark = _build(
    ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.dark)
        .copyWith(
      primary: lilac,
      onPrimary: const Color(0xFF2C114B),
      primaryContainer: const Color(0xFF322048),
      onPrimaryContainer: const Color(0xFFEAD9FF),
      surface: midnight,
      surfaceContainerLowest: const Color(0xFF0B0910),
      surfaceContainerLow: const Color(0xFF18131F),
      surfaceContainer: const Color(0xFF1D1727),
      surfaceContainerHigh: const Color(0xFF251D31),
      surfaceContainerHighest: const Color(0xFF31243F),
      onSurface: frost,
      onSurfaceVariant: const Color(0xFFBDB0CE),
      outline: const Color(0xFF897897),
      outlineVariant: const Color(0xFF342941),
    ),
  );

  static SystemUiOverlayStyle overlay(ColorScheme colors) =>
      (colors.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: colors.surfaceContainerLow,
        systemNavigationBarContrastEnforced: false,
      );

  static ThemeData _build(ColorScheme scheme) {
    final rounding = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
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
        systemOverlayStyle: overlay(scheme),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
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
          backgroundColor: violet,
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
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
        headlineSmall: base.textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.7),
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
