import 'package:flutter/material.dart';

class AppTheme {
  // Brand palette
  static const Color _seed = Color(0xFF7C4DFF);
  static const Color _darkBg = Color(0xFF0D0D14);
  static const Color _darkSurface = Color(0xFF16162A);
  static const Color _darkCard = Color(0xFF1E1E35);
  static const Color _darkBorder = Color(0xFF2A2A48);
  static const Color _accent = Color(0xFF7C4DFF);
  static const Color _accentGlow = Color(0x337C4DFF);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _seed,
        scaffoldBackgroundColor: _darkBg,
        cardTheme: CardThemeData(
          color: _darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _darkBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontFamily: 'Inter'),
          bodyMedium: TextStyle(fontFamily: 'Inter'),
          labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        extensions: const [
          AppColors(
            background: _darkBg,
            surface: _darkSurface,
            card: _darkCard,
            border: _darkBorder,
            accent: _accent,
            accentGlow: _accentGlow,
          )
        ],
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: _seed,
        scaffoldBackgroundColor: const Color(0xFFF4F3FF),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E0FF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF4F3FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD6D0FF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD6D0FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        extensions: const [
          AppColors(
            background: Color(0xFFF4F3FF),
            surface: Colors.white,
            card: Colors.white,
            border: Color(0xFFE5E0FF),
            accent: _accent,
            accentGlow: _accentGlow,
          )
        ],
      );
}

// Custom theme extension for easy access to brand colors
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color accent;
  final Color accentGlow;

  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.accent,
    required this.accentGlow,
  });

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? accent,
    Color? accentGlow,
  }) =>
      AppColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        border: border ?? this.border,
        accent: accent ?? this.accent,
        accentGlow: accentGlow ?? this.accentGlow,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
    );
  }
}
