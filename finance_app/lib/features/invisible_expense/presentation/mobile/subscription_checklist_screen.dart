import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../domain/audit_decision_model.dart';
import '../../domain/audit_result_model.dart';
import '../audit_provider.dart';

/// Mobile: shows detected subscriptions as a checklist and micro-habit summary.
///
/// Keep / Review / Ignore buttons are for local user awareness only — they do
/// NOT write to Firestore, delete transactions, or cancel anything.
class SubscriptionChecklistScreen extends ConsumerStatefulWidget {
  const SubscriptionChecklistScreen({super.key});

  @override
  ConsumerState<SubscriptionChecklistScreen> createState() =>
      _SubscriptionChecklistScreenState();
}

class _SubscriptionChecklistScreenState
    extends ConsumerState<SubscriptionChecklistScreen> {
  final DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isRunning = false;
  String? _errorMessage;
  AuditResultModel? _result;

  // Local-only: tracks the user's response to each subscription (no Firestore writes)
  final Map<String, _SubscriptionStatus> _responses = {};

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get _monthKey =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  String get _monthLabel =>
      '${_monthNames[_currentMonth.month]} ${_currentMonth.year}';

  /// Leakage shown in the UI — excludes subscriptions the user has marked
  /// Keep or Ignore so the figure reflects only unreviewed / flagged items.
  ///
  /// Micro-habits are always included; they cannot be individually tagged.
  /// The underlying [AuditResultModel.estimatedAnnualLeakage] is unchanged.
  double get _displayedLeakage {
    if (_result == null) return 0.0;
    double total =
        _result!.microHabits.fold(0.0, (s, h) => s + h.projectedAnnual);
    for (final sub in _result!.subscriptions) {
      final status = _responses[sub.description];
      if (status != _SubscriptionStatus.keep &&
          status != _SubscriptionStatus.ignore) {
        total += sub.projectedAnnual;
      }
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    // Load saved audit result and user decisions for this month
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExisting();
      _loadDecisions();
    });
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    final existing =
        await ref.read(auditServiceProvider).getAuditResult(user.uid, _monthKey);
    if (mounted && existing != null) {
      setState(() => _result = existing);
    }
  }

  /// Loads previously saved Keep/Review/Ignore decisions from Firestore and
  /// pre-populates [_responses] so the UI reflects the persisted state.
  Future<void> _loadDecisions() async {
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    try {
      final saved =
          await ref.read(auditServiceProvider).getDecisions(uid, _monthKey);
      if (!mounted || saved.isEmpty) return;
      final updates = <String, _SubscriptionStatus>{};
      for (final d in saved.values) {
        final s = switch (d.status) {
          'keep'   => _SubscriptionStatus.keep,
          'review' => _SubscriptionStatus.review,
          'ignore' => _SubscriptionStatus.ignore,
          _        => _SubscriptionStatus.unknown,
        };
        if (s != _SubscriptionStatus.unknown) {
          updates[d.description] = s;
        }
      }
      if (mounted) setState(() => _responses.addAll(updates));
    } catch (_) {
      // Non-critical — user will just see no pre-selected status
    }
  }

  /// Saves the user's decision to Firestore, updates local state, and shows
  /// a confirmation SnackBar.  All three happen synchronously in the UI
  /// while the Firestore write runs in the background.
  Future<void> _setStatus(String description, _SubscriptionStatus status) async {
    // Update UI immediately
    setState(() => _responses[description] = status);

    // Confirmation SnackBar
    final label = switch (status) {
      _SubscriptionStatus.keep    => 'Marked as Keep',
      _SubscriptionStatus.review  => 'Marked for Review',
      _SubscriptionStatus.ignore  => 'Ignored',
      _SubscriptionStatus.unknown => '',
    };
    if (label.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (status == _SubscriptionStatus.unknown) return;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    final statusStr = switch (status) {
      _SubscriptionStatus.keep    => 'keep',
      _SubscriptionStatus.review  => 'review',
      _SubscriptionStatus.ignore  => 'ignore',
      _SubscriptionStatus.unknown => '',
    };

    try {
      await ref.read(auditServiceProvider).saveDecision(
        uid,
        AuditDecisionModel(
          description: description,
          status: statusStr,
          month: _monthKey,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Write failure is non-critical — local state is already updated
    }
  }

  Future<void> _runAudit() async {
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _responses.clear();
    });

    try {
      final result = await ref
          .read(auditServiceProvider)
          .runAudit(uid, _monthKey);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Audit failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Audit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              _monthLabel,
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
      body: _isRunning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analysing your transactions…'),
                ],
              ),
            )
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRunning ? null : _runAudit,
        icon: const Icon(Icons.search_rounded),
        label: Text(_result == null ? 'Run Audit' : 'Re-run Audit'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.expense),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(
                label: 'Retry',
                onPressed: _runAudit,
                isFullWidth: false,
              ),
            ],
          ),
        ),
      );
    }

    if (_result == null) {
      return _buildIdleState();
    }

    return _buildResults(_result!);
  }

  Widget _buildIdleState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.manage_search_rounded,
                  size: 40, color: AppColors.warning),
            ),
            const SizedBox(height: 20),
            Text('Invisible Expense Audit', style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Scan your transactions to detect recurring subscriptions '
              'and small spending habits you might have forgotten about.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Run Audit for $_monthLabel',
              onPressed: _runAudit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AuditResultModel result) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // ── Summary card ───────────────────────────────────────────────────
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text('Audit Summary', style: AppTextStyles.titleLarge),
                ],
              ),
              const SizedBox(height: 12),
              if (!result.hasFindings)
                Text(
                  '✅ No suspicious patterns found for $_monthLabel.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.income),
                )
              else ...[
                _SummaryRow(
                    label: 'Subscriptions detected',
                    value: '${result.subscriptions.length}'),
                _SummaryRow(
                    label: 'Micro-habits detected',
                    value: '${result.microHabits.length}'),
                _SummaryRow(
                    label: 'Est. annual leakage',
                    value: 'RM ${_displayedLeakage.toStringAsFixed(2)}',
                    valueColor: AppColors.expense),
              ],
              const SizedBox(height: 8),
              Text(
                'Last run: ${_formatTime(result.generatedAt)}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Subscriptions checklist ────────────────────────────────────────
        if (result.subscriptions.isNotEmpty) ...[
          Text(
            'Recurring Subscriptions (${result.subscriptions.length})',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Did you actually use these this month?',
            style: AppTextStyles.bodySmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ...result.subscriptions.map((sub) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SubscriptionCard(
                  item: sub,
                  status: _responses[sub.description] ??
                      _SubscriptionStatus.unknown,
                  onStatusChange: (s) => _setStatus(sub.description, s),
                ),
              )),
          const SizedBox(height: 16),
        ],

        // ── Confirmed subscriptions (Keep) ─────────────────────────────────
        Builder(builder: (context) {
          final keepItems = result.subscriptions
              .where((s) =>
                  (_responses[s.description] ?? _SubscriptionStatus.unknown) ==
                  _SubscriptionStatus.keep)
              .toList();
          if (keepItems.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmed Subscriptions (${keepItems.length})',
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Recurring payments you marked as intentional.',
                style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              ...keepItems.map((sub) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub.description,
                                  style: AppTextStyles.titleMedium),
                              Text(
                                'RM ${sub.amount.toStringAsFixed(2)}/mo · '
                                'Est. RM ${sub.projectedAnnual.toStringAsFixed(2)}/year',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.40)),
                          ),
                          child: const Text(
                            'Keep',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  )),
              const SizedBox(height: 16),
            ],
          );
        }),

        // ── Micro-habits ───────────────────────────────────────────────────
        if (result.microHabits.isNotEmpty) ...[
          Text(
            'Micro-Habits (${result.microHabits.length})',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 8),
          ...result.microHabits.map((habit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded,
                              size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(habit.description,
                                style: AppTextStyles.titleMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${habit.count}× this month · '
                        'Total RM ${habit.totalAmount.toStringAsFixed(2)}',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💡 This habit may cost RM '
                        '${habit.projectedAnnual.toStringAsFixed(2)} per year.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],

        if (!result.hasFindings)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 40, color: AppColors.income),
                const SizedBox(height: 12),
                Text('Looking clean!',
                    style: AppTextStyles.titleLarge
                        .copyWith(color: AppColors.income)),
                const SizedBox(height: 4),
                Text(
                  'No invisible expenses detected for $_monthLabel.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subscription card ─────────────────────────────────────────────────────────

enum _SubscriptionStatus { unknown, keep, review, ignore }

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.item,
    required this.status,
    required this.onStatusChange,
  });

  final SubscriptionItem item;
  final _SubscriptionStatus status;
  final ValueChanged<_SubscriptionStatus> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = switch (status) {
      _SubscriptionStatus.keep   => AppColors.income,
      _SubscriptionStatus.review => AppColors.warning,
      _SubscriptionStatus.ignore => cs.outlineVariant,
      _SubscriptionStatus.unknown => cs.outlineVariant,
    };
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.subscriptions_rounded,
                  size: 18, color: AppColors.catSubscription),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.description,
                    style: AppTextStyles.titleMedium),
              ),
              Text(
                'RM ${item.amount.toStringAsFixed(2)}/mo',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.expense),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Detected ${item.occurrences}× · '
            'Est. RM ${item.projectedAnnual.toStringAsFixed(2)}/year',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 10),
          // Keep / Review / Ignore buttons (local only — no Firestore writes)
          Row(
            children: [
              _ActionButton(
                label: '✓ Keep',
                active: status == _SubscriptionStatus.keep,
                activeColor: AppColors.income,
                onTap: () => onStatusChange(_SubscriptionStatus.keep),
              ),
              const SizedBox(width: 6),
              _ActionButton(
                label: '⚠ Review',
                active: status == _SubscriptionStatus.review,
                activeColor: AppColors.warning,
                onTap: () => onStatusChange(_SubscriptionStatus.review),
              ),
              const SizedBox(width: 6),
              _ActionButton(
                label: '— Ignore',
                active: status == _SubscriptionStatus.ignore,
                activeColor: cs.onSurfaceVariant,
                onTap: () => onStatusChange(_SubscriptionStatus.ignore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? activeColor
                  : Theme.of(context).colorScheme.outlineVariant,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: active
                  ? activeColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
