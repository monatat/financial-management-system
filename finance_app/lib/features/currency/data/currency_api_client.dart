import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/currency_rate_model.dart';

/// Fetches live exchange rates from the Open Exchange Rates API.
///
/// API: https://open.er-api.com/v6/latest/{baseCurrency}
///
/// Free tier — no API key required. Rate limit: ~1,500 requests/month.
/// If the request fails (network error, rate limit, CORS), returns null.
/// The caller ([CurrencyService.getLatestRates]) falls back to Firestore cache.
class CurrencyApiClient {
  static const String _baseUrl = 'https://open.er-api.com/v6/latest';
  static const String _source = 'open.er-api.com';
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches the latest exchange rates for [baseCurrency].
  ///
  /// Returns null if the request fails for any reason (network error,
  /// non-200 response, invalid JSON, CORS block on web).
  Future<CurrencyRateModel?> fetchRates(String baseCurrency) async {
    try {
      final uri = Uri.parse('$_baseUrl/$baseCurrency');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['result'] != 'success') return null;

      final rawRates = data['rates'] as Map<String, dynamic>;
      final rates = rawRates.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );

      return CurrencyRateModel(
        baseCurrency: baseCurrency,
        rates: rates,
        fetchedAt: DateTime.now(),
        source: _source,
      );
    } catch (_) {
      return null;
    }
  }
}
