import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Storage keys ──────────────────────────────────────────────────────────────

/// Current key — stores a bool.
const _kDarkModeKey = 'app_dark_mode';

/// Legacy key from Phase 20.1 (3-option enum as string).
/// Read once for migration, then removed.
const _kLegacyKey = 'app_appearance';

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Stores the Dark Mode on/off preference in [SharedPreferences].
///
/// Default: **false** (Light Mode).  The app never follows the system theme.
///
/// Migration: if the legacy "app_appearance" key exists:
///   • "dark"  → true
///   • anything else → false
/// The legacy key is removed after migration.
class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadStored();
    return false; // Default: Light Mode while prefs load
  }

  Future<void> _loadStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Try the current bool key.
      final saved = prefs.getBool(_kDarkModeKey);
      if (saved != null) {
        state = saved;
        return;
      }

      // 2. Migrate from Phase 20.1 legacy string key.
      final legacy = prefs.getString(_kLegacyKey);
      if (legacy != null) {
        final isDark = legacy == 'dark';
        state = isDark;
        await prefs.setBool(_kDarkModeKey, isDark);
        await prefs.remove(_kLegacyKey);
        return;
      }

      // 3. First launch — use Light Mode.
      state = false;
    } catch (_) {
      // Storage failure is non-critical; stay on the default.
    }
  }

  /// Persists [enabled] and updates the reactive state immediately.
  Future<void> setDarkMode(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDarkModeKey, enabled);
    } catch (_) {
      // Persist failure is non-critical; in-memory state is already updated.
    }
  }
}

/// Global provider — watched by [FinanceApp] for [ThemeMode] and by the
/// Profile screen for the current toggle value.
final appearanceProvider =
    NotifierProvider<DarkModeNotifier, bool>(DarkModeNotifier.new);
