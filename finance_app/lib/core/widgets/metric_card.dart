import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'fintech_card.dart';

/// A [FintechCard] variant for displaying a single labelled KPI metric.
///
/// Layout:
/// ```
/// ┌──────────────────────────────────────┐
/// │ [icon bg]  title                     │
/// │            value (large text)        │
/// │            subtitle  trend           │
/// └──────────────────────────────────────┘
/// ```
///
/// The widget is entirely passive — it displays whatever strings are passed
/// and does not read from providers or perform calculations.
///
/// Example:
/// ```dart
/// MetricCard(
///   icon: Icons.arrow_upward_rounded,
///   iconColor: AppColors.success,
///   title: 'Income',
///   valueWidget: MoneyText(amount: 4200, currency: 'MYR', variant: MoneyVariant.large),
///   subtitle: 'this month',
/// )
///
/// MetricCard(
///   icon: Icons.receipt_long_rounded,
///   title: 'Transactions',
///   value: '42',
///   subtitle: 'this month',
///   trend: '+8 vs last month',
///   trendColor: AppColors.success,
/// )
/// ```
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.valueWidget,
    this.subtitle,
    this.trend,
    this.trendColor,
    this.iconColor,
    this.iconBgColor,
    this.padding,
    this.onTap,
  }) : assert(
          value != null || valueWidget != null,
          'Provide either value or valueWidget.',
        );

  /// Icon shown in the coloured container on the left.
  final IconData icon;

  /// Label above the value (e.g. "Income", "Total Expense").
  final String title;

  /// Primary value as plain text. Ignored when [valueWidget] is provided.
  final String? value;

  /// Custom widget for the primary value area.
  /// Takes precedence over [value] when both are supplied.
  /// Ideal for [MoneyText] with sign colouring.
  final Widget? valueWidget;

  /// Secondary line below the value (e.g. "this month", "vs budget").
  final String? subtitle;

  /// Optional trend or status label (e.g. "+12% vs last month").
  final String? trend;

  /// Colour applied to [trend] text. Defaults to [AppColors.textSecondary].
  final Color? trendColor;

  /// Icon foreground colour. Defaults to [AppColors.primary].
  final Color? iconColor;

  /// Icon container background. Defaults to a 12 % tint of [iconColor].
  final Color? iconBgColor;

  /// Override inner padding. Defaults to [AppSpacing.xl] all sides.
  final EdgeInsetsGeometry? padding;

  /// Optional tap handler. Wraps the card in a [GestureDetector] when set.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AppColors.primary;
    final resolvedIconBg =
        iconBgColor ?? resolvedIconColor.withValues(alpha: 0.12);

    Widget card = FintechCard(
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon ──────────────────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resolvedIconBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: resolvedIconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          // ── Text column ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: AppTypography.label.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                // Value
                if (valueWidget != null)
                  valueWidget!
                else
                  Text(
                    value!,
                    style: AppTypography.title.copyWith(
                        color: Theme.of(context).colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (trend != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    trend!,
                    style: AppTypography.caption.copyWith(
                      color: trendColor ??
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
