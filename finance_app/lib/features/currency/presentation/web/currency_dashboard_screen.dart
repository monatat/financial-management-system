import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/responsive/responsive_helpers.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/currency_service.dart';
import '../currency_provider.dart';

class CurrencyDashboardScreen extends ConsumerStatefulWidget {
  const CurrencyDashboardScreen({super.key});

  @override
  ConsumerState<CurrencyDashboardScreen> createState() =>
      _CurrencyDashboardScreenState();
}

class _CurrencyDashboardScreenState
    extends ConsumerState<CurrencyDashboardScreen> {
  final _amountController = TextEditingController(text: '1');
  String _fromCurrency = 'MYR';
  String _toCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _swapCurrencies() =>
      setState(() {
        final tmp = _fromCurrency;
        _fromCurrency = _toCurrency;
        _toCurrency = tmp;
      });

  String _formatLastUpdated(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(currencyRatesProvider);
    final supported =
        ref.read(currencyServiceProvider).getSupportedCurrencies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Dashboard'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.invalidate(currencyRatesProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh Rates'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ratesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(),
        data: (ratesModel) {
          if (ratesModel == null) return _buildErrorState();
          return _buildContent(context, ratesModel, supported);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    dynamic ratesModel,
    List<String> supported,
  ) {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.responsiveMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Last updated banner ──────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Rates last updated: '
                    '${_formatLastUpdated(ratesModel.fetchedAt)} '
                    '· Source: ${ratesModel.source}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    'Base currency: MYR',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Two-column layout ────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Converter panel
                SizedBox(
                  width: 380,
                  child: AppCard(
                    padding: const EdgeInsets.all(20),
                    child: _ConverterPanel(
                      amountController: _amountController,
                      fromCurrency: _fromCurrency,
                      toCurrency: _toCurrency,
                      supported: supported,
                      rates: Map<String, double>.from(ratesModel.rates),
                      onFromChanged: (v) =>
                          setState(() => _fromCurrency = v),
                      onToChanged: (v) => setState(() => _toCurrency = v),
                      onSwap: _swapCurrencies,
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right: All rates table
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Current Rates vs MYR',
                          style: AppTextStyles.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        // Table header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              const Expanded(
                                  flex: 2,
                                  child: Text('Currency',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              const Expanded(
                                  flex: 3,
                                  child: Text('Name',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Expanded(
                                flex: 2,
                                child: Text('Rate',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.right),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('1 MYR =',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 8),
                        ...supported.map((code) {
                          final rate = (ratesModel.rates as Map<String, double>)[code] ?? 0.0;
                          final invertedRate = rate > 0 ? 1.0 / rate : 0.0;
                          return InkWell(
                            onTap: () => setState(() {
                              _fromCurrency = 'MYR';
                              _toCurrency = code;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 10),
                              decoration: _fromCurrency == 'MYR' &&
                                      _toCurrency == code
                                  ? BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.10),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.30),
                                      ),
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Text(
                                          CurrencyService
                                                  .currencyFlags[code] ??
                                              '',
                                          style: const TextStyle(
                                              fontSize: 20),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(code,
                                            style: AppTextStyles
                                                .titleMedium),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      CurrencyService
                                              .currencyNames[code] ??
                                          '',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      CurrencyService.formatAmount(rate),
                                      style: AppTextStyles.titleMedium
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      code == 'MYR'
                                          ? '1.0000'
                                          : CurrencyService
                                              .formatAmount(invertedRate),
                                      style: AppTextStyles.bodySmall
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Text(
                          'Tap a row to set as target currency in the converter.',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.38)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.38)),
            const SizedBox(height: 16),
            Text(
              'Exchange rates unavailable',
              style: AppTextStyles.headlineMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load rates from the API and no cached data found.\n'
              'Check your internet connection and tap Refresh Rates.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(currencyRatesProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Converter panel (shared between mobile + web) ─────────────────────────────

class _ConverterPanel extends StatelessWidget {
  const _ConverterPanel({
    required this.amountController,
    required this.fromCurrency,
    required this.toCurrency,
    required this.supported,
    required this.rates,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onSwap,
  });

  final TextEditingController amountController;
  final String fromCurrency;
  final String toCurrency;
  final List<String> supported;
  final Map<String, double> rates;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final inputAmount = double.tryParse(amountController.text.trim());
    final result = inputAmount != null
        ? CurrencyService.convertWithRates(
            inputAmount, fromCurrency, toCurrency, rates)
        : null;
    final rateStr = CurrencyService.rateDisplay(rates, fromCurrency, toCurrency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Currency Converter', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 16),

        // Amount
        TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: AppTextStyles.amountMedium,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixIcon: Icon(Icons.numbers_rounded),
          ),
        ),
        const SizedBox(height: 16),

        // From dropdown
        _WebCurrencyDropdown(
          label: 'From',
          selected: fromCurrency,
          currencies: supported,
          onChanged: onFromChanged,
        ),
        const SizedBox(height: 8),

        // Swap button
        Center(
          child: IconButton.filled(
            onPressed: onSwap,
            icon: const Icon(Icons.swap_vert_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            tooltip: 'Swap currencies',
          ),
        ),
        const SizedBox(height: 8),

        // To dropdown
        _WebCurrencyDropdown(
          label: 'To',
          selected: toCurrency,
          currencies: supported,
          onChanged: onToChanged,
        ),
        const SizedBox(height: 20),

        // Result display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result != null
                    ? CurrencyService.formatAmount(result)
                    : '—',
                style: AppTextStyles.amountLarge.copyWith(
                    color: Theme.of(context).colorScheme.primary),
              ),
              Text(
                toCurrency,
                style: AppTextStyles.titleMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (rateStr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(rateStr, style: AppTextStyles.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WebCurrencyDropdown extends StatelessWidget {
  const _WebCurrencyDropdown({
    required this.label,
    required this.selected,
    required this.currencies,
    required this.onChanged,
  });

  final String label;
  final String selected;
  final List<String> currencies;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(selected),
      initialValue: selected,
      decoration: InputDecoration(labelText: label),
      items: currencies
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Row(
                children: [
                  Text(CurrencyService.currencyFlags[c] ?? '',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('$c — ${CurrencyService.currencyNames[c] ?? ''}'),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
