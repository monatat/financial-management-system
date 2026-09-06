/// Spacing scale for the app.
///
/// Use these constants everywhere a distance, gap, or padding value is needed
/// so that spacing remains consistent and easy to adjust globally.
///
/// Scale (dp):
///   xs   =  4  — hairline gap, icon-to-label nudge
///   sm   =  8  — tight spacing inside cards
///   md   = 12  — default intra-section gap
///   lg   = 16  — standard edge padding, between list items
///   xl   = 24  — section gap, card padding
///   xxl  = 32  — page padding on tablet+
///   xxxl = 40  — large screen section separator
abstract final class AppSpacing {
  static const double xs   =  4;
  static const double sm   =  8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 40;
}
