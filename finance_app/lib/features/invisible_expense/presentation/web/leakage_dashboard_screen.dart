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

/// Web: full invisible expense leakage dashboard.
///
/// Displays total annual leakage, detected subscriptions, and micro-habits
/// with individual insight messages.
///
/// Read-only — no transactions are modified or cancelled.
class LeakageDashboardScreen extends ConsumerStatefulWidget {
  const LeakageDashboardScreen({super.key});

  @override
  ConsumerState<LeakageDashboardScreen> createState() =>
      _LeakageDashboardScreenState();
}

class _LeakageDashboardScreenState
    extends ConsumerState<LeakageDashboardScreen> {
  final DateTime _currentMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  bool _isRunning = false;
  String? _errorMessage;
  AuditResultModel? _result;
  // Persisted decisions keyed by normalised description
  Map<String, AuditDecisionModel> _decisions = {};

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get _monthKey =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  String get _monthLabel =>
      '${_monthNames[_currentMonth.month]} ${_currentMonth.year}';

  @override
  void initState() {
    super.initState();
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
    if (mounted && existing != null) setState(() => _result = existing);
  }

  Future<void> _loadDecisions() async {
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    try {
      final saved =
          await ref.read(auditServiceProvider).getDecisions(uid, _monthKey);
      if (mounted) setState(() => _decisions = saved);
    } catch (_) {}
  }

  /// Leakage shown in the UI — excludes subscriptions the user has marked
  /// Keep or Ignore so the figure reflects only unreviewed / flagged items.
  ///
  /// Micro-habits are always included; they cannot be individually tagged.
  /// The underlying [AuditResultModel.estimatedAnnualLeakage] is unchanged.
  double _displayedLeakage(AuditResultModel result) {
    double total = result.microHabitLeakage;
    for (final sub in result.subscriptions) {
      final key = sub.description.trim().toLowerCase();
      final status = _decisions[key]?.status;
      if (status != 'keep' && status != 'ignore') {
        total += sub.projectedAnnual;
      }
    }
    return total;
  }

  Future<void> _runAudit() async {
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isRunning = true;
      _errorMessage = null;
    });

    try {
      final result =
          await ref.read(auditServiceProvider).runAudit(uid, _monthKey);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Audit failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  String _fmt(double v) => 'RM ${v.toStringAsFixed(2)}';

  String _formatTime(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invisible Expense Dashboard'),
            Text(_monthLabel,
                style: AppTextStyles.bodySmall
                    .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAudit,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.manage_search_rounded, size: 18),
              label: Text(_result == null ? 'Run Audit' : 'Re-run Audit'),
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
                  Text('Analysing your transactions across 3 months…'),
                ],
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.expense),
            const SizedBox(height: 12),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            AppButton(
                label: 'Retry', onPressed: _runAudit, isFullWidth: false),
          ],
        ),
      );
    }

    if (_result == null) return _buildIdleState();
    return _buildDashboard(_result!);
  }

  Widget _buildIdleState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.leak_add_rounded,
                  size: 44, color: AppColors.warning),
            ),
            const SizedBox(height: 20),
            Text('Invisible Expense Audit',
                style: AppTextStyles.displayMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                'Detect recurring subscriptions you may have forgotten and '
                'micro-spending habits that quietly drain your wallet.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Run Audit for $_monthLabel',
              onPressed: _runAudit,
              isFullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(AuditResultModel result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top summary cards ────────────────────────────────────────
            Row(
              children: [
                _TopCard(
                  label: 'Est. Annual Leakage',
                  value: _fmt(_displayedLeakage(result)),
                  icon: Icons.money_off_rounded,
                  color: AppColors.expense,
                  subtitle: 'Excludes Keep & Ignored items',
                ),
                const SizedBox(width: 12),
                _TopCard(
                  label: 'Subscription Leakage',
                  value: _fmt(result.subscriptionLeakage),
                  icon: Icons.subscriptions_rounded,
                  color: AppColors.catSubscription,
                  subtitle:
                      '${result.subscriptions.length} recurring charges/mo',
                ),
                const SizedBox(width: 12),
                _TopCard(
                  label: 'Micro-Habit Leakage',
                  value: _fmt(result.microHabitLeakage),
                  icon: Icons.coffee_rounded,
                  color: AppColors.warning,
                  subtitle:
                      '${result.microHabits.length} small habits/mo',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last audit: ${_formatTime(result.generatedAt)} · '
              'Covers last 3 months of transactions · '
              'Read-only — no transactions were modified.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
            ),
            const SizedBox(height: 20),

            if (!result.hasFindings) ...[
              AppCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 56, color: AppColors.income),
                    const SizedBox(height: 16),
                    Text('Looking clean!',
                        style: AppTextStyles.headlineLarge
                            .copyWith(color: AppColors.income)),
                    const SizedBox(height: 8),
                    Text(
                      'No invisible expenses detected for $_monthLabel.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ── Two-column layout ──────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Subscriptions + Confirmed Subscriptions
                  Expanded(
                    flex: 5,
                    child: Builder(builder: (context) {
                      final keepItems = result.subscriptions
                          .where((s) => _decisions[
                                  s.description.trim().toLowerCase()]
                              ?.status ==
                              'keep')
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── All recurring subscriptions ─────────────────
                          AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.subscriptions_rounded,
                                        color: AppColors.catSubscription,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Recurring Subscriptions '
                                      '(${result.subscriptions.length})',
                                      style: AppTextStyles.headlineMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Detected across the last 3 months.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                if (result.subscriptions.isEmpty)
                                  _EmptySection(
                                      label:
                                          'No recurring subscriptions found.')
                                else ...[
                                  _TableHeader(
                                    columns: const [
                                      'Description',
                                      'Monthly',
                                      'Est. Annual',
                                      'Seen',
                                      'Status',
                                    ],
                                    flex: const [4, 2, 2, 1, 2],
                                  ),
                                  const Divider(height: 12),
                                  ...result.subscriptions.map((sub) {
                                    final key =
                                        sub.description.trim().toLowerCase();
                                    return _SubscriptionRow(
                                      item: sub,
                                      fmt: _fmt,
                                      decision: _decisions[key],
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),

                          // ── Confirmed Subscriptions (Keep) ───────────────
                          if (keepItems.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        color: AppColors.success, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Confirmed Subscriptions '
                                      '(${keepItems.length})',
                                      style: AppTextStyles.headlineMedium,
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Recurring payments you marked as intentional.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  _TableHeader(
                                    columns: const [
                                      'Description',
                                      'Monthly',
                                      'Est. Annual',
                                      'Status',
                                    ],
                                    flex: const [5, 2, 2, 2],
                                  ),
                                  const Divider(height: 12),
                                  ...keepItems.map((sub) {
                                    final key =
                                        sub.description.trim().toLowerCase();
                                    return _SubscriptionRow(
                                      item: sub,
                                      fmt: _fmt,
                                      decision: _decisions[key],
                                      hideSeen: true,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 16),

                  // Right: Micro-habits + insight messages
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.loop_rounded,
                                      color: AppColors.warning, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Micro-Habits '
                                    '(${result.microHabits.length})',
                                    style: AppTextStyles.headlineMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Small frequent expenses (< RM 10).',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              if (result.microHabits.isEmpty)
                                _EmptySection(
                                    label: 'No micro-habits found.')
                              else
                                ...result.microHabits
                                    .map((h) => _MicroHabitRow(
                                          item: h,
                                          fmt: _fmt,
                                        )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Insight messages
                        if (result.microHabits.isNotEmpty ||
                            result.subscriptions.isNotEmpty)
                          AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb_rounded,
                                        color: AppColors.warning, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Insights',
                                        style: AppTextStyles.headlineMedium),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...[
                                  ...result.microHabits.map(
                                    (h) => _InsightCard(
                                      message:
                                          'Your ${_fmt(h.totalAmount / h.count)} '
                                          '"${h.description}" habit may cost '
                                          '${_fmt(h.projectedAnnual)} per year.',
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  ...result.subscriptions.map((s) {
                                    final key =
                                        s.description.trim().toLowerCase();
                                    final status =
                                        _decisions[key]?.status;
                                    if (status == 'keep') {
                                      return _InsightCard(
                                        message:
                                            '"${s.description}" appears to be a recurring subscription and has been marked Keep.',
                                        color: AppColors.info,
                                      );
                                    }
                                    if (status == 'ignore') {
                                      return _InsightCard(
                                        message:
                                            '"${s.description}" appears to be a recurring subscription and has been marked Ignore.',
                                        color: AppColors.info,
                                      );
                                    }
                                    // Not reviewed or Review — warning insight
                                    return _InsightCard(
                                      message:
                                          'Your ${_fmt(s.amount)} "${s.description}" '
                                          'subscription costs an estimated '
                                          '${_fmt(s.projectedAnnual)} per year.',
                                      color: AppColors.catSubscription,
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text(value,
                      style: AppTextStyles.amountMedium.copyWith(color: color),
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.flex});

  final List<String> columns;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(columns.length, (i) {
        return Expanded(
          flex: flex[i],
          child: Text(
            columns[i],
            style: AppTextStyles.labelLarge,
            textAlign: i > 0 ? TextAlign.right : TextAlign.left,
          ),
        );
      }),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.item,
    required this.fmt,
    this.decision,
    this.hideSeen = false,
  });

  final SubscriptionItem item;
  final String Function(double) fmt;
  final AuditDecisionModel? decision;

  /// When true the "Seen N×" column is omitted (used in Confirmed table).
  final bool hideSeen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: hideSeen ? 5 : 4,
            child: Text(item.description,
                style: AppTextStyles.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(
              fmt(item.amount),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.expense),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              fmt(item.projectedAnnual),
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.expense),
              textAlign: TextAlign.right,
            ),
          ),
          if (!hideSeen)
            Expanded(
              flex: 1,
              child: Text(
                '${item.occurrences}×',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.right,
              ),
            ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: _StatusBadge(status: decision?.status),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (status == null || status!.isEmpty) {
      return Text(
        'Not reviewed',
        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.38)),
        textAlign: TextAlign.right,
      );
    }

    final String label;
    final Color textColor;
    final Color borderColor;
    final Color bgColor;

    switch (status) {
      case 'keep':
        label       = 'Keep';
        textColor   = AppColors.success;
        borderColor = AppColors.success.withValues(alpha: 0.40);
        bgColor     = AppColors.success.withValues(alpha: 0.10);
      case 'review':
        label       = 'Review';
        textColor   = AppColors.warning;
        borderColor = AppColors.warning.withValues(alpha: 0.40);
        bgColor     = AppColors.warning.withValues(alpha: 0.10);
      case 'ignore':
        label       = 'Ignore';
        textColor   = cs.onSurfaceVariant;
        borderColor = cs.outlineVariant;
        bgColor     = cs.surfaceContainerHighest;
      default:
        label       = 'Unknown';
        textColor   = cs.onSurfaceVariant;
        borderColor = cs.outlineVariant;
        bgColor     = cs.surfaceContainerHighest;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _MicroHabitRow extends StatelessWidget {
  const _MicroHabitRow({required this.item, required this.fmt});

  final MicroHabitItem item;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description,
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${item.count}× this month',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              fmt(item.totalAmount),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.warning),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              fmt(item.projectedAnnual),
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.warning),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(label,
          style: AppTextStyles.bodyMedium
              .copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
          textAlign: TextAlign.center),
    );
  }
}
