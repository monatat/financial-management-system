import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/fintech_card.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/saving_goal_model.dart';
import 'saving_goal_provider.dart';

/// Screen for adding a new saving goal or editing an existing one.
///
/// Pass [existingGoal] = null to create a new goal.
/// Pass an existing [SavingGoalModel] to edit it.
class SavingGoalFormScreen extends ConsumerStatefulWidget {
  const SavingGoalFormScreen({super.key, this.existingGoal});

  final SavingGoalModel? existingGoal;

  @override
  ConsumerState<SavingGoalFormScreen> createState() =>
      _SavingGoalFormScreenState();
}

class _SavingGoalFormScreenState
    extends ConsumerState<SavingGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingGoal != null;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    if (g != null) {
      _titleController.text = g.title;
      _amountController.text = g.targetAmount.toStringAsFixed(2);
      _noteController.text = g.note;
      _targetDate = g.targetDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2060),
    );
    if (picked != null && mounted) setState(() => _targetDate = picked);
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(savingGoalServiceProvider);

      if (_isEditing) {
        await service.updateGoal(uid, widget.existingGoal!.goalId, {
          'title': _titleController.text.trim(),
          'targetAmount': double.parse(_amountController.text.trim()),
          'targetDate': Timestamp.fromDate(_targetDate),
          'note': _noteController.text.trim(),
        });
      } else {
        final now = DateTime.now();
        await service.createGoal(
          uid,
          SavingGoalModel(
            goalId: '',
            title: _titleController.text.trim(),
            targetAmount:
                double.parse(_amountController.text.trim()),
            savedAmount: 0.0,
            targetDate: _targetDate,
            note: _noteController.text.trim(),
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Goal updated.' : 'Goal created.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Failed to save goal. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text(
          'Delete "${widget.existingGoal!.title}" and all its '
          'contributions? This cannot be undone.',
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

              setState(() => _isLoading = true);
              try {
                await ref
                    .read(savingGoalServiceProvider)
                    .deleteGoal(uid, widget.existingGoal!.goalId);
                if (mounted) {
                  // Pop the form — the detail screen's stream will emit null
                  // and auto-navigate back to the goals list.
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goal deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Delete failed. Please try again.';
                  });
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Goal' : 'New Goal'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.expense,
              tooltip: 'Delete goal',
              onPressed: _isLoading ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.appFormHorizontalPadding,
            vertical: context.formVerticalPadding(),
          ),
          children: [
            // ── Section 1: Goal Details ─────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goal Details',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Goal Title', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    enabled: !_isLoading,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.flag_rounded),
                      hintText: 'e.g. Emergency Fund',
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Title is required.';
                      if (s.length > 50) {
                        return 'Title must be 50 characters or less.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 2: Target Amount ────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Amount',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _amountController,
                    enabled: !_isLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.attach_money_rounded),
                      hintText: '0.00',
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Target amount is required.';
                      final parsed = double.tryParse(s);
                      if (parsed == null) {
                        return 'Please enter a valid number.';
                      }
                      if (parsed <= 0) {
                        return 'Amount must be greater than 0.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 3: Deadline ─────────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deadline',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Target Date', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isLoading ? null : _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        '${_targetDate.day} '
                        '${_months[_targetDate.month]} '
                        '${_targetDate.year}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 4: Notes ────────────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _noteController,
                    enabled: !_isLoading,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                      hintText: 'Why are you saving for this?',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v != null && v.length > 200) {
                        return 'Note must be 200 characters or less.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'Save Changes' : 'Create Goal',
              onPressed: _isLoading ? null : _save,
              isLoading: _isLoading,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.expense.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.expense, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.expense, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
