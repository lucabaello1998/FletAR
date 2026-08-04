import 'package:flutter/material.dart';

/// Tokens semánticos de color. Los widgets usan estos nombres, nunca un
/// naranja/azul escrito a mano — ver "Identidad visual" en el CLAUDE.md raíz.
abstract final class FletarColors {
  static const background = Color(0xFFFAFAF8);
  static const surface = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF1E2530);
  static const mutedForeground = Color(0xFF6B7280);
  static const primary = Color(0xFFF97316);
  static const secondary = Color(0xFF1E3A5F);
  static const border = Color(0xFFE5E1DA);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const destructive = Color(0xFFEF4444);
}
