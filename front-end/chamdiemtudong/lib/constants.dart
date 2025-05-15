import 'package:flutter/material.dart';

// ==================== MÀU SẮC ====================
const Color primaryColor = Color(0xFF3B82F6);
const Color secondaryColor = Color(0xFF60A5FA);
const Color accentColor = Color(0xFFFFF59D);
const Color backgroundColor = Color(0xFFF1F5F9);
const Color cardColor = Colors.white;

// ==================== GRADIENT ====================
const LinearGradient primaryGradient = LinearGradient(
  colors: [primaryColor, secondaryColor],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ==================== TEXT STYLE ====================
const TextStyle titleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: Colors.black87,
);

const TextStyle subtitleStyle = TextStyle(
  fontSize: 16,
  color: Colors.black54,
);

const TextStyle buttonTextStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

// ==================== BUTTON STYLE ====================
final ButtonStyle elevatedButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white,
  shadowColor: Colors.black26,
  elevation: 8,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  padding: const EdgeInsets.symmetric(vertical: 16),
);

// ==================== THỜI GIAN ANIMATION ====================
const Duration animationDuration = Duration(milliseconds: 300);
