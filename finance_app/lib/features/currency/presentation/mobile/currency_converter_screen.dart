import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/responsive/responsive_helpers.dart';
import '../../../../core/widgets/app_card.dart';
import '../currency_provider.dart';
import '../../data/currency_service.dart';

class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState
    extends ConsumerState<CurrencyConverterScreen> {
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

  void _swapCurrencies() {
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
    });
  }

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
    final supported = ref.read(currencyServiceProvider).getSupportedCurrencies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh rates',
            onPressed: () => ref.invalidate(currencyRatesProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Amount input ─────────────────────────────────────────────
            Text('Amount', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: AppTextStyles.amountLarge,
              decoration: const InputDecoration(
                hintText: '0',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 20),

            // ── Currency selector row ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _CurrencyDropdown(
                    label: 'From',
                    selected: _fromCurrency,
                    currencies: supported,
                    onChanged: (v) => setState(() => _fromCurrency = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton.filled(
                    onPressed: _swapCurrencies,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    tooltip: 'Swap currencies',
                  ),
                ),
                Expanded(
                  child: _CurrencyDropdown(
                    label: 'To',
                    selected: _toCurrency,
                    currencies: supported,
                    onChanged: (v) => setState(() => _toCurrency = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Result ────────────────────────────────────────────────────
            ratesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorResult(),
              data: (ratesModel) {
                if (ratesModel == null) return _ErrorResult();

                final inputAmount =
                    double.tryParse(_amountController.text.trim());
                final result = inputAmount != null
                    ? CurrencyService.convertWithRates(
                        inputAmount,
                        _fromCurrency,
                        _toCurrency,
                        ratesModel.rates,
                      )
                    : null;

                final rateStr = CurrencyService.rateDisplay(
                  ratesModel.rates,
                  _fromCurrency,
                  _toCurrency,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            result != null
                                ? CurrencyService.formatAmount(result)
                                : '—',
                            style: AppTextStyles.amountLarge.copyWith(
                              color: AppColors.primary,
                              fontSize: 36,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _toCurrency,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          if (rateStr.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Text(
                              rateStr,
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38)),
                        const SizedBox(width: 4),
                        Text(
                          'Rates updated: '
                          '${_formatLastUpdated(ratesModel.fetchedAt)}',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.38)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── All rates vs MYR ─────────────────────────────────
                    Text('All rates vs MYR',
                        style: AppTextStyles.titleMedium),
                    const SizedBox(height: 8),
                    ...supported
                        .where((c) => c != 'MYR')
                        .map((code) => _RateChip(
                              code: code,
                              rates: ratesModel.rates,
                            )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Currency dropdown ─────────────────────────────────────────────────────────

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: currencies
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Text(
                        CurrencyService.currencyFlags[c] ?? '',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(c, style: AppTextStyles.titleMedium),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

// ── Rate chip row ─────────────────────────────────────────────────────────────

class _RateChip extends StatelessWidget {
  const _RateChip({required this.code, required this.rates});

  final String code;
  final Map<String, double> rates;

  @override
  Widget build(BuildContext context) {
    final rate = rates[code];
    if (rate == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(
              CurrencyService.currencyFlags[code] ?? '',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code, style: AppTextStyles.titleMedium),
                  Text(
                    CurrencyService.currencyNames[code] ?? '',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              CurrencyService.formatAmount(rate),
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.expense.withValues(alpha: 0.3),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 36,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.38)),
          const SizedBox(height: 12),
          Text(
            'Exchange rates unavailable',
            style: AppTextStyles.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your internet connection and tap the refresh button.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
