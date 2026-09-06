/// Screen-size breakpoints and derived constants for the responsive system.
///
/// Breakpoints align with common device classes:
///   Mobile   0 – 599 px
///   Tablet   600 – 1023 px
///   Desktop  1024 – 1439 px
///   Large    1440+ px
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  // ── Content layout breakpoints ─────────────────────────────────────────────
  static const double tablet = 600;
  static const double desktop = 1024;
  static const double largeDesktop = 1440;

  // ── Navigation shell breakpoints ───────────────────────────────────────────
  // These control ONLY the navigation chrome (bottom bar vs side rail).
  // They are intentionally wider than the content breakpoints so the side
  // rail never squeezes content on tablet-sized laptop windows.

  /// Below this width the app uses bottom navigation.
  /// At or above it the compact side rail is shown.
  static const double navMobileBreakpoint = 900;

  /// At or above this width the side rail switches to extended mode
  /// (icon + label in one row).
  static const double navExtendedBreakpoint = 1200;

  // ── Content max-widths ─────────────────────────────────────────────────────
  /// Tablets: content is centred within this width.
  static const double contentMaxWidthTablet = 900;

  /// Desktops: primary content column stays within this width.
  static const double contentMaxWidthDesktop = 1200;

  /// Large monitors: extra whitespace is acceptable, content no wider than this.
  static const double contentMaxWidthLargeDesktop = 1400;

  // ── Form max-widths ────────────────────────────────────────────────────────
  /// Auth / add-item forms on mobile (effectively unconstrained below 480 px).
  static const double formMaxWidthMobile = 480;

  /// Forms on tablet feel comfortable at this width.
  static const double formMaxWidthTablet = 560;

  /// Forms on desktop — wider than this looks like a spreadsheet, not a form.
  static const double formMaxWidthDesktop = 620;

  // ── Padding values ─────────────────────────────────────────────────────────
  static const double paddingMobile = 16;
  static const double paddingTablet = 24;
  static const double paddingDesktop = 32;

  // ── Grid columns ──────────────────────────────────────────────────────────
  static const int gridColsMobile = 1;
  static const int gridColsTablet = 2;
  static const int gridColsDesktop = 3;
  static const int gridColsLargeDesktop = 4;
}
