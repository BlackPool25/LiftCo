// lib/config/theme.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // === ENERGETIC FITNESS COLOR PALETTE ===
  
  // Background colors - True dark with subtle warmth
  static const Color background = Color(0xFF0A0A0F);
  static const Color backgroundSecondary = Color(0xFF0F0F14);
  static const Color surface = Color(0xFF15151A);
  static const Color surfaceLight = Color(0xFF1E1E26);
  static const Color surfaceBorder = Color(0xFF2A2A35);
  
  // Glassmorphism colors
  static Color get glassBackground => const Color(0xFF1A1A24).withValues(alpha: 0.6);
  static Color get glassBorder => const Color(0xFF3A3A4A).withValues(alpha: 0.3);
  
  // Primary gradient colors - Warm Amber to Teal
  static const Color primaryOrange = Color(0xFFE8956A);
  static const Color primaryCoral = Color(0xFFF0A878);
  static const Color primaryBlue = Color(0xFF4ECDC4);
  static const Color accentCyan = Color(0xFF45B7AA);
  static const Color accentLime = Color(0xFF7CFC00);
  
  // Legacy color aliases for compatibility
  static const Color primaryPurple = primaryOrange; // Map to new primary
  static const Color primaryIndigo = primaryCoral;
  static const Color accentPink = Color(0xFFEC4899);
  
  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDim = Color(0xFF475569);
  
  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // === GRADIENT DEFINITIONS ===
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryOrange, primaryCoral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [primaryBlue, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient meshGradient = LinearGradient(
    colors: [
      Color(0xFFE8956A),
      Color(0xFFF0A878),
      Color(0xFF4ECDC4),
      Color(0xFF45B7AA),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.33, 0.66, 1.0],
  );
  
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [backgroundSecondary, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Card-specific gradients (like the wallet card in reference)
  static const LinearGradient featureCardGradient = LinearGradient(
    colors: [
      Color(0xFF1A3A4A),
      Color(0xFF0F2E3D),
      Color(0xFF0A1F2A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // === THEME DATA ===
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: accentCyan,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        error: error,
      ),
      textTheme: TextTheme(
        // Display - Large hero text
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1,
          height: 1.15,
        ),
        // Headlines
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        // Titles
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        // Body
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: textSecondary,
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: textMuted,
          height: 1.5,
        ),
        // Labels
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textMuted,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: surfaceBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: surfaceBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: surfaceBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(
          color: textMuted,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryPurple,
        disabledColor: surfaceLight,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: surfaceBorder),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // === HELPER METHODS ===
  
  /// Creates a glassmorphic decoration
  static BoxDecoration glassDecoration({
    double borderRadius = 24,
    bool hasBorder = true,
    Color? customColor,
  }) {
    return BoxDecoration(
      color: customColor ?? glassBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(color: glassBorder, width: 1) : null,
    );
  }
  
  /// Creates a gradient card decoration
  static BoxDecoration gradientCardDecoration({
    required List<Color> colors,
    double borderRadius = 24,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: shadows,
    );
  }
}
