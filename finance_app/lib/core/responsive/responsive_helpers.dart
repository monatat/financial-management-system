import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Convenient responsive properties available on any [BuildContext].
///
/// Usage:
/// ```dart
/// if (context.isMobile) { ... }
/// double maxW = context.responsiveMaxWidth;
/// int cols  = context.responsiveGridCount;
/// ```
extension ResponsiveHelpers on BuildContext {
  // ── Screen dimensions ──────────────────────────────────────────────────────

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  // ── Device class ───────────────────────────────────────────────────────────

  bool get isMobile => screenWidth < ResponsiveBreakpoints.tablet;

  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.tablet &&
      screenWidth < ResponsiveBreakpoints.desktop;

  bool get isDesktop =>
      screenWidth >= ResponsiveBreakpoints.desktop &&
      screenWidth < ResponsiveBreakpoints.largeDesktop;

  bool get isLargeDesktop => screenWidth >= ResponsiveBreakpoints.largeDesktop;

  /// True on tablet OR desktop (i.e. NOT a phone).
  bool get isTabletOrLarger => screenWidth >= ResponsiveBreakpoints.tablet;

  // ── Orientation ────────────────────────────────────────────────────────────

  bool get isPortrait =>
      MediaQuery.orientationOf(this) == Orientation.portrait;

  bool get isLandscape => !isPortrait;

  // ── Content width constraints ──────────────────────────────────────────────

  /// Maximum width for main page content.
  /// Mobile: unconstrained.  Tablet: 900.  Desktop: 1200.  Large: 1400.
  double get responsiveMaxWidth {
    if (isLargeDesktop) return ResponsiveBreakpoints.contentMaxWidthLargeDesktop;
    if (isDesktop) return ResponsiveBreakpoints.contentMaxWidthDesktop;
    if (isTablet) return ResponsiveBreakpoints.contentMaxWidthTablet;
    return double.infinity; // mobile — full width
  }

  /// Maximum width for auth/add-item forms.
  /// Prevents forms from stretching across wide screens.
  double get responsiveFormMaxWidth {
    if (isTabletOrLarger && screenWidth >= ResponsiveBreakpoints.desktop) {
      return ResponsiveBreakpoints.formMaxWidthDesktop;
    }
    if (isTablet) return ResponsiveBreakpoints.formMaxWidthTablet;
    return ResponsiveBreakpoints.formMaxWidthMobile;
  }

  // ── Spacing / padding ──────────────────────────────────────────────────────

  /// Symmetric horizontal + vertical page padding that grows with screen size.
  EdgeInsets get responsivePadding {
    if (isDesktop || isLargeDesktop) {
      return const EdgeInsets.all(ResponsiveBreakpoints.paddingDesktop);
    }
    if (isTablet) {
      return const EdgeInsets.all(ResponsiveBreakpoints.paddingTablet);
    }
    return const EdgeInsets.all(ResponsiveBreakpoints.paddingMobile);
  }

  /// Scalar value of the current padding (useful for manual calculations).
  double get responsivePaddingValue {
    if (isDesktop || isLargeDesktop) return ResponsiveBreakpoints.paddingDesktop;
    if (isTablet) return ResponsiveBreakpoints.paddingTablet;
    return ResponsiveBreakpoints.paddingMobile;
  }

  // ── Grid columns ──────────────────────────────────────────────────────────

  /// Number of grid columns appropriate for the current screen size.
  /// Also returns 2 for phone landscape to utilise the extra width.
  int get responsiveGridCount {
    if (isLargeDesktop) return ResponsiveBreakpoints.gridColsLargeDesktop;
    if (isDesktop) return ResponsiveBreakpoints.gridColsDesktop;
    if (isTablet) return ResponsiveBreakpoints.gridColsTablet;
    if (isLandscape) return 2; // phone landscape — squeeze in 2 columns
    return ResponsiveBreakpoints.gridColsMobile;
  }

  /// Cross-axis count for GridView widgets.
  int get responsiveCrossAxisCount {
    if (isDesktop || isLargeDesktop) return 3;
    if (isTablet) return 2;
    return 2;
  }

  // ── Convenience shortcuts ──────────────────────────────────────────────────

  /// Horizontal padding only, suitable for list/scroll views.
  EdgeInsets get responsiveHorizontalPadding => EdgeInsets.symmetric(
        horizontal: responsivePaddingValue,
      );

  // ── Content centering helper ───────────────────────────────────────────────

  /// Horizontal padding for list/content pages (not forms).
  ///
  /// Centers content at [responsiveMaxWidth] on wide screens.
  /// Returns base padding when the screen is narrower than the threshold.
  ///
  /// Math identical to [formHorizontalPadding] but uses the wider
  /// [responsiveMaxWidth] so list cards and summary rows stay comfortably wide.
  double get contentHorizontalPadding {
    final maxW = responsiveMaxWidth;
    final base = responsivePaddingValue;
    if (maxW == double.infinity) return base; // mobile — no centering
    if (screenWidth <= maxW + 2 * base) return base;
    return (screenWidth - maxW) / 2;
  }

  // ── Form centering helper ──────────────────────────────────────────────────

  /// Horizontal padding for a [ListView]-based form body.
  ///
  /// On screens narrow enough to fill with the form, returns the normal base
  /// padding (form fills the screen with gutters).
  /// On wider screens, returns enough padding on each side so the form content
  /// is visually centred at [responsiveFormMaxWidth].
  ///
  /// Math:
  ///   If screen ≤ formMax + 2*basePad → full-width mode → return basePad
  ///   Otherwise                       → centred mode   → return (screen - formMax) / 2
  ///
  /// Verification:
  ///   375px phone   → 375 ≤ 480+32=512 → return 16 → content = 343px (full) ✓
  ///   768px tablet  → 768 > 560+48=608 → return (768-560)/2=104 → content = 560px ✓
  ///   1366px desktop→ 1366 > 620+64=684→ return (1366-620)/2=373 → content = 620px ✓
  ///   1920px large  → 1920 > 620+64=684→ return (1920-620)/2=650 → content = 620px ✓
  double get formHorizontalPadding {
    final maxW = responsiveFormMaxWidth;
    final base = responsivePaddingValue;
    if (screenWidth <= maxW + 2 * base) return base;
    return (screenWidth - maxW) / 2;
  }

  /// Vertical padding for a [ListView]-based form body.
  ///
  /// On mobile landscape the screen is only ~375 px tall — cutting the
  /// vertical padding to 8 px buys enough room to see the first field
  /// and start scrolling without overflow.
  double formVerticalPadding({double portraitValue = 20}) =>
      isMobile && isLandscape ? 8.0 : portraitValue;

  // ── App-form width helpers ─────────────────────────────────────────────────

  /// Maximum width for financial entry forms (transactions, budgets, goals,
  /// debts). Wider than [responsiveFormMaxWidth] so app forms feel like real
  /// pages rather than narrow auth dialogs.
  ///
  ///   < 600 px     → full width (mobile)
  ///   600–899 px   → 700 px  (tablet)
  ///   900–1199 px  → 820 px  (compact web rail)
  ///   1200–1439 px → 900 px  (extended rail / desktop)
  ///   ≥ 1440 px    → 1000 px (large desktop)
  double get responsiveAppFormMaxWidth {
    final w = screenWidth;
    if (w >= ResponsiveBreakpoints.largeDesktop) return 1000;
    if (w >= ResponsiveBreakpoints.navExtendedBreakpoint) return 900;
    if (w >= ResponsiveBreakpoints.navMobileBreakpoint) return 820;
    if (w >= ResponsiveBreakpoints.tablet) return 700;
    return double.infinity;
  }

  /// Maximum width for the export builder screen.
  ///
  ///   < 600 px     → full width (mobile)
  ///   600–899 px   → 760 px
  ///   900–1199 px  → 900 px
  ///   1200–1439 px → 1100 px
  ///   ≥ 1440 px    → 1200 px
  double get responsiveExportMaxWidth {
    final w = screenWidth;
    if (w >= ResponsiveBreakpoints.largeDesktop) return 1200;
    if (w >= ResponsiveBreakpoints.navExtendedBreakpoint) return 1100;
    if (w >= ResponsiveBreakpoints.navMobileBreakpoint) return 900;
    if (w >= ResponsiveBreakpoints.tablet) return 760;
    return double.infinity;
  }

  /// Horizontal padding for financial entry forms.
  ///
  /// Same math as [formHorizontalPadding] but centred at [responsiveAppFormMaxWidth].
  double get appFormHorizontalPadding {
    final maxW = responsiveAppFormMaxWidth;
    final base = responsivePaddingValue;
    if (maxW == double.infinity) return base;
    if (screenWidth <= maxW + 2 * base) return base;
    return (screenWidth - maxW) / 2;
  }
}
