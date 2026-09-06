import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/fintech_card.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/export_service.dart';
import 'export_provider.dart';

// ── Format enum ───────────────────────────────────────────────────────────────

enum _ExportFormat { csv, pdf }

// ── Screen ────────────────────────────────────────────────────────────────────

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  // Format
  _ExportFormat _format = _ExportFormat.csv;

  // Date range — default to current month
  DateTime _startMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _endMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // Sections — all selected by default
  final Set<String> _selectedSections =
      Set<String>.from(ExportService.allSections);

  // Export state
  bool _isExporting = false;
  String? _errorMessage;
  String? _successMessage;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // ── Month key helpers ──────────────────────────────────────────────────────

  String _key(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  String _label(DateTime dt) =>
      '${_monthNames[dt.month]} ${dt.year}';

  // ── Quick date range helpers ───────────────────────────────────────────────

  void _setCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _startMonth = DateTime(now.year, now.month);
      _endMonth = DateTime(now.year, now.month);
    });
  }

  void _setLast3Months() {
    final now = DateTime.now();
    setState(() {
      _startMonth = DateTime(now.year, now.month - 2);
      _endMonth = DateTime(now.year, now.month);
    });
  }

  void _setLast6Months() {
    final now = DateTime.now();
    setState(() {
      _startMonth = DateTime(now.year, now.month - 5);
      _endMonth = DateTime(now.year, now.month);
    });
  }

  void _setThisYear() {
    final now = DateTime.now();
    setState(() {
      _startMonth = DateTime(now.year, 1);
      _endMonth = DateTime(now.year, now.month);
    });
  }

  // ── Month navigation ───────────────────────────────────────────────────────

  void _prevStart() =>
      setState(() => _startMonth =
          DateTime(_startMonth.year, _startMonth.month - 1));

  void _nextStart() {
    final next = DateTime(_startMonth.year, _startMonth.month + 1);
    if (!next.isAfter(_endMonth)) setState(() => _startMonth = next);
  }

  void _prevEnd() {
    final prev = DateTime(_endMonth.year, _endMonth.month - 1);
    if (!prev.isBefore(_startMonth)) setState(() => _endMonth = prev);
  }

  void _nextEnd() {
    final next = DateTime(_endMonth.year, _endMonth.month + 1);
    final now = DateTime.now();
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _endMonth = next);
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  String? get _validationError {
    if (_selectedSections.isEmpty) {
      return 'Select at least one section to include.';
    }
    final start = DateTime(_startMonth.year, _startMonth.month);
    final end = DateTime(_endMonth.year, _endMonth.month);
    if (start.isAfter(end)) {
      return 'Start month cannot be after end month.';
    }
    return null;
  }

  bool get _canGenerate =>
      _validationError == null && !_isExporting;

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> _generate() async {
    final error = _validationError;
    if (error != null) {
      setState(() { _errorMessage = error; _successMessage = null; });
      return;
    }

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final start = _key(_startMonth);
    final end = _key(_endMonth);
    final sections = _selectedSections.toList();

    try {
      final service = ref.read(exportServiceProvider);
      if (_format == _ExportFormat.csv) {
        await service.generateCustomCsvReport(uid, start, end, sections);
      } else {
        await service.generateCustomPdfReport(uid, start, end, sections);
      }
      if (mounted) {
        setState(() => _successMessage =
            '${_format == _ExportFormat.csv ? "CSV" : "PDF"} downloaded successfully!');
      }
    } on ExportEmptyException catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Export failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Export Report')),
      body: !kIsWeb
          ? _MobileNotice()
          : SingleChildScrollView(
              padding: context.responsivePadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.responsiveExportMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Export Format ──────────────────────────────────────────────
                    _FormSection(
                      title: '1. Export Format',
                      child: Row(children: [
                        _FormatChip(
                          label: 'Excel / CSV',
                          icon: Icons.table_chart_rounded,
                          selected: _format == _ExportFormat.csv,
                          color: AppColors.success,
                          onTap: () => setState(() => _format = _ExportFormat.csv),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _FormatChip(
                          label: 'PDF',
                          icon: Icons.picture_as_pdf_rounded,
                          selected: _format == _ExportFormat.pdf,
                          color: AppColors.danger,
                          onTap: () => setState(() => _format = _ExportFormat.pdf),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── 2. Date Range ──────────────────────────────────────────────────
                    _FormSection(
                      title: '2. Date Range',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sub-header: Quick Select
                          Text(
                            'Quick Select',
                            style: AppTypography.label.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            _QuickChip('Current Month', _setCurrentMonth),
                            _QuickChip('Last 3 Months', _setLast3Months),
                            _QuickChip('Last 6 Months', _setLast6Months),
                            _QuickChip('This Year', _setThisYear),
                          ]),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          // Sub-header: Custom Range
                          Text(
                            'Custom Range',
                            style: AppTypography.label.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(children: [
                            Expanded(
                              child: _MonthPicker(
                                label: 'Start Month',
                                value: _label(_startMonth),
                                onPrevious: _prevStart,
                                onNext: _nextStart,
                                canGoNext: !DateTime(
                                        _startMonth.year,
                                        _startMonth.month + 1)
                                    .isAfter(_endMonth),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              child: Text('to',
                                  style: AppTypography.label
                                      .copyWith(color: AppColors.textSecondary)),
                            ),
                            Expanded(
                              child: _MonthPicker(
                                label: 'End Month',
                                value: _label(_endMonth),
                                onPrevious: _prevEnd,
                                onNext: _nextEnd,
                                canGoNext: DateTime(
                                        _endMonth.year, _endMonth.month + 1)
                                    .compareTo(DateTime(DateTime.now().year,
                                        DateTime.now().month)) <= 0,
                              ),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _startMonth == _endMonth
                                ? '${_label(_startMonth)} only'
                                : '${_label(_startMonth)} → ${_label(_endMonth)} '
                                  '(${ref.read(exportServiceProvider).getMonthsInRange(_key(_startMonth), _key(_endMonth)).length} months)',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── 3. Sections to Include ─────────────────────────────────────────
                    _FormSection(
                      title: '3. Sections to Include',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            TextButton(
                              onPressed: () => setState(() =>
                                  _selectedSections
                                    ..addAll(ExportService.allSections)),
                              child: const Text('Select All'),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                  () => _selectedSections.clear()),
                              child: const Text('Clear All'),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.xs),
                          LayoutBuilder(builder: (ctx, constraints) {
                            final cols = constraints.maxWidth > 420 ? 2 : 1;
                            return Wrap(
                              children: ExportService.allSections.map((id) {
                                return SizedBox(
                                  width: constraints.maxWidth / cols,
                                  child: CheckboxListTile(
                                    dense: true,
                                    title: Text(
                                        ExportService.sectionLabels[id] ?? id,
                                        style: AppTypography.body.copyWith(
                                            color: Theme.of(ctx)
                                                .colorScheme
                                                .onSurface)),
                                    value: _selectedSections.contains(id),
                                    onChanged: (v) => setState(() {
                                      if (v!) {
                                        _selectedSections.add(id);
                                      } else {
                                        _selectedSections.remove(id);
                                      }
                                    }),
                                    activeColor: Theme.of(ctx).colorScheme.primary,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                );
                              }).toList(),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── 4. Generate Report ─────────────────────────────────────────────
                    _FormSection(
                      title: '4. Generate Report',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_validationError != null && _selectedSections.isNotEmpty)
                            _MessageBanner(
                                message: _validationError!, color: AppColors.warning),
                          if (_errorMessage != null)
                            _MessageBanner(
                                message: _errorMessage!, color: AppColors.danger),
                          if (_successMessage != null)
                            _MessageBanner(
                                message: _successMessage!, color: AppColors.success),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: _format == _ExportFormat.csv
                                ? 'Generate CSV Report'
                                : 'Generate PDF Report',
                            onPressed: _canGenerate ? _generate : null,
                            isLoading: _isExporting,
                            icon: _format == _ExportFormat.csv
                                ? Icons.download_rounded
                                : Icons.picture_as_pdf_rounded,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Center(
                            child: Text(
                              'Files are downloaded directly to your browser.',
                              style: AppTypography.caption.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.38)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FintechCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.heading.copyWith(
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: AppTypography.label.copyWith(
                    color: selected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
              color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.label,
    required this.value,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
  });

  final String label;
  final String value;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              onPressed: onPrevious,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTypography.label.copyWith(
                    color: Theme.of(context).colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: canGoNext
                    ? null
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38),
              ),
              onPressed: canGoNext ? onNext : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            ),
          ]),
        ),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isSuccess = color == AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(
          isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ),
      ]),
    );
  }
}

class _MobileNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: FintechCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.computer_rounded,
                    size: 36, color: AppColors.info),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Export is best used on the web version.',
                style: AppTypography.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Open the app in a desktop browser to generate '
                'customised CSV and PDF reports.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
