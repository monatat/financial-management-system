import 'package:flutter/material.dart';

/// Elevation shadow tokens for the app.
///
/// Two tiers to cover the common card hierarchy:
///
///   [soft]   — resting cards, list items, subtle lift (1 dp equivalent)
///   [medium] — hovered / focused cards, modals, more visible depth (3 dp)
///
/// Both are designed for light-mode surfaces.  For dark mode, consider
/// reducing opacity further rather than changing blur/offset.
abstract final class AppShadows {
  // ── Soft — subtle lift for standard cards ────────────────────────────────

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0A000000), // 4 % black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // ── Medium — more visible depth for focused / floating surfaces ──────────

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x0A000000), // 4 % black — ambient layer
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x14000000), // 8 % black — key-light layer
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}
