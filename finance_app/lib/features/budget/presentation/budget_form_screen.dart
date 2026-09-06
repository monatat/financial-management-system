import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/fintech_card.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../categories/presentation/category_provider.dart';
import '../domain/budget_model.dart';
import 'budget_provider.dart';

/// Screen for adding a new category budget or editing an existing one.
///
/// [month] — "YYYY-MM" string for the month being budgeted.
/// [existingBudget] — null when adding, non-null when editing.
///
/// Category dropdown is DISABLED when editing to avoid duplicate budgets.
/// If the user wants to change the category, they should delete this budget
/// and create a new one.
class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({
    super.key,
    required this.month,
    this.existingBudget,
  });

  final String month;
  final BudgetModel? existingBudget;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedCategoryId;
  String _currency = AppStrings.defaultCurrency;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingBudget != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedCategoryId = widget.existingBudget!.categoryId;
      _amountController.text =
          widget.existingBudget!.allocatedAmount.toStringAsFixed(2);
      _currency = widget.existingBudget!.currency;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrency());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    final profile = await ref.read(currentUserProfileProvider.future);
    if (mounted && profile != null && !_isEditing) {
      setState(() => _currency = profile.currency);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save(
    String categoryId,
    String categoryName,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final amount = double.parse(_amountController.text.trim());

    try {
      final service = ref.read(budgetServiceProvider);

      if (_isEditing) {
        await service.updateBudget(
          uid,
          widget.existingBudget!.budgetId,
          {
            'allocatedAmount': amount,
            'categoryName': categoryName,
          },
        );
      } else {
        final now = DateTime.now();
        await service.createBudget(
          uid,
          BudgetModel(
            budgetId: '',
            month: widget.month,
            categoryId: categoryId,
            categoryName: categoryName,
            allocatedAmount: amount,
            currency: _currency,
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
              _isEditing ? 'Budget updated.' : 'Budget created.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = e.toString().replaceAll('Exception: ', ''));
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
        title: const Text('Delete Budget'),
        content: Text(
          'Delete the budget for '
          '"${widget.existingBudget!.categoryName}"?',
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
                await ref.read(budgetServiceProvider).deleteBudget(
                      uid,
                      widget.existingBudget!.budgetId,
                    );
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Budget deleted.')),
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
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final categories = categoriesAsync.asData?.value ?? const [];

    // When editing: show the existing category locked; value must be in items.
    // When adding:  validate selectedId is in the current category list.
    final validSelectedId = categories
            .any((c) => c.categoryId == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    // Resolve category name for save (used when editing, where dropdown is disabled)
    String resolvedCategoryName() {
      if (_isEditing) return widget.existingBudget!.categoryName;
      final cat = categories
          .where((c) => c.categoryId == _selectedCategoryId)
          .firstOrNull;
      return cat?.name ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Budget' : 'New Budget'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.expense,
              tooltip: 'Delete budget',
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
            // ── Section 1: Budgeting Month ──────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Budgeting for',
                          style: AppTypography.label
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(widget.month,
                          style: AppTypography.heading
                              .copyWith(color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 2: Budget Category ──────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Category',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_isEditing)
                    // Locked when editing — shows existing category as plain text
                    InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      child: Row(
                        children: [
                          if (categories.any(
                                  (c) => c.categoryId == _selectedCategoryId)) ...[
                            Icon(
                              materialIconData(categories
                                  .firstWhere((c) =>
                                      c.categoryId == _selectedCategoryId)
                                  .iconCode),
                              size: 18,
                              color: categories
                                  .firstWhere((c) =>
                                      c.categoryId == _selectedCategoryId)
                                  .color,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.existingBudget!.categoryName,
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(locked)',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: ValueKey(validSelectedId ?? 'none'),
                      initialValue: validSelectedId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                        hintText: 'Select expense category',
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.categoryId,
                              child: Row(
                                children: [
                                  Icon(
                                    materialIconData(c.iconCode),
                                    color: c.color,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(c.name),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoading
                          ? null
                          : (id) => setState(() => _selectedCategoryId = id),
                      validator: (v) =>
                          v == null ? 'Please select a category.' : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 3: Monthly Limit ────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Limit',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Budget Amount ($_currency)',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    enabled: !_isLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      hintText: '0.00',
                      prefixText: '$_currency ',
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Amount is required.';
                      final parsed = double.tryParse(s);
                      if (parsed == null) return 'Please enter a valid number.';
                      if (parsed <= 0) return 'Amount must be greater than 0.';
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
              label: _isEditing ? 'Save Changes' : 'Create Budget',
              isLoading: _isLoading,
              onPressed: _isLoading
                  ? null
                  : () {
                      final catId = _isEditing
                          ? widget.existingBudget!.categoryId
                          : _selectedCategoryId;
                      if (catId == null) {
                        _formKey.currentState!.validate();
                        return;
                      }
                      _save(catId, resolvedCategoryName());
                    },
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
