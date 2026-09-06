import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'fintech_card.dart';

/// A [FintechCard] variant for displaying a metric with a progress bar.
///
/// Layout:
/// ```
/// ┌──────────────────────────────────┐
/// │ title                    value   │
/// │ subtitle                         │
/// │ ████████████░░░░░░░░░░░░░░░░░░  │
/// │ status text                      │
/// └──────────────────────────────────┘
/// ```
///
/// The widget is entirely passive — it does not calculate [progress].
/// The caller is responsible for computing the ratio and clamping if needed
/// (values outside 0–1 are clamped to that range internally for the bar).
///
/// Example:
/// ```dart
/// ProgressSummaryCard(
///   title: 'Food Budget',
///   value: 'MYR 380 / 500',
///   subtitle: 'May 2025',
///   progress: 0.76,
///   progressColor: AppColors.warning,
///   statusText: '76 % used',
/// )
///
/// ProgressSummaryCard(
///   title: 'Emergency Fund',
///   value: 'MYR 3,200 / 10,000',
///   progress: 0.32,
///   progressColor: AppColors.success,
///   statusText: '32 % saved',
///   statusColor: AppColors.success,
/// )
/// ```
class ProgressSummaryCard extends StatelessWidget {
  const ProgressSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.progress,
    this.progressColor,
    this.statusText,
    this.statusColor,
    this.padding,
  });

  /// Card header label (e.g. "Food Budget", "Emergency Fund").
  final String title;

  /// Primary value string displayed in the top-right (e.g. "MYR 380 / 500").
  final String value;

  /// Secondary label below [title] (e.g. "May 2025", "Goal deadline: Dec").
  final String? subtitle;

  /// Progress ratio from 0.0 (empty) to 1.0 (full).
  /// Values outside this range are clamped before rendering the bar.
  final double progress;

  /// Fill colour of the progress bar. Defaults to [AppColors.primary].
  final Color? progressColor;

  /// Short status line shown below the bar (e.g. "76 % used", "On track").
  final String? statusText;

  /// Colour for [statusText]. Defaults to [AppColors.textSecondary].
  final Color? statusColor;

  /// Override inner padding. Defaults to [AppSpacing.xl] all sides.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = progressColor ?? AppColors.primary;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return FintechCard(
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Value (right-aligned)
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.heading.copyWith(
                      color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Progress bar ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 6,
              color: resolvedColor,
              backgroundColor: resolvedColor.withValues(alpha: 0.12),
            ),
          ),
          // ── Status text ───────────────────────────────────────────────────
          if (statusText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              statusText!,
              style: AppTypography.caption.copyWith(
                color: statusColor ??
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
