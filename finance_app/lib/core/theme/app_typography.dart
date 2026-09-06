import 'package:flutter/material.dart';

/// Typography scale for the app.
///
/// Styles are organised by semantic role rather than size so that call-sites
/// communicate intent ("this is a heading") rather than a raw pixel size.
///
/// Role map:
///   [display]  — hero numbers, large KPI values (28 sp, bold)
///   [title]    — screen / section titles (22 sp, semibold)
///   [heading]  — card and subsection headers (18 sp, semibold)
///   [body]     — standard reading text (15 sp, regular)
///   [label]    — form labels, tags, nav items (13 sp, medium)
///   [caption]  — timestamps, hints, secondary metadata (12 sp, regular)
///   [money]    — monetary amounts with tabular figures (16 sp, semibold)
///
/// The [money] style sets [FontFeature.tabularFigures] so that digits always
/// occupy equal horizontal space — essential for aligned currency columns.
abstract final class AppTypography {
  // ── Display ──────────────────────────────────────────────────────────────

  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // ── Title ─────────────────────────────────────────────────────────────────

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  // ── Heading ───────────────────────────────────────────────────────────────

  static const TextStyle heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  // ── Body ──────────────────────────────────────────────────────────────────

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  // ── Label ─────────────────────────────────────────────────────────────────

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ── Caption ───────────────────────────────────────────────────────────────

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.4,
  );

  // ── Money ─────────────────────────────────────────────────────────────────

  /// Monetary amount style.
  ///
  /// Uses [FontFeature.tabularFigures] ('tnum') so that every digit occupies
  /// the same advance width — keeps currency columns aligned without manual
  /// padding regardless of the number of digits displayed.
  static const TextStyle money = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── Money variants ────────────────────────────────────────────────────────

  /// Larger money style for KPI cards and dashboard totals.
  static const TextStyle moneyLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Smaller money style for list rows and secondary amounts.
  static const TextStyle moneySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
