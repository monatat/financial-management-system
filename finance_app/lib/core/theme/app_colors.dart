import 'package:flutter/material.dart';

/// Centralised colour tokens for the app.
///
/// Semantic groups:
///   Brand      — [primary], [primaryDark], [primaryLight]
///   Status     — [success], [danger], [warning], [info]
///   Surfaces   — [background], [surface], [surfaceVariant]
///   Text       — [textPrimary], [textSecondary], [textDisabled], [textOnPrimary]
///   Border     — [border]
///   Dark theme — dark* variants
///   Categories — cat* palette
///
/// Compatibility aliases kept for existing screens (migrate gradually):
///   [income]  → [success]    (was #10B981, now #16A34A)
///   [expense] → [danger]     (was #EF4444, now #DC2626)
///   [accent] family retained unchanged — no new-token equivalent
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────

  static const Color primary      = Color(0xFF2F5BEA);
  static const Color primaryDark  = Color(0xFF1E3FB0);
  static const Color primaryLight = Color(0xFF93C5FD);

  // ── Status ─────────────────────────────────────────────────────────────────

  static const Color success = Color(0xFF16A34A);
  static const Color danger  = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info    = Color(0xFF3B82F6);

  // ── Surfaces ───────────────────────────────────────────────────────────────

  static const Color background     = Color(0xFFF6F7F9);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);

  // ── Text ───────────────────────────────────────────────────────────────────

  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textDisabled  = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Border ─────────────────────────────────────────────────────────────────

  static const Color border = Color(0xFFE2E8F0);

  // ── Dark theme ─────────────────────────────────────────────────────────────

  static const Color darkBackground     = Color(0xFF111827);
  static const Color darkSurface        = Color(0xFF1F2937);
  static const Color darkSurfaceVariant = Color(0xFF374151);
  static const Color darkBorder         = Color(0xFF374151);
  static const Color darkTextPrimary    = Color(0xFFF9FAFB);
  static const Color darkTextSecondary  = Color(0xFF9CA3AF);

  // ── Compatibility aliases ──────────────────────────────────────────────────
  // Old semantic names kept so existing screens compile without changes.
  // New screens should use [success] and [danger] directly.

  /// @deprecated Use [success] instead.
  static const Color income = success;

  /// @deprecated Use [danger] instead.
  static const Color expense = danger;

  // Accent family has no direct new-token equivalent; retained as-is.
  static const Color accent      = Color(0xFF10B981);
  static const Color accentLight = Color(0xFF6EE7B7);
  static const Color accentDark  = Color(0xFF059669);

  // ── Category palette ───────────────────────────────────────────────────────

  static const Color catSubscription  = Color(0xFF8B5CF6);
  static const Color catFood          = Color(0xFFF59E0B);
  static const Color catEntertainment = Color(0xFFEC4899);
  static const Color catShopping      = Color(0xFF3B82F6);
  static const Color catTransport     = Color(0xFF10B981);
  static const Color catUtilities     = Color(0xFF6366F1);
  static const Color catHealth        = Color(0xFFEF4444);
  static const Color catEducation     = Color(0xFF0EA5E9);
  static const Color catRent          = Color(0xFF64748B);
  static const Color catOther         = Color(0xFF9CA3AF);
}
