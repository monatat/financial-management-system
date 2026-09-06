import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Base card surface for the FinTech design system.
///
/// Combines [AppColors.surface] background, [AppRadius.lgAll] corners,
/// [AppShadows.soft] elevation, and a [AppColors.border] outline into one
/// reusable container.
///
/// Use [FintechCard] directly for custom content, or build higher-level
/// components ([MetricCard], [ProgressSummaryCard]) on top of it.
///
/// Example:
/// ```dart
/// FintechCard(
///   child: Text('Hello'),
/// )
///
/// FintechCard(
///   padding: EdgeInsets.all(AppSpacing.lg),
///   child: MyCustomContent(),
/// )
/// ```
class FintechCard extends StatelessWidget {
  const FintechCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
  });

  final Widget child;

  /// Inner padding. Defaults to [EdgeInsets.all(AppSpacing.xl)] (24 dp).
  final EdgeInsetsGeometry? padding;

  /// Outer margin. Defaults to none.
  final EdgeInsetsGeometry? margin;

  /// Background colour. Defaults to [AppColors.surface].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}
