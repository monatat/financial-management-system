import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../categories/domain/category_model.dart';
import '../../categories/domain/description_preset_model.dart';
import '../../categories/presentation/category_provider.dart';
import '../domain/transaction_model.dart';
import 'transaction_provider.dart';

/// Screen for adding a new transaction or editing an existing one.
///
/// Pass [existingTransaction] = null to create a new transaction.
/// Pass an existing [TransactionModel] to edit it.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existingTransaction});

  final TransactionModel? existingTransaction;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'expense';
  String? _selectedCategoryId;
  List<DescriptionPresetModel> _presets = [];
  DateTime _selectedDate = DateTime.now();
  String _currency = AppStrings.defaultCurrency;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingTransaction != null;

  String get _monthString =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';

  static const _shortMonths = [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();

    // Pre-fill form when editing
    final tx = widget.existingTransaction;
    if (tx != null) {
      _type = tx.type;
      _selectedCategoryId = tx.categoryId;
      _amountController.text = tx.amount.toStringAsFixed(2);
      _descriptionController.text = tx.description;
      _noteController.text = tx.note;
      _selectedDate = tx.date;
      _currency = tx.currency;
    }

    // Load user currency and (in edit mode) presets — after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserCurrency();
      if (_isEditing && _selectedCategoryId != null) {
        _loadPresetsForId(_selectedCategoryId!, clearDescription: false);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Data loaders ───────────────────────────────────────────────────────────

  Future<void> _loadUserCurrency() async {
    final profile = await ref.read(currentUserProfileProvider.future);
    if (mounted && profile != null) {
      setState(() => _currency = profile.currency);
    }
  }

  Future<void> _loadPresetsForId(
    String categoryId, {
    bool clearDescription = true,
  }) async {
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    if (clearDescription && mounted) {
      setState(() => _presets = []);
      _descriptionController.clear();
    }

    try {
      final loaded = await ref
          .read(categoryServiceProvider)
          .getDescriptionPresets(uid, categoryId)
          .first;
      if (mounted) setState(() => _presets = loaded);
    } catch (_) {
      // Preset loading is best-effort; silently ignore failures
    }
  }

  // ── Event handlers ─────────────────────────────────────────────────────────

  void _onTypeChanged(String newType) {
    if (newType == _type) return;
    setState(() {
      _type = newType;
      _selectedCategoryId = null;
      _presets = [];
    });
    _descriptionController.clear();
  }

  void _onCategoryChanged(String? id) {
    if (id == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = id;
      _presets = [];
    });
    _descriptionController.clear();
    if (id != null) _loadPresetsForId(id);
  }

  void _selectPreset(String label) {
    _descriptionController
      ..text = label
      ..selection =
          TextSelection.fromPosition(TextPosition(offset: label.length));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save(List<CategoryModel> categories) async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    // Defensive guard — router should prevent this, but protect anyway.
    if (_currency.isEmpty) {
      setState(() =>
          _errorMessage = 'Please complete currency setup first.');
      return;
    }

    final category = categories.firstWhere(
      (c) => c.categoryId == _selectedCategoryId,
    );
    final amount = double.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim();
    final note = _noteController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(transactionServiceProvider);

      if (_isEditing) {
        await service.updateTransaction(
          uid,
          widget.existingTransaction!.transactionId,
          {
            'type': _type,
            'amount': amount,
            'categoryId': category.categoryId,
            'categoryName': category.name,
            'description': description,
            'note': note,
            'date': Timestamp.fromDate(_selectedDate),
            'month': _monthString,
            'currency': _currency,
          },
        );
      } else {
        final now = DateTime.now();
        await service.addTransaction(
          uid,
          TransactionModel(
            transactionId: '',
            type: _type,
            amount: amount,
            categoryId: category.categoryId,
            categoryName: category.name,
            description: description,
            note: note,
            date: _selectedDate,
            month: _monthString,
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
              _isEditing ? 'Transaction updated.' : 'Transaction added.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Failed to save transaction. Please try again.');
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
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
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
                await ref.read(transactionServiceProvider).deleteTransaction(
                      uid,
                      widget.existingTransaction!.transactionId,
                    );
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction deleted.')),
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
    final categoriesAsync = _type == 'expense'
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);
    final categories = categoriesAsync.asData?.value ?? const [];

    // Only pass the selectedId to the dropdown when it exists in the current
    // categories list — avoids Flutter assertion errors on empty or type-change
    final validSelectedId = categories
            .any((c) => c.categoryId == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.expense,
              tooltip: 'Delete transaction',
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
            // ── Section 1: Transaction Type ─────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Type',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TypeToggle(
                    selected: _type,
                    onChanged: _isLoading ? null : _onTypeChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 2: Category & Description ──────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category & Description',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Category', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  // ValueKey forces a fresh rebuild when type or category changes,
                  // making initialValue reactive — avoids the deprecated `value` param.
                  DropdownButtonFormField<String>(
                    key: ValueKey('$_type-${validSelectedId ?? 'none'}'),
                    initialValue: validSelectedId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_outlined),
                      hintText: 'Select a category',
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
                    onChanged: _isLoading ? null : _onCategoryChanged,
                    validator: (v) =>
                        v == null ? 'Please select a category.' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Description', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_isLoading,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'What was this for?',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Description is required.';
                      }
                      return null;
                    },
                  ),
                  if (_presets.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Quick select:', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _presets
                          .map(
                            (p) => ActionChip(
                              label: Text(
                                p.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => _selectPreset(p.label),
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.08),
                              side: BorderSide(
                                color: AppColors.primary
                                    .withValues(alpha: 0.40),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 3: Amount & Date ────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount & Date',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Amount', style: AppTextStyles.titleMedium),
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
                  const SizedBox(height: AppSpacing.lg),
                  Text('Date', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isLoading ? null : _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        '${_selectedDate.day} '
                        '${_shortMonths[_selectedDate.month]} '
                        '${_selectedDate.year}',
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
                      hintText: 'Add a note...',
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
              label: _isEditing ? 'Save Changes' : 'Add Transaction',
              onPressed: _isLoading ? null : () => _save(categories),
              isLoading: _isLoading,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ── Type toggle ───────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.selected, this.onChanged});

  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Expense',
          value: 'expense',
          selected: selected,
          color: AppColors.expense,
          onTap: onChanged,
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: 'Income',
          value: 'income',
          selected: selected,
          color: AppColors.income,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final Color color;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.titleMedium.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
          ),
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
          color: AppColors.expense.withValues(alpha: 0.3),
        ),
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
