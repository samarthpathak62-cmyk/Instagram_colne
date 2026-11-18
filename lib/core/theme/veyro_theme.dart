import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Veyro's violet-on-midnight palette, with a matching light option.
class VeyroTheme {
  static const ink = Color(0xFF0C0914);
  static const violet = Color(0xFF7036E5);
  static const lavender = Color(0xFFCBB0FF);
  static const frost = Color(0xFFF8F3FF);
  static const font = 'Manrope';

  static final dark = _build(
    ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.dark)
        .copyWith(
      primary: lavender,
      onPrimary: const Color(0xFF231138),
      primaryContainer: const Color(0xFF38255B),
      onPrimaryContainer: const Color(0xFFEEE0FF),
      secondary: const Color(0xFFDAA9FF),
      secondaryContainer: const Color(0xFF251937),
      onSecondaryContainer: const Color(0xFFDFCBFE),
      surface: ink,
      surfaceContainerLow: const Color(0xFF120E1C),
      surfaceContainer: const Color(0xFF181224),
      surfaceContainerHigh: const Color(0xFF211831),
      surfaceContainerHighest: const Color(0xFF2A203C),
      onSurface: frost,
      onSurfaceVariant: const Color(0xFFBAAEC9),
      outline: const Color(0xFF786787),
      outlineVariant: const Color(0xFF352946),
      error: const Color(0xFFFF9DB5),
    ),
  );

  static final light = _build(
    ColorScheme.fromSeed(seedColor: violet).copyWith(
      primary: const Color(0xFF5928C6),
      primaryContainer: const Color(0xFFE9DCFF),
      onPrimaryContainer: const Color(0xFF351465),
      surface: const Color(0xFFFAF7FF),
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainer: const Color(0xFFF2ECFA),
      surfaceContainerHigh: const Color(0xFFECE3F7),
      surfaceContainerHighest: const Color(0xFFE5DBF0),
      onSurface: const Color(0xFF211532),
      onSurfaceVariant: const Color(0xFF645773),
      outlineVariant: const Color(0xFFDCCFE8),
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final rounding = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
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
        toolbarHeight: 64,
        backgroundColor: scheme.surface,
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
          borderRadius: BorderRadius.circular(20),
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
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: font,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 23,
          );
        }),
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
        backgroundColor: scheme.surfaceContainer,
        modalBackgroundColor: scheme.surfaceContainer,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
