import 'package:cloud_firestore/cloud_firestore.dart';

/// Exchange rates relative to one base currency, with a cache timestamp.
///
/// Stored at: currencyRates/{baseCurrency}  (top-level, shared collection)
/// Example:   currencyRates/MYR
///
/// [rates] stores how much of each foreign currency equals 1 unit of
/// [baseCurrency]. E.g. with baseCurrency = "MYR":
///   rates["USD"] = 0.2123  →  1 MYR = 0.2123 USD
///   rates["MYR"] = 1.0     →  1 MYR = 1 MYR (base is always 1.0)
class CurrencyRateModel {
  const CurrencyRateModel({
    required this.baseCurrency,
    required this.rates,
    required this.fetchedAt,
    required this.source,
  });

  final String baseCurrency;

  /// Maps currency code → rate (relative to [baseCurrency]).
  final Map<String, double> rates;

  final DateTime fetchedAt;

  /// API provider name, e.g. "open.er-api.com".
  final String source;

  // ── Firestore serialization ────────────────────────────────────────────────

  factory CurrencyRateModel.fromMap(Map<String, dynamic> map) {
    final rawRates = map['rates'] as Map<String, dynamic>;
    final rates = rawRates.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );
    return CurrencyRateModel(
      baseCurrency: map['baseCurrency'] as String,
      rates: rates,
      fetchedAt: (map['fetchedAt'] as Timestamp).toDate(),
      source: map['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseCurrency': baseCurrency,
      'rates': rates,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
      'source': source,
    };
  }
}
