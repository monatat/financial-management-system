import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/debt_payment_model.dart';
import 'debt_provider.dart';

/// Screen for logging a repayment toward a debt.
class AddDebtPaymentScreen extends ConsumerStatefulWidget {
  const AddDebtPaymentScreen({super.key, required this.debtId});

  final String debtId;

  @override
  ConsumerState<AddDebtPaymentScreen> createState() =>
      _AddDebtPaymentScreenState();
}

class _AddDebtPaymentScreenState
    extends ConsumerState<AddDebtPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _currency = AppStrings.defaultCurrency;
  bool _isLoading = false;
  String? _errorMessage;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrency());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    final profile = await ref.read(currentUserProfileProvider.future);
    if (mounted && profile != null) {
      setState(() => _currency = profile.currency);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      await ref.read(debtServiceProvider).addPayment(
            uid,
            widget.debtId,
            DebtPaymentModel(
              paymentId: '',
              amount: double.parse(_amountController.text.trim()),
              date: _selectedDate,
              note: _noteController.text.trim(),
              createdAt: now,
            ),
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            'Failed to record payment. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.appFormHorizontalPadding,
            vertical: context.formVerticalPadding(),
          ),
          children: [
            // ── Amount ──────────────────────────────────────────────────────
            Text('Payment Amount', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              enabled: !_isLoading,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.payments_rounded),
                hintText: '0.00',
                prefixText: '$_currency ',
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Amount is required.';
                final p = double.tryParse(s);
                if (p == null) return 'Please enter a valid number.';
                if (p <= 0) return 'Amount must be greater than 0.';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Date ────────────────────────────────────────────────────────
            Text('Payment Date', style: AppTextStyles.titleMedium),
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
                  '${_months[_selectedDate.month]} '
                  '${_selectedDate.year}',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Note ────────────────────────────────────────────────────────
            Text('Note (optional)', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              enabled: !_isLoading,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
                hintText: 'e.g. Monthly PTPTN repayment',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v != null && v.length > 200) {
                  return 'Note must be 200 characters or less.';
                }
                return null;
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              _ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),

            AppButton(
              label: 'Record Payment',
              onPressed: _isLoading ? null : _save,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),
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
