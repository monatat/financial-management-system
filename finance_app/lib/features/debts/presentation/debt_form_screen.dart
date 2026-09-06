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
import '../domain/debt_model.dart';
import 'debt_provider.dart';

/// Screen for adding a new debt or editing an existing one.
///
/// PTPTN example: use title "Student Loan / PTPTN".
class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({super.key, this.existingDebt});

  final DebtModel? existingDebt;

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _dueDate =
      DateTime(DateTime.now().year + 5, DateTime.now().month);
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingDebt != null;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.existingDebt;
    if (d != null) {
      _titleController.text = d.title;
      _totalController.text = d.totalAmount.toStringAsFixed(2);
      _monthlyController.text = d.monthlyDue.toStringAsFixed(2);
      _noteController.text = d.note;
      _startDate = d.startDate;
      _dueDate = d.dueDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _monthlyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Date pickers ───────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2060),
    );
    if (p != null && mounted) setState(() => _startDate = p);
  }

  Future<void> _pickDueDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2060),
    );
    if (p != null && mounted) setState(() => _dueDate = p);
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
      final service = ref.read(debtServiceProvider);
      final total = double.parse(_totalController.text.trim());
      final monthly = double.parse(_monthlyController.text.trim());

      if (_isEditing) {
        await service.updateDebt(uid, widget.existingDebt!.debtId, {
          'title': _titleController.text.trim(),
          'totalAmount': total,
          'monthlyDue': monthly,
          'startDate': Timestamp.fromDate(_startDate),
          'dueDate': Timestamp.fromDate(_dueDate),
          'note': _noteController.text.trim(),
        });
      } else {
        final now = DateTime.now();
        await service.createDebt(
          uid,
          DebtModel(
            debtId: '',
            title: _titleController.text.trim(),
            totalAmount: total,
            remainingAmount: total, // set to totalAmount on creation
            monthlyDue: monthly,
            startDate: _startDate,
            dueDate: _dueDate,
            note: _noteController.text.trim(),
            isSettled: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Debt updated.' : 'Debt added.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Failed to save debt. Please try again.');
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
        title: const Text('Delete Debt'),
        content: Text(
          'Delete "${widget.existingDebt!.title}" and all its '
          'payment history? This cannot be undone.',
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
                await ref.read(debtServiceProvider).deleteDebt(
                      uid,
                      widget.existingDebt!.debtId,
                    );
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debt deleted.')),
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
        title: Text(_isEditing ? 'Edit Debt' : 'New Debt'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.expense,
              tooltip: 'Delete debt',
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
            // ── Section 1: Debt Details ─────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debt Details',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Debt Title', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    enabled: !_isLoading,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_rounded),
                      hintText: 'e.g. Student Loan / PTPTN',
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

            // ── Section 2: Amount & Payment ─────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount & Payment',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Total Loan Amount', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _totalController,
                    enabled: !_isLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.attach_money_rounded),
                      hintText: '0.00',
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Total amount is required.';
                      final p = double.tryParse(s);
                      if (p == null) return 'Please enter a valid number.';
                      if (p <= 0) return 'Amount must be greater than 0.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Monthly Repayment', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _monthlyController,
                    enabled: !_isLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                      hintText: '0.00',
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Monthly repayment is required.';
                      final p = double.tryParse(s);
                      if (p == null) return 'Please enter a valid number.';
                      if (p <= 0) return 'Amount must be greater than 0.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 3: Due Date ─────────────────────────────────────────
            FintechCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Date',
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Start Date', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isLoading ? null : _pickStartDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.play_circle_outline_rounded)),
                      child: Text(
                        '${_startDate.day} '
                        '${_months[_startDate.month]} '
                        '${_startDate.year}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Final Due Date', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isLoading ? null : _pickDueDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.event_rounded)),
                      child: Text(
                        '${_dueDate.day} '
                        '${_months[_dueDate.month]} '
                        '${_dueDate.year}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: !_isEditing &&
                                  _dueDate.isBefore(DateTime.now())
                              ? AppColors.expense
                              : null,
                        ),
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
                      hintText: 'Add a note about this debt...',
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
              label: _isEditing ? 'Save Changes' : 'Add Debt',
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
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.expense, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.expense, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
