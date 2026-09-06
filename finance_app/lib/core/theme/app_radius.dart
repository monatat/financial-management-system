import 'package:flutter/material.dart';

/// Border-radius tokens for the app.
///
/// Scalar values and pre-built [BorderRadius] shortcuts:
///   sm →  8 dp  — chips, tags, small badges
///   md → 12 dp  — input fields, secondary cards
///   lg → 16 dp  — primary cards, bottom sheets
///   xl → 20 dp  — dialogs, prominent surfaces
abstract final class AppRadius {
  // ── Scalar values ────────────────────────────────────────────────────────

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  // ── BorderRadius shortcuts ───────────────────────────────────────────────

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}
