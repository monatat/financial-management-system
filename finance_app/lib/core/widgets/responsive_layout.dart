import 'package:flutter/material.dart';
import '../responsive/responsive_breakpoints.dart';

/// Navigation shell breakpoint.
///
/// Below this width the app shows bottom navigation (full-width content).
/// At or above it the side navigation rail is shown.
///
/// Set to [ResponsiveBreakpoints.navMobileBreakpoint] (900 px) so that tablet
/// and small laptop windows never have the rail squeezing the main content.
///
/// Kept for backward-compatibility with all call sites that still reference
/// [kWebBreakpoint].
const double kWebBreakpoint = ResponsiveBreakpoints.navMobileBreakpoint; // 900 px

/// Returns true when the current screen width is at or above [kWebBreakpoint].
bool isWebLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWebBreakpoint;

/// Renders [mobile] below [kWebBreakpoint] (bottom nav) and [web] at or above
/// it (side rail).
///
/// The split point (900 px) covers:
///   < 900 px  → [mobile]  (phones AND tablets in portrait AND small laptops)
///   ≥ 900 px  → [web]     (large tablets in landscape, desktops)
///
/// Usage:
/// ```dart
/// ResponsiveLayout(
///   mobile: MobileDashboardScreen(),
///   web: WebDashboardScreen(),
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.web,
  });

  final Widget mobile;
  final Widget web;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kWebBreakpoint) {
          return web;
        }
        return mobile;
      },
    );
  }
}
