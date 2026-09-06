import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../debts/presentation/debt_provider.dart';
import '../../saving_goals/presentation/saving_goal_provider.dart';
import '../domain/month_end_sweep_model.dart';
import 'sweep_provider.dart';

// ── Per-row mutable state ─────────────────────────────────────────────────────

class _Entry {
  _Entry({required this.type, required this.id})
      : controller = TextEditingController();

  final String id;            // stable unique ID for ValueKey
  final String type;          // "savingGoal" | "debt"
  String? destinationId;
  String? destinationLabel;
  final TextEditingController controller;

  double get amount => double.tryParse(controller.text.trim()) ?? 0.0;

  bool get isValid =>
      destinationId != null && destinationId!.isNotEmpty && amount > 0;

  void dispose() => controller.dispose();
}

// ── Popup widget ──────────────────────────────────────────────────────────────

/// Dialog shown when a monthly leftover is detected.
///
/// The user can add multiple allocation rows targeting any combination of
/// active saving goals and unsettled debts.
///
/// Rules:
///   - Total allocated ≤ leftoverAmount  (partial allocation is allowed)
///   - Each row needs a destination AND an amount > 0
///   - Same destination cannot be selected twice
///   - No transactions are created or modified
class LeftoverPopup extends ConsumerStatefulWidget {
  const LeftoverPopup({
    super.key,
    required this.sweep,
    required this.uid,
    required this.onDone,
  });

  final MonthEndSweepModel sweep;
  final String uid;
  final VoidCallback onDone; // called after completion; popup handles its own close

  @override
  ConsumerState<LeftoverPopup> createState() => _LeftoverPopupState();
}

class _LeftoverPopupState extends ConsumerState<LeftoverPopup> {
  final List<_Entry> _entries = [];
  int _nextId = 0;
  bool _isActing = false;
  String? _globalError;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void dispose() {
    for (final e in _entries) { e.dispose(); }
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _monthLabel(String key) {
    final p = key.split('-');
    if (p.length < 2) return key;
    final m = int.tryParse(p[1]) ?? 0;
    return '${m > 0 && m < 13 ? _monthNames[m] : p[1]} ${p[0]}';
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  double get _totalAllocated =>
      _entries.fold(0.0, (s, e) => s + e.amount);

  double get _remaining => widget.sweep.leftoverAmount - _totalAllocated;

  bool get _isOverAllocated =>
      _totalAllocated > widget.sweep.leftoverAmount + 0.001;

  bool get _canAllocate =>
      !_isOverAllocated &&
      _totalAllocated > 0 &&
      _entries.isNotEmpty &&
      _entries.every((e) => e.isValid);

  /// IDs selected in OTHER rows of the same [type].
  Set<String> _otherSelected(int rowIndex, String type) => _entries
      .asMap()
      .entries
      .where((e) =>
          e.key != rowIndex &&
          e.value.type == type &&
          e.value.destinationId != null)
      .map((e) => e.value.destinationId!)
      .toSet();

  // ── Row management ─────────────────────────────────────────────────────────

  void _addGoalRow() =>
      setState(() => _entries.add(_Entry(type: 'savingGoal', id: '${_nextId++}')));

  void _addDebtRow() =>
      setState(() => _entries.add(_Entry(type: 'debt', id: '${_nextId++}')));

  void _removeRow(int index) {
    _entries[index].dispose();
    setState(() => _entries.removeAt(index));
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _allocate() async {
    if (!_canAllocate) return;

    setState(() { _isActing = true; _globalError = null; });

    try {
      final allocations = _entries
          .where((e) => e.isValid)
          .map((e) => AllocationItem(
                label: e.destinationLabel ?? '',
                amount: e.amount,
                destinationType: e.type,
                destinationId: e.destinationId!,
              ))
          .toList();

      await ref.read(sweepServiceProvider).completeSweep(
            widget.uid, widget.sweep, allocations);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(); // close with popup's OWN context
        messenger.showSnackBar(SnackBar(
          content: Text(
            'RM ${_totalAllocated.toStringAsFixed(2)} allocated successfully!'),
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _isActing = false; _globalError = 'Allocation failed. Please try again.'; });
    }
  }

  Future<void> _skip() async {
    setState(() => _isActing = true);
    try {
      await ref.read(sweepServiceProvider).skipSweep(
            widget.uid, widget.sweep.month);
      if (mounted) Navigator.of(context).pop(); // popup's OWN context
    } catch (_) {
      if (mounted) setState(() => _isActing = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final goals = (ref.watch(goalsProvider).asData?.value ?? [])
        .where((g) => !g.isCompleted)
        .toList();
    final debts = (ref.watch(debtsProvider).asData?.value ?? [])
        .where((d) => !d.isSettled)
        .toList();
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ?? 'MYR';
    final hasDestinations = goals.isNotEmpty || debts.isNotEmpty;

    // How many goals / debts can still be added (not yet picked in a row)
    final pickedGoalIds = _entries
        .where((e) => e.type == 'savingGoal' && e.destinationId != null)
        .map((e) => e.destinationId!)
        .toSet();
    final pickedDebtIds = _entries
        .where((e) => e.type == 'debt' && e.destinationId != null)
        .map((e) => e.destinationId!)
        .toSet();
    final canAddGoal =
        goals.any((g) => !pickedGoalIds.contains(g.goalId));
    final canAddDebt =
        debts.any((d) => !pickedDebtIds.contains(d.debtId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fixed header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title row
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_rounded,
                          color: AppColors.income, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Leftover Detected!',
                              style: AppTextStyles.headlineMedium),
                          Text(_monthLabel(widget.sweep.month),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // Leftover amount card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.income.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.income.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Text(
                        '$currency ${widget.sweep.leftoverAmount.toStringAsFixed(2)}',
                        style: AppTextStyles.amountMedium
                            .copyWith(color: AppColors.income),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'left from ${_monthLabel(widget.sweep.month)}. '
                          'Give it a job!',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // No destinations warning
                    if (!hasDestinations)
                      _InfoBox(
                        message:
                            'Create a saving goal or debt first to allocate leftover money.',
                        color: AppColors.warning,
                      )
                    else if (_entries.isEmpty)
                      Center(
                        child: Text(
                          'Use the buttons below to choose where to put your leftover.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Allocation rows
                    const SizedBox(height: 4),
                    ...List.generate(_entries.length, (i) {
                      final entry = _entries[i];
                      final isGoal = entry.type == 'savingGoal';
                      final items = isGoal
                          ? goals
                              .where((g) => !_otherSelected(i, 'savingGoal')
                                  .contains(g.goalId))
                              .map((g) => DropdownMenuItem<String>(
                                    value: g.goalId,
                                    child: Text(g.title,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList()
                          : debts
                              .where((d) => !_otherSelected(i, 'debt')
                                  .contains(d.debtId))
                              .map((d) => DropdownMenuItem<String>(
                                    value: d.debtId,
                                    child: Text(d.title,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          // Type icon
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: (isGoal
                                      ? AppColors.income
                                      : AppColors.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isGoal
                                  ? Icons.savings_rounded
                                  : Icons.account_balance_rounded,
                              size: 15,
                              color: isGoal
                                  ? AppColors.income
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Destination dropdown
                          Expanded(
                            flex: 5,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(
                                  '${entry.id}-${entry.destinationId ?? "none"}'),
                              initialValue: entry.destinationId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                                hintText: 'Select',
                              ),
                              items: items,
                              onChanged: _isActing
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      final label = isGoal
                                          ? goals
                                              .firstWhere(
                                                  (g) => g.goalId == value)
                                              .title
                                          : debts
                                              .firstWhere(
                                                  (d) => d.debtId == value)
                                              .title;
                                      setState(() {
                                        entry.destinationId = value;
                                        entry.destinationLabel = label;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Amount field
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              controller: entry.controller,
                              enabled: !_isActing,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                                hintText: '0.00',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 2),

                          // Remove row
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.expense,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 30, minHeight: 30),
                            onPressed:
                                _isActing ? null : () => _removeRow(i),
                          ),
                        ]),
                      );
                    }),

                    const SizedBox(height: 8),

                    // Add-row buttons
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              (canAddGoal && !_isActing) ? _addGoalRow : null,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Saving Goal'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.income,
                            side: BorderSide(
                                color: canAddGoal
                                    ? AppColors.income
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              (canAddDebt && !_isActing) ? _addDebtRow : null,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Debt / Loan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                                color: canAddDebt
                                    ? AppColors.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 12),

                    // Totals summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant),
                      ),
                      child: Column(children: [
                        _TotalRow(
                          label: 'Total allocated:',
                          value:
                              '$currency ${_totalAllocated.toStringAsFixed(2)}',
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(height: 4),
                        _TotalRow(
                          label: 'Remaining unallocated:',
                          value:
                              '$currency ${_remaining.abs().toStringAsFixed(2)}',
                          color: _isOverAllocated
                              ? AppColors.expense
                              : _remaining <= 0.001
                                  ? AppColors.income
                                  : AppColors.warning,
                        ),
                      ]),
                    ),

                    // Over-allocation error
                    if (_isOverAllocated) ...[
                      const SizedBox(height: 8),
                      _InfoBox(
                        message: 'Allocation cannot exceed leftover amount.',
                        color: AppColors.expense,
                      ),
                    ],

                    if (_globalError != null) ...[
                      const SizedBox(height: 6),
                      Text(_globalError!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.expense)),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Fixed footer ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Allocate Now',
                    onPressed: (_canAllocate && !_isActing && hasDestinations)
                        ? _allocate
                        : null,
                    isLoading: _isActing,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _isActing ? null : _skip,
                    child: Text(
                      'Skip This Month',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  const _TotalRow(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(value,
            style: AppTextStyles.titleMedium.copyWith(color: color)),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(message,
          style: AppTextStyles.bodySmall.copyWith(color: color)),
    );
  }
}
