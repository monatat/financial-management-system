import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/transaction_model.dart';
import 'add_transaction_screen.dart';
import 'edit_transaction_screen.dart';
import 'transaction_provider.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  // Month navigation state — defaults to current month
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  // Local filter: "all" | "income" | "expense"
  String _filterType = 'all';

  // ── Month helpers ──────────────────────────────────────────────────────────

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get _monthKey =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  String get _monthLabel =>
      '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}';

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    final now = DateTime.now();
    // Do not navigate past the current month
    if (next.year < now.year ||
        (next.year == now.year && next.month <= now.month)) {
      setState(() => _currentMonth = next);
    }
  }

  // ── Amount formatting ──────────────────────────────────────────────────────

  static const _shortMonths = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) => '${d.day} ${_shortMonths[d.month]}';

  String _formatAmount(TransactionModel t) {
    final sign = t.isIncome ? '+' : '-';
    return '$sign${t.currency} ${t.amount.toStringAsFixed(2)}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final transactionsAsync =
        ref.watch(transactionsByMonthProvider(_monthKey));

    return Scaffold(
      appBar: AppBar(
        title: _MonthNavigator(
          label: _monthLabel,
          onPrevious: _previousMonth,
          onNext: _nextMonth,
          canGoNext: () {
            final next =
                DateTime(_currentMonth.year, _currentMonth.month + 1);
            final now = DateTime.now();
            return next.year < now.year ||
                (next.year == now.year && next.month <= now.month);
          },
        ),
        centerTitle: true,
      ),
      body: transactionsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load transactions',
              style: AppTextStyles.bodyMedium),
        ),
        data: (all) {
          // Apply local type filter
          final transactions = _filterType == 'all'
              ? all
              : all.where((t) => t.type == _filterType).toList();

          return ResponsiveContent(
            child: Column(
              children: [
              _SummaryRow(transactions: all),
              _FilterBar(
                selected: _filterType,
                onChanged: (v) => setState(() => _filterType = v),
              ),
              const Divider(height: 1),
              Expanded(
                child: transactions.isEmpty
                    ? EmptyState(
                        title: 'No transactions',
                        subtitle: _filterType == 'all'
                            ? 'Tap + to record your first transaction for $_monthLabel.'
                            : 'No $_filterType transactions in $_monthLabel.',
                        icon: Icons.receipt_long_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: transactions.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) =>
                            _TransactionTile(
                          transaction: transactions[index],
                          formatDate: _formatDate,
                          formatAmount: _formatAmount,
                          onTap: () => _openEdit(transactions[index]),
                        ),
                      ),
              ),
            ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openAdd() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const AddTransactionScreen(),
    ));
  }

  void _openEdit(TransactionModel transaction) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => EditTransactionScreen(transaction: transaction),
    ));
  }
}

// ── Month navigator widget ────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool Function() canGoNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrevious,
          tooltip: 'Previous month',
        ),
        Text(label, style: AppTextStyles.titleLarge),
        IconButton(
          icon: Icon(
            Icons.chevron_right_rounded,
            color: canGoNext()
                ? null
                : AppColors.textDisabled,
          ),
          onPressed: canGoNext() ? onNext : null,
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.transactions});

  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    double income = 0;
    double expense = 0;
    String currency = 'MYR';

    for (final t in transactions) {
      currency = t.currency;
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    final balance = income - expense;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SummaryCard(
            label: 'Income',
            value: '$currency ${income.toStringAsFixed(2)}',
            color: AppColors.income,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Expense',
            value: '$currency ${expense.toStringAsFixed(2)}',
            color: AppColors.expense,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Balance',
            value: '$currency ${balance.toStringAsFixed(2)}',
            color: balance >= 0 ? AppColors.primary : AppColors.expense,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                fontSize: 11,
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

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _FilterChip(label: 'All', value: 'all', selected: selected, onTap: onChanged),
          const SizedBox(width: 8),
          _FilterChip(label: 'Income', value: 'income', selected: selected, onTap: onChanged),
          const SizedBox(width: 8),
          _FilterChip(label: 'Expense', value: 'expense', selected: selected, onTap: onChanged),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color:
                isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.formatDate,
    required this.formatAmount,
    required this.onTap,
  });

  final TransactionModel transaction;
  final String Function(DateTime) formatDate;
  final String Function(TransactionModel) formatAmount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final amountColor =
        isIncome ? AppColors.income : AppColors.expense;
    final iconData =
        isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 18, color: amountColor),
              ),
              const SizedBox(width: 12),

              // Description + category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: AppTextStyles.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.categoryName,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Amount + date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(transaction),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(transaction.date),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
