class RouteNames {
  RouteNames._();

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // First-time setup (requires login, before app access)
  static const String currencySetup = '/currency-setup';

  // Export (full-screen, no navigation shell)
  static const String export = '/export';

  // Category sub-screens (no navigation shell — shown full-screen)
  static const String categoryAdd = '/categories/add';
  static String categoryEdit(String id) => '/categories/$id/edit';
  static String categoryPresets(String id) => '/categories/$id/presets';

  // Main shell
  static const String dashboard = '/dashboard';
  static const String transactions = '/transactions';
  static const String budget = '/budget';
  static const String savingGoals = '/saving-goals';
  static const String debts = '/debts';
  static const String categories = '/categories';
  static const String reports = '/reports';
  static const String currency = '/currency';
  static const String aiAssistant = '/ai-assistant';
  static const String profile = '/profile';
}
