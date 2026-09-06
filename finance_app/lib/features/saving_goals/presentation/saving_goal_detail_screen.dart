import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/saving_contribution_model.dart';
import '../domain/saving_goal_model.dart';
import 'add_contribution_screen.dart';
import 'saving_goal_form_screen.dart';
import 'saving_goal_provider.dart';

/// Shows the full detail of one saving goal: progress, note, and contributions.
///
/// Watches [goalByIdProvider] in real time — if the goal is deleted from the
/// edit form, this screen auto-pops back to the goals list.
class SavingGoalDetailScreen extends ConsumerWidget {
  const SavingGoalDetailScreen({
    super.key,
    required this.goalId,
    required this.initialGoal,
  });

  final String goalId;

  /// Used as the initial display while the stream loads to avoid a flicker.
  final SavingGoalModel initialGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalByIdProvider(goalId));
    final contributionsAsync = ref.watch(contributionsProvider(goalId));
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ??
            'MYR';

    // Use the latest stream value, falling back to the initial data.
    final goal = goalAsync.asData?.value ?? initialGoal;

    // Auto-pop when the goal is deleted
    if (goalAsync.asData != null && goalAsync.asData!.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit goal',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    SavingGoalFormScreen(existingGoal: goal),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // ── Progress card ────────────────────────────────────────────────
          _ProgressCard(goal: goal, currency: currency),
          const SizedBox(height: 16),

          // ── Note ────────────────────────────────────────────────────────
          if (goal.note.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(goal.note,
                        style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Contributions section ────────────────────────────────────────
          SectionHeader(
            title: 'Contributions',
            actionLabel: 'Add',
            onAction: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AddContributionScreen(goalId: goalId),
              ),
            ),
          ),
          const SizedBox(height: 8),

          contributionsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load contributions',
                style: AppTextStyles.bodyMedium),
            data: (contributions) => contributions.isEmpty
                ? EmptyState(
                    title: 'No contributions yet',
                    subtitle: 'Tap Add to record your first deposit.',
                    icon: Icons.savings_outlined,
                  )
                : Column(
                    children: contributions
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ContributionTile(
                              contribution: c,
                              currency: currency,
                              onDelete: () =>
                                  _confirmDeleteContribution(
                                      context, ref, c),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AddContributionScreen(goalId: goalId),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Contribution'),
        backgroundColor: AppColors.income,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _confirmDeleteContribution(
    BuildContext context,
    WidgetRef ref,
    SavingContributionModel contribution,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: Text(
          'Remove this contribution of '
          '${contribution.amount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uid =
                  ref.read(authStateChangesProvider).asData?.value?.uid;
              if (uid == null) return;
              try {
                await ref
                    .read(savingGoalServiceProvider)
                    .deleteContribution(
                        uid, goalId, contribution.contributionId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Progress card ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.goal, required this.currency});

  final SavingGoalModel goal;
  final String currency;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Color get _color => goal.isCompleted ? AppColors.income : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final d = goal.targetDate;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Completion badge
          if (goal.isCompleted)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.income.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.income, size: 16),
                  const SizedBox(width: 6),
                  Text('Goal Achieved!',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.income)),
                ],
              ),
            ),

          // Saved amount vs target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved', style: AppTextStyles.labelLarge),
                  Text(
                    '$currency ${goal.savedAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.amountMedium
                        .copyWith(color: _color),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Target', style: AppTextStyles.labelLarge),
                  Text(
                    '$currency ${goal.targetAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.amountMedium
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar + percent
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.clampedPercent,
                    backgroundColor:
                        _color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(_color),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                goal.percentLabel,
                style: AppTextStyles.titleMedium.copyWith(color: _color),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Remaining + deadline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.isCompleted
                    ? 'Fully funded!'
                    : 'Still needed: $currency '
                        '${goal.remainingAmount.toStringAsFixed(2)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color:
                      goal.isCompleted ? AppColors.income : AppColors.textSecondary,
                  fontWeight: goal.isCompleted
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              Text(
                'By ${d.day} ${_months[d.month]} ${d.year}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Contribution tile ─────────────────────────────────────────────────────────

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({
    required this.contribution,
    required this.currency,
    required this.onDelete,
  });

  final SavingContributionModel contribution;
  final String currency;
  final VoidCallback onDelete;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final d = contribution.date;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 18,
              color: AppColors.income,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contribution.note.isNotEmpty
                      ? contribution.note
                      : 'Contribution',
                  style: AppTextStyles.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${d.day} ${_months[d.month]} ${d.year}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$currency ${contribution.amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.income),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.expense,
            tooltip: 'Delete contribution',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
