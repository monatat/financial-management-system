import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/currency_api_client.dart';
import '../data/currency_service.dart';
import '../domain/currency_rate_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService(FirebaseFirestore.instance, CurrencyApiClient());
});

// ── Rates provider ─────────────────────────────────────────────────────────────

/// Loads the latest MYR-base exchange rates.
///
/// On first mount: checks Firestore cache → fetches API if cache is stale.
/// autoDispose: provider is recreated on next mount (may pick up fresh rates).
///
/// A [_refreshKey] lets the UI force a re-fetch by calling
/// `ref.invalidate(currencyRatesProvider)`.
final currencyRatesProvider =
    FutureProvider.autoDispose<CurrencyRateModel?>((ref) async {
  return ref.read(currencyServiceProvider).getLatestRates('MYR');
});
