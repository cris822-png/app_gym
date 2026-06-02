import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores del design system en modo oscuro.
/// Todos los widgets deben referenciar AppColors, no usar colores literales.
class AppColors {
  AppColors._();

  // ── Fondos (de más oscuro a más claro) ──────────────────────────────────
  static const bg0 = Color(0xFF0D0F14); // fondo más profundo
  static const bg1 = Color(0xFF13161E); // scaffold background
  static const bg2 = Color(0xFF1C2030); // tarjetas
  static const bg3 = Color(0xFF252A3A); // inputs / elevated cards

  // ── Acentos principales ──────────────────────────────────────────────────
  static const accentGreen  = Color(0xFF00E5A0); // serie completada ✓
  static const accentBlue   = Color(0xFF4D9FFF); // acción principal
  static const accentPurple = Color(0xFF9B6DFF); // IA / Chat
  static const accentOrange = Color(0xFFFF7043); // warning / timer

  // ── Semánticos ───────────────────────────────────────────────────────────
  /// Fondo verde traslúcido para filas de serie completada
  static const serieCompletada = Color(0x2200E5A0);
  /// Borde verde de serie completada
  static const serieCompletadaBorder = Color(0x6600E5A0);
  /// Texto placeholder (registro anterior)
  static const placeholder = Color(0xFF4A5270);

  // ── Texto ────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF8892B0);
  static const textMuted     = Color(0xFF4A5270);

  // ── Utilidades ───────────────────────────────────────────────────────────
  static const divider = Color(0xFF1C2030);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg1,
      colorScheme: const ColorScheme.dark(
        primary:          AppColors.accentBlue,
        secondary:        AppColors.accentGreen,
        tertiary:         AppColors.accentPurple,
        surface:          AppColors.bg2,
        onSurface:        AppColors.textPrimary,
        onPrimary:        Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -0.3),
        titleLarge: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
        titleMedium: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: AppColors.textSecondary),
        labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: AppColors.textMuted, letterSpacing: 0.5),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bg2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bg3, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg3,
        hintStyle: GoogleFonts.inter(
          fontSize: 14, color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg2,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.bg3, thickness: 1, space: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}
