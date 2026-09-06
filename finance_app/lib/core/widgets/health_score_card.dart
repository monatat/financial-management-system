import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ── Health score calculator ───────────────────────────────────────────────────

/// Computes a 0–100 financial health score from summarised metrics.
///
/// Four equally weighted factors (25 pts each):
///   • Budget discipline (25 pts) — full score at ≤80% usage; 0 at ≥120%
///   • Savings progress  (25 pts) — linear with overall funding percentage
///   • Debt repayment    (25 pts) — linear with total repaid fraction
///   • Invisible leakage (25 pts) — deducted proportionally to leakage ratio
double calculateHealthScore({
  required double budgetUsagePercent,
  required bool hasBudgets,
  required double savingsProgressPercent,
  required double debtRepaidPercent,
  required bool hasDebts,
  required double invisibleLeakageAmount,
  required double totalIncome,
}) {
  // Budget discipline
  double budgetScore = 25;
  if (hasBudgets) {
    if (budgetUsagePercent <= 0.8) {
      budgetScore = 25;
    } else if (budgetUsagePercent >= 1.2) {
      budgetScore = 0;
    } else {
      budgetScore = 25 * (1 - (budgetUsagePercent - 0.8) / 0.4);
    }
  }

  // Savings progress
  final savingsScore = (savingsProgressPercent * 25).clamp(0.0, 25.0);

  // Debt repayment (full score if no debts)
  final debtScore = hasDebts
      ? (debtRepaidPercent * 25).clamp(0.0, 25.0)
      : 25.0;

  // Invisible leakage (full score if not yet audited)
  double leakageScore = 25;
  if (totalIncome > 0 && invisibleLeakageAmount > 0) {
    final ratio = invisibleLeakageAmount / totalIncome;
    leakageScore = (25 * (1 - ratio * 4)).clamp(0.0, 25.0);
  }

  return (budgetScore + savingsScore + debtScore + leakageScore)
      .clamp(0.0, 100.0);
}

/// Label and colour for a given health score.
({String label, Color color, String emoji}) scoreLevel(double score) {
  if (score >= 80) {
    return (label: 'Excellent', color: AppColors.success, emoji: '🌟');
  }
  if (score >= 60) {
    return (label: 'Good', color: AppColors.primary, emoji: '👍');
  }
  if (score >= 40) {
    return (label: 'Fair', color: AppColors.warning, emoji: '⚠️');
  }
  return (label: 'Needs Attention', color: AppColors.danger, emoji: '❗');
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Displays the financial health score plus optional wellness analytics.
///
/// Pass [totalIncome], [totalExpense], [budgetSpent], [budgetAllocated], and
/// [debtOutstanding] to unlock the three mini-metric tiles (Savings Rate,
/// Budget Utilisation, Debt-to-Income).  When not provided the card shows the
/// score ring and level text only.
class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({
    super.key,
    required this.score,
    this.compact = false,
    this.totalIncome,
    this.totalExpense,
    this.budgetSpent,
    this.budgetAllocated,
    this.debtOutstanding,
  });

  final double score;

  /// Compact mode for use inside a summary row (smaller circle).
  final bool compact;

  // ── Optional analytics inputs ─────────────────────────────────────────────

  /// Current-month income (from dashboard summary).
  final double? totalIncome;

  /// Current-month expense (from dashboard summary).
  final double? totalExpense;

  /// Total budget spent this month.
  final double? budgetSpent;

  /// Total budget allocated this month. Pass 0 / null when no budgets set.
  final double? budgetAllocated;

  /// Total remaining (outstanding) debt across all debts.
  final double? debtOutstanding;

  // ── Computed metrics ──────────────────────────────────────────────────────

  /// Savings Rate = (Income − Expense) / Income × 100.
  double? get _savingsRate {
    if (totalIncome == null || totalExpense == null || totalIncome! <= 0) {
      return null;
    }
    return ((totalIncome! - totalExpense!) / totalIncome!) * 100;
  }

  /// Budget Utilisation = Budget Spent / Budget Allocated × 100.
  double? get _budgetUtil {
    if (budgetSpent == null ||
        budgetAllocated == null ||
        budgetAllocated! <= 0) {
      return null;
    }
    return (budgetSpent! / budgetAllocated!) * 100;
  }

  /// Debt-to-Income = Outstanding Debt / (Monthly Income × 12) × 100.
  double? get _dti {
    if (debtOutstanding == null ||
        totalIncome == null ||
        totalIncome! <= 0) {
      return null;
    }
    if (debtOutstanding! <= 0) return 0;
    return (debtOutstanding! / (totalIncome! * 12)) * 100;
  }

  bool get _hasMetrics =>
      totalIncome != null && totalExpense != null;

  @override
  Widget build(BuildContext context) {
    final level = scoreLevel(score);
    final circleSize = compact ? 72.0 : 96.0;
    final metricsWidget =
        _hasMetrics ? _MetricsRow(sr: _savingsRate, bu: _budgetUtil, dti: _dti) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level.color.withValues(alpha: 0.2)),
      ),
      child: compact
          ? _CompactLayout(
              score: score,
              level: level,
              circleSize: circleSize,
              metrics: metricsWidget,
            )
          : _FullLayout(
              score: score,
              level: level,
              circleSize: circleSize,
              metrics: metricsWidget,
            ),
    );
  }
}

// ── Full layout (web / non-compact) ──────────────────────────────────────────

class _FullLayout extends StatelessWidget {
  const _FullLayout({
    required this.score,
    required this.level,
    required this.circleSize,
    this.metrics,
  });

  final double score;
  final ({String label, Color color, String emoji}) level;
  final double circleSize;
  final Widget? metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Score ring + status text (horizontal) ───────────────────────────
        Row(
          children: [
            _AnimatedCircle(score: score, color: level.color, size: circleSize),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Health', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(level.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      level.label,
                      style: AppTextStyles.headlineMedium
                          .copyWith(color: level.color),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _description(score),
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Analytics metrics (below) ────────────────────────────────────────
        if (metrics != null) ...[
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          metrics!,
        ],
      ],
    );
  }

  String _description(double s) {
    if (s >= 80) return 'Great job! Keep maintaining your habits.';
    if (s >= 60) return 'On track. Small improvements will help.';
    if (s >= 40) return 'Review your budget and savings goals.';
    return 'Attention needed. Focus on budgeting.';
  }
}

// ── Compact layout (mobile) ───────────────────────────────────────────────────

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.score,
    required this.level,
    required this.circleSize,
    this.metrics,
  });

  final double score;
  final ({String label, Color color, String emoji}) level;
  final double circleSize;
  final Widget? metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Score ring + label (horizontal compact row) ──────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Financial Health', style: AppTextStyles.labelLarge),
                const SizedBox(height: 4),
                Text(
                  '${level.emoji} ${level.label}',
                  style: AppTextStyles.titleMedium.copyWith(color: level.color),
                ),
              ],
            ),
            _AnimatedCircle(score: score, color: level.color, size: circleSize),
          ],
        ),

        // ── Analytics metrics (below) ────────────────────────────────────────
        if (metrics != null) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          metrics!,
        ],
      ],
    );
  }
}

// ── Analytics metrics row ─────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.sr,
    required this.bu,
    required this.dti,
  });

  final double? sr;   // Savings Rate %
  final double? bu;   // Budget Utilisation %
  final double? dti;  // Debt-to-Income %

  static Color _srColor(double? v) {
    if (v == null) return AppColors.textDisabled;
    if (v >= 20) return AppColors.success;
    if (v >= 10) return AppColors.primary;
    if (v >= 0) return AppColors.warning;
    return AppColors.danger;
  }

  static Color _buColor(double? v) {
    if (v == null) return AppColors.textDisabled;
    if (v <= 80) return AppColors.success;
    if (v <= 100) return AppColors.warning;
    return AppColors.danger;
  }

  static Color _dtiColor(double? v) {
    if (v == null) return AppColors.textDisabled;
    if (v <= 0) return AppColors.success;
    if (v <= 50) return AppColors.success;
    if (v <= 100) return AppColors.warning;
    return AppColors.danger;
  }

  String _fmt(double? v) =>
      v == null ? '—' : '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Savings Rate',
            value: _fmt(sr),
            color: _srColor(sr),
            progress: sr != null ? (sr! / 100).clamp(0.0, 1.0) : 0,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricTile(
            label: 'Budget Used',
            value: _fmt(bu),
            color: _buColor(bu),
            progress: bu != null ? (bu! / 100).clamp(0.0, 1.0) : 0,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricTile(
            label: 'Debt / Income',
            value: _fmt(dti),
            color: _dtiColor(dti),
            progress: dti != null ? (dti! / 100).clamp(0.0, 1.0) : 0,
          ),
        ),
      ],
    );
  }
}

// ── Mini metric tile ──────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.progress,
  });

  final String label;
  final String value;
  final Color color;
  final double progress; // 0.0–1.0 for the mini bar

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.label.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

// ── Animated circular progress ────────────────────────────────────────────────

class _AnimatedCircle extends StatelessWidget {
  const _AnimatedCircle({
    required this.score,
    required this.color,
    required this.size,
  });

  final double score;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, value, child) => CircularProgressIndicator(
              value: value,
              strokeWidth: size * 0.09,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              score.toInt().toString(),
              style: TextStyle(
                fontSize: size * 0.27,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
            Text(
              'of 100',
              style: TextStyle(
                fontSize: size * 0.1,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
