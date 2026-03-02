
import 'package:flutter/material.dart';

class CaretakerColors {
  static const Color primaryGreen = Color(0xFF1FA37A);
  static const Color lightGreen = Color(0xFFE6F6F1);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFF4B400);
  static const Color errorRed = Color(0xFFE5533D);
  static const Color background = Color(0xFFF9FBFA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color dividerGrey = Color(0xFFE6EAEA);
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color mutedIconGrey = Color(0xFF9CA3AF);
  static const Color highlightBlue = Color(0xFF2F80ED);
}

class CaretakerTextStyles {
  // App Title: 18-20, w700
  static const TextStyle header = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: CaretakerColors.textPrimary,
    fontFamily: 'Inter',
  );

  // Section Header: 16, w700
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: CaretakerColors.textPrimary,
    fontFamily: 'Inter',
  );

  // Card Title: 15, w600
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: CaretakerColors.textPrimary,
    fontFamily: 'Inter',
  );

  // Body: 13-14, w400
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: CaretakerColors.textPrimary,
    fontFamily: 'Inter',
  );

  // Caption: 11-12, w400/500
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: CaretakerColors.textSecondary,
    fontFamily: 'Inter',
  );
}

class CaretakerLayout {
  static const EdgeInsets screenPadding = EdgeInsets.all(16);
  static final BorderRadius cardRadius = BorderRadius.circular(14);
  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
