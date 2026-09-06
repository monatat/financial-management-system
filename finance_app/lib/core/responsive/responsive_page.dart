import 'package:flutter/material.dart';
import 'responsive_helpers.dart';

/// Centres and constrains a page's content to [responsiveMaxWidth].
///
/// Drop this inside a [Scaffold.body] for any screen whose content should not
/// stretch to the full display width on large monitors.
///
/// ```dart
/// Scaffold(
///   body: ResponsivePage(
///     child: ListView(children: [...]),
///   ),
/// )
/// ```
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.applyPadding = true,
  });

  final Widget child;

  /// Override the default [responsivePadding] if needed.
  final EdgeInsetsGeometry? padding;

  /// Override the default [responsiveMaxWidth] if needed.
  final double? maxWidth;

  /// Set to false when the child already handles its own padding.
  final bool applyPadding;

  @override
  Widget build(BuildContext context) {
    final effectiveMax = maxWidth ?? context.responsiveMaxWidth;
    final effectivePad = applyPadding
        ? (padding ?? context.responsivePadding)
        : EdgeInsets.zero;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMax),
        child: Padding(
          padding: effectivePad,
          child: child,
        ),
      ),
    );
  }
}

/// Centres and constrains a page body that contains [Column] with [Expanded]
/// children (e.g. a summary row above an [Expanded] list).
///
/// Unlike [ResponsivePage] (which uses [Center] and may collapse bounded
/// height), this widget uses [Align] so the [Scaffold] body's full height is
/// passed through to the inner [Column]'s [Expanded] children.
///
/// On mobile ([responsiveMaxWidth] == infinity) the widget is a no-op and
/// returns [child] directly.
///
/// ```dart
/// Scaffold(
///   body: ResponsiveContent(
///     child: Column(children: [
///       _SummaryRow(),
///       const Divider(height: 1),
///       Expanded(child: ListView(...)),
///     ]),
///   ),
/// )
/// ```
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxW = context.responsiveMaxWidth;
    if (maxW == double.infinity) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}

/// Centres an auth/add-item form within [responsiveFormMaxWidth].
///
/// On mobile the form fills the screen; on tablet/desktop it appears as a
/// centred panel — preventing forms from stretching across wide monitors.
///
/// ```dart
/// Scaffold(
///   body: SafeArea(
///     child: ResponsiveForm(
///       child: SingleChildScrollView(child: formBody),
///     ),
///   ),
/// )
/// ```
class ResponsiveForm extends StatelessWidget {
  const ResponsiveForm({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;

  /// Override the default padding. Pass [EdgeInsets.zero] to opt out.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.responsiveFormMaxWidth),
        child: Padding(
          padding: padding ?? context.responsivePadding,
          child: child,
        ),
      ),
    );
  }
}
