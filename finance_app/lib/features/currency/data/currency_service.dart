import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/currency_rate_model.dart';
import 'currency_api_client.dart';

/// Manages exchange rate fetching, caching, and conversion.
///
/// Strategy:
/// 1. If the Firestore cache is < 1 hour old → return cache (no API call).
/// 2. Otherwise → fetch from API and update cache.
/// 3. If API fails → return stale cache rather than showing an error.
/// 4. If both fail → return null (caller shows error state).
class CurrencyService {
  CurrencyService(this._firestore, this._apiClient);

  final FirebaseFirestore _firestore;
  final CurrencyApiClient _apiClient;

  static const Duration _cacheMaxAge = Duration(hours: 1);

  // ── Supported currencies ───────────────────────────────────────────────────

  static const List<String> _supported = [
    'MYR', 'USD', 'SGD', 'EUR', 'GBP', 'JPY', 'CNY', 'AUD',
  ];

  static const Map<String, String> currencyNames = {
    'MYR': 'Malaysian Ringgit',
    'USD': 'US Dollar',
    'SGD': 'Singapore Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'CNY': 'Chinese Yuan',
    'AUD': 'Australian Dollar',
  };

  static const Map<String, String> currencyFlags = {
    'MYR': '🇲🇾',
    'USD': '🇺🇸',
    'SGD': '🇸🇬',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'JPY': '🇯🇵',
    'CNY': '🇨🇳',
    'AUD': '🇦🇺',
  };

  /// Returns the list of supported ISO 4217 currency codes.
  List<String> getSupportedCurrencies() => List.unmodifiable(_supported);

  // ── Firestore cache ────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _cacheDoc(String base) =>
      _firestore.collection('currencyRates').doc(base);

  /// Reads cached rates for [baseCurrency] from Firestore.
  /// Returns null if no cache exists.
  Future<CurrencyRateModel?> getCachedRates(String baseCurrency) async {
    try {
      final doc = await _cacheDoc(baseCurrency).get();
      if (!doc.exists || doc.data() == null) return null;
      return CurrencyRateModel.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Stores [model] in Firestore for future offline use.
  Future<void> _saveCache(CurrencyRateModel model) async {
    try {
      await _cacheDoc(model.baseCurrency).set(model.toMap());
    } catch (_) {
      // Cache write failures are non-fatal
    }
  }

  // ── API fetch ──────────────────────────────────────────────────────────────

  /// Fetches live rates from the API and filters to supported currencies.
  /// Returns null if the request fails.
  Future<CurrencyRateModel?> fetchLatestRates(String baseCurrency) async {
    final model = await _apiClient.fetchRates(baseCurrency);
    if (model == null) return null;

    // Keep only the supported currencies
    final filtered = Map.fromEntries(
      model.rates.entries
          .where((e) => _supported.contains(e.key)),
    );

    return CurrencyRateModel(
      baseCurrency: model.baseCurrency,
      rates: filtered,
      fetchedAt: model.fetchedAt,
      source: model.source,
    );
  }

  // ── Primary entry point ────────────────────────────────────────────────────

  /// Returns the most up-to-date rates for [baseCurrency].
  ///
  /// Flow:
  /// 1. Cache is fresh (< 1 h old) → return cache without API call.
  /// 2. Cache is stale or missing → call API.
  ///    a. API succeeds → save to cache and return.
  ///    b. API fails   → return stale cache if available.
  ///    c. No cache    → return null (UI shows error).
  Future<CurrencyRateModel?> getLatestRates(String baseCurrency) async {
    final cached = await getCachedRates(baseCurrency);

    // Return fresh cache immediately (no network call needed)
    if (cached != null) {
      final age = DateTime.now().difference(cached.fetchedAt);
      if (age < _cacheMaxAge) return cached;
    }

    // Fetch from API
    final fresh = await fetchLatestRates(baseCurrency);
    if (fresh != null) {
      await _saveCache(fresh);
      return fresh;
    }

    // API failed — return stale cache or null
    return cached;
  }

  // ── Conversion ─────────────────────────────────────────────────────────────

  /// Converts [amount] from [from] to [to] by fetching the latest rates.
  ///
  /// Returns null if rates are unavailable or currencies unsupported.
  Future<double?> convertAmount(
    double amount,
    String from,
    String to,
  ) async {
    final ratesModel = await getLatestRates('MYR');
    if (ratesModel == null) return null;
    return convertWithRates(amount, from, to, ratesModel.rates);
  }

  /// Pure conversion with a pre-loaded [rates] map.
  ///
  /// All rates must be relative to the same base currency (MYR).
  /// Formula: amount / rates[from] * rates[to]
  ///
  /// Example (base = MYR, rates["USD"] = 0.21, rates["SGD"] = 0.28):
  ///   100 USD → MYR: 100 / 0.21 * 1.0 = 476.19
  ///   100 USD → SGD: 100 / 0.21 * 0.28 = 133.33
  static double? convertWithRates(
    double amount,
    String from,
    String to,
    Map<String, double> rates,
  ) {
    if (!rates.containsKey(from) || !rates.containsKey(to)) return null;
    final fromRate = rates[from]!;
    final toRate = rates[to]!;
    if (fromRate == 0) return null;
    return amount / fromRate * toRate;
  }

  // ── Display helpers ────────────────────────────────────────────────────────

  /// Returns the exchange rate string, e.g. "1 USD = 4.7234 MYR".
  static String rateDisplay(
    Map<String, double> rates,
    String from,
    String to,
  ) {
    if (!rates.containsKey(from) || !rates.containsKey(to)) return '';
    final fromRate = rates[from]!;
    final toRate = rates[to]!;
    if (fromRate == 0) return '';
    final rate = toRate / fromRate;
    return '1 $from = ${_smartFormat(rate)} $to';
  }

  /// Formats a currency amount with appropriate decimal places.
  static String formatAmount(double value) {
    if (value.abs() >= 10000) return value.toStringAsFixed(2);
    if (value.abs() >= 1) return value.toStringAsFixed(4);
    return value.toStringAsFixed(6);
  }

  static String _smartFormat(double v) {
    if (v.abs() >= 100) return v.toStringAsFixed(2);
    if (v.abs() >= 1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(6);
  }
}
