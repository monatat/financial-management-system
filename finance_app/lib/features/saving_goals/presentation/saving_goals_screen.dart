import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/saving_goal_model.dart';
import 'saving_goal_detail_screen.dart';
import 'saving_goal_form_screen.dart';
import 'saving_goal_provider.dart';

class SavingGoalsScreen extends ConsumerWidget {
  const SavingGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ??
            'MYR';

    return Scaffold(
      appBar: AppBar(title: const Text('Saving Goals')),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load goals',
              style: AppTextStyles.bodyMedium),
        ),
        data: (goals) => ResponsiveContent(child: Column(
          children: [
            _SummaryRow(goals: goals, currency: currency),
            const Divider(height: 1),
            Expanded(
              child: goals.isEmpty
                  ? EmptyState(
                      title: 'No saving goals yet',
                      subtitle: 'Tap + to create your first saving goal.',
                      icon: Icons.savings_rounded,
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: goals.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) => _GoalCard(
                        goal: goals[i],
                        currency: currency,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => SavingGoalDetailScreen(
                              goalId: goals[i].goalId,
                              initialGoal: goals[i],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
              builder: (_) => const SavingGoalFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Goal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.goals, required this.currency});

  final List<SavingGoalModel> goals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final totalTarget =
        goals.fold<double>(0.0, (t, g) => t + g.targetAmount);
    final totalSaved =
        goals.fold<double>(0.0, (t, g) => t + g.savedAmount);
    final overallPercent =
        totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SummaryChip(
                label: 'Total Target',
                value: '$currency ${totalTarget.toStringAsFixed(2)}',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Total Saved',
                value: '$currency ${totalSaved.toStringAsFixed(2)}',
                color: AppColors.income,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Overall Progress',
                style: AppTextStyles.labelLarge
                    .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${(overallPercent * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: overallPercent,
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? _chipDarkBg(color) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? _chipDarkBorder(color)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary chip dark-mode helpers ───────────────────────────────────────────

Color _chipDarkBg(Color color) {
  if (color == AppColors.success) return const Color(0xFF10261A);
  if (color == AppColors.danger) return const Color(0xFF2A1515);
  if (color == AppColors.primary) return const Color(0xFF15213B);
  if (color == AppColors.warning) return const Color(0xFF271F0A);
  return color.withValues(alpha: 0.12);
}

Color _chipDarkBorder(Color color) {
  if (color == AppColors.success) return const Color(0xFF22C55E);
  if (color == AppColors.danger) return const Color(0xFFEF4444);
  if (color == AppColors.primary) return const Color(0xFF60A5FA);
  if (color == AppColors.warning) return const Color(0xFFF59E0B);
  return color;
}

// ── Goal card ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currency,
    required this.onTap,
  });

  final SavingGoalModel goal;
  final String currency;
  final VoidCallback onTap;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month]} ${d.year}';

  Color get _progressColor {
    if (goal.isCompleted) return AppColors.income;
    if (goal.clampedPercent >= 0.75) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _progressColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      goal.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.savings_rounded,
                      color: _progressColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.title,
                            style: AppTextStyles.titleMedium),
                        Text(
                          'Target: $currency '
                          '${goal.targetAmount.toStringAsFixed(2)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (goal.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                AppColors.income.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Completed',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.income),
                      ),
                    )
                  else
                    Text(
                      goal.percentLabel,
                      style: AppTextStyles.titleMedium
                          .copyWith(color: _progressColor),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Progress bar ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.clampedPercent,
                  backgroundColor:
                      _progressColor.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_progressColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),

              // ── Saved / Remaining row ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved: $currency '
                    '${goal.savedAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    goal.isCompleted
                        ? 'Goal achieved!'
                        : 'Left: $currency '
                            '${goal.remainingAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: goal.isCompleted
                          ? AppColors.income
                          : AppColors.textSecondary,
                      fontWeight: goal.isCompleted
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Target date ──────────────────────────────────────────────
              Text(
                'Target date: ${_fmtDate(goal.targetDate)}',
                style:
                    AppTextStyles.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
