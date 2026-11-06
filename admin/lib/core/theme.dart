import 'package:flutter/material.dart';

/// Palet panel admin, diturunkan dari logo resmi RTSQ.
class AdminColors {
  static const bg = Color(0xFFF4F6F5);
  static const surface = Colors.white;
  static const panel = Color(0xFF0E1B17);
  static const panelAlt = Color(0xFF16261F);
  static const ink = Color(0xFF12211D);
  static const inkSoft = Color(0xFF4B5F57);
  static const gold = Color(0xFFA8892F);
  static const goldSoft = Color(0xFFF6F0DF);
  static const teal = Color(0xFF0F8F7F);
  static const tealSoft = Color(0xFFE3F4F1);
  static const line = Color(0xFFDCE3E0);
  static const danger = Color(0xFFC4463A);
  static const dangerSoft = Color(0xFFFBECEA);
  static const success = Color(0xFF1F7A4D);
  static const successSoft = Color(0xFFE6F3EC);
  static const warn = Color(0xFF9A6B12);
  static const warnSoft = Color(0xFFFBF2DD);
}

class AdminText {
  static const family = 'PlusJakartaSans';

  static const title = TextStyle(
    fontFamily: family,
    fontSize: 26,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AdminColors.ink,
  );

  static const h2 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AdminColors.ink,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AdminColors.ink,
  );

  static const label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AdminColors.inkSoft,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AdminColors.inkSoft,
  );
}

ThemeData buildAdminTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AdminColors.teal,
      primary: AdminColors.teal,
      surface: AdminColors.surface,
      error: AdminColors.danger,
    ),
    scaffoldBackgroundColor: AdminColors.bg,
    fontFamily: AdminText.family,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AdminColors.ink,
      displayColor: AdminColors.ink,
      fontFamily: AdminText.family,
    ),
    cardTheme: CardThemeData(
      color: AdminColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.teal, width: 1.6),
      ),
      labelStyle: AdminText.label,
      hintStyle: AdminText.caption,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: AdminText.family,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.ink,
        side: const BorderSide(color: AdminColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: AdminText.family,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.teal,
        textStyle: const TextStyle(
          fontFamily: AdminText.family,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: AdminColors.line),
      labelStyle: AdminText.caption,
    ),
    dividerTheme: const DividerThemeData(color: AdminColors.line, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontFamily: AdminText.family,
        color: Colors.white,
        fontSize: 12,
      ),
    ),
  );
}
