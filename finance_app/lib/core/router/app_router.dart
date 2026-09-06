import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../widgets/app_shell.dart';
import '../widgets/responsive_layout.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/currency_setup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/export/presentation/export_screen.dart';
import '../../features/dashboard/presentation/mobile/mobile_dashboard_screen.dart';
import '../../features/dashboard/presentation/web/web_dashboard_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/budget/presentation/budget_screen.dart';
import '../../features/saving_goals/presentation/saving_goals_screen.dart';
import '../../features/debts/presentation/debt_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/currency/presentation/mobile/currency_converter_screen.dart';
import '../../features/currency/presentation/web/currency_dashboard_screen.dart';
import '../../features/ai_assistant/presentation/ai_assistant_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

// ── Router notifier ───────────────────────────────────────────────────────────
//
// RouterNotifier extends ChangeNotifier so it can be passed to GoRouter's
// refreshListenable. Each time the auth state changes (login / logout),
// notifyListeners() is called, which causes GoRouter to re-run redirect().

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    // Re-evaluate redirects when Firebase auth state changes.
    ref.listen<AsyncValue<User?>>(
      authStateChangesProvider,
      (previous, next) => notifyListeners(),
    );
    // Re-evaluate redirects when the Firestore profile changes.
    // This fires when the user completes currency setup, so the router
    // can immediately allow access to the dashboard.
    ref.listen<AsyncValue<UserModel?>>(
      userProfileStreamProvider,
      (previous, next) => notifyListeners(),
    );
    _ref = ref;
  }

  late final Ref _ref;

  /// Three-state redirect logic:
  ///
  ///  State 1 — Not logged in
  ///    → Allow public routes (/login, /register, /forgot-password).
  ///    → All other routes → /login.
  ///
  ///  State 2 — Logged in, currency setup NOT complete
  ///    → Allow /currency-setup only.
  ///    → All other routes → /currency-setup.
  ///
  ///  State 3 — Logged in, currency setup complete
  ///    → Redirect away from auth/setup screens → /dashboard.
  ///    → Allow all app routes.
  ///
  ///  Setup is considered complete when users/{uid}.currency is not empty.
  ///  This handles backward-compat: existing users with "MYR" already set
  ///  are treated as complete even if hasCompletedCurrencySetup is false.
  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateChangesProvider);

    // Still resolving Firebase session — wait.
    if (authState.isLoading) return null;

    final isLoggedIn = authState.asData?.value != null;
    final path = state.uri.path;

    const publicRoutes = {
      RouteNames.login,
      RouteNames.register,
      RouteNames.forgotPassword,
    };

    final isOnPublicRoute = publicRoutes.contains(path);
    final isOnSetupRoute = path == RouteNames.currencySetup;

    // ── State 1: Not logged in ────────────────────────────────────────────
    if (!isLoggedIn) {
      if (isOnPublicRoute) return null;
      return RouteNames.login;
    }

    // ── States 2 & 3: Logged in — check Firestore profile ─────────────────
    final profileState = _ref.read(userProfileStreamProvider);

    // Profile stream still loading → don't redirect yet.
    if (profileState.isLoading) return null;

    final profile = profileState.asData?.value;

    // Profile document not yet available (race after registration) → wait.
    if (profile == null) return null;

    // Backward-compatible check: any non-empty currency = setup complete.
    final setupComplete = profile.currency.isNotEmpty;

    // ── State 2: Setup incomplete ─────────────────────────────────────────
    if (!setupComplete) {
      if (isOnSetupRoute) return null;        // Already on setup screen
      return RouteNames.currencySetup;        // Force to setup
    }

    // ── State 3: Setup complete ───────────────────────────────────────────
    if (isOnPublicRoute || isOnSetupRoute) return RouteNames.dashboard;
    return null; // Allow all app routes
  }
}

// ── Router provider ───────────────────────────────────────────────────────────
//
// appRouterProvider creates the GoRouter once and keeps it alive for the
// lifetime of the app. The router uses _RouterNotifier as its refreshListenable
// so it re-evaluates redirect() whenever auth state changes.

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: RouteNames.login,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    debugLogDiagnostics: true,
    routes: _routes,
  );

  ref.onDispose(router.dispose);
  ref.onDispose(notifier.dispose);
  return router;
});

// ── Route definitions ─────────────────────────────────────────────────────────

final List<RouteBase> _routes = [
  // Auth routes — no navigation shell
  GoRoute(
    path: RouteNames.login,
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: RouteNames.register,
    builder: (context, state) => const RegisterScreen(),
  ),
  GoRoute(
    path: RouteNames.forgotPassword,
    builder: (context, state) => const ForgotPasswordScreen(),
  ),
  GoRoute(
    path: RouteNames.currencySetup,
    builder: (context, state) => const CurrencySetupScreen(),
  ),
  // Export — full-screen, no navigation shell
  GoRoute(
    path: RouteNames.export,
    builder: (context, state) => const ExportScreen(),
  ),

  // Authenticated routes — wrapped in AppShell (bottom nav / rail)
  ShellRoute(
    builder: (context, state, child) => AppShell(
      currentRoute: state.uri.path,
      child: child,
    ),
    routes: [
      GoRoute(
        path: RouteNames.dashboard,
        pageBuilder: (context, state) => _fade(
          state,
          // Both dashboard screens provide their own Scaffold and AppBar,
          // so they are NOT wrapped in _NamedScaffold.
          const ResponsiveLayout(
            mobile: MobileDashboardScreen(),
            web: WebDashboardScreen(),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.transactions,
        pageBuilder: (context, state) => _fade(
          state,
          // TransactionsScreen has its own Scaffold with a month-navigation
          // AppBar, so it is NOT wrapped in _NamedScaffold here.
          const TransactionsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.budget,
        pageBuilder: (context, state) => _fade(
          state,
          // BudgetScreen has its own Scaffold with month-navigation AppBar.
          const BudgetScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.savingGoals,
        pageBuilder: (context, state) => _fade(
          state,
          // SavingGoalsScreen has its own Scaffold and AppBar.
          const SavingGoalsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.debts,
        pageBuilder: (context, state) => _fade(
          state,
          // DebtScreen has its own Scaffold and AppBar.
          const DebtScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.categories,
        pageBuilder: (context, state) => _fade(
          state,
          const _NamedScaffold(title: 'Categories', body: CategoriesScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.reports,
        pageBuilder: (context, state) => _fade(
          state,
          // ReportsScreen has its own Scaffold with month-navigation AppBar.
          const ReportsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.currency,
        pageBuilder: (context, state) => _fade(
          state,
          // Both screens provide their own Scaffold and AppBar.
          const ResponsiveLayout(
            mobile: CurrencyConverterScreen(),
            web: CurrencyDashboardScreen(),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.aiAssistant,
        pageBuilder: (context, state) => _fade(
          state,
          // AiAssistantScreen has its own Scaffold and AppBar.
          const AiAssistantScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.profile,
        pageBuilder: (context, state) => _fade(
          state,
          const _NamedScaffold(title: 'Profile', body: ProfileScreen()),
        ),
      ),
    ],
  ),
];

// ── Helpers ───────────────────────────────────────────────────────────────────

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Provides an AppBar with [title] for each shell route's content.
class _NamedScaffold extends StatelessWidget {
  const _NamedScaffold({required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
