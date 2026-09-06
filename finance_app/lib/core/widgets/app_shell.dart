import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import '../responsive/responsive_breakpoints.dart';
import '../router/route_names.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/categories/presentation/category_provider.dart';
import 'responsive_layout.dart';

// ── Nav item model ────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.mobileLabel,
  });

  final String label;

  /// Short label for the horizontally-scrollable mobile bottom bar.
  /// Falls back to [label] when null.
  final String? mobileLabel;

  final IconData icon;
  final IconData selectedIcon;
  final String route;

  String get effectiveMobileLabel => mobileLabel ?? label;
}

// ── Nav items ─────────────────────────────────────────────────────────────────

const List<_NavItem> _navItems = [
  _NavItem(
    label: AppStrings.navDashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    route: RouteNames.dashboard,
  ),
  _NavItem(
    label: AppStrings.navTransactions,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    route: RouteNames.transactions,
  ),
  _NavItem(
    label: AppStrings.navBudget,
    icon: Icons.pie_chart_outline_rounded,
    selectedIcon: Icons.pie_chart_rounded,
    route: RouteNames.budget,
  ),
  _NavItem(
    label: AppStrings.navSavingGoals,
    mobileLabel: 'Goals',
    icon: Icons.savings_outlined,
    selectedIcon: Icons.savings_rounded,
    route: RouteNames.savingGoals,
  ),
  _NavItem(
    label: AppStrings.navDebts,
    mobileLabel: 'Debt',
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance_rounded,
    route: RouteNames.debts,
  ),
  _NavItem(
    label: AppStrings.navCategories,
    icon: Icons.category_outlined,
    selectedIcon: Icons.category_rounded,
    route: RouteNames.categories,
  ),
  _NavItem(
    label: AppStrings.navReports,
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics_rounded,
    route: RouteNames.reports,
  ),
  _NavItem(
    label: AppStrings.navCurrency,
    icon: Icons.currency_exchange_outlined,
    selectedIcon: Icons.currency_exchange_rounded,
    route: RouteNames.currency,
  ),
  _NavItem(
    label: AppStrings.navAiAssistant,
    mobileLabel: 'AI',
    icon: Icons.smart_toy_outlined,
    selectedIcon: Icons.smart_toy_rounded,
    route: RouteNames.aiAssistant,
  ),
  _NavItem(
    label: AppStrings.navProfile,
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    route: RouteNames.profile,
  ),
];

// ── AppShell ──────────────────────────────────────────────────────────────────

/// The top-level shell that wraps all authenticated screens.
///
/// Responsive navigation strategy:
///   < 900 px  : horizontally-scrollable bottom bar — all 10 items, no overflow
///   900–1199 px: compact [_ScrollableRail], icons + tooltip, vertically scrollable
///   ≥ 1200 px : extended [_ScrollableRail], icon + label, vertically scrollable
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  final Widget child;
  final String currentRoute;

  int get _selectedIndex {
    final idx = _navItems.indexWhere((item) => item.route == currentRoute);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateChangesProvider).asData?.value?.uid;

    if (uid != null) {
      final seedState = ref.watch(seedingProvider(uid));
      if (seedState.isLoading) {
        return const _SeedingScreen();
      }
    }

    return ResponsiveLayout(
      mobile: _MobileShell(
        currentRoute: currentRoute,
        selectedIndex: _selectedIndex,
        child: child,
      ),
      web: _WebShell(
        currentRoute: currentRoute,
        selectedIndex: _selectedIndex,
        child: child,
      ),
    );
  }
}

// ── Seeding overlay ───────────────────────────────────────────────────────────

class _SeedingScreen extends StatelessWidget {
  const _SeedingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              'Setting up your account…',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile shell ──────────────────────────────────────────────────────────────

/// Mobile layout: Scaffold body + horizontally scrollable bottom navigation.
///
/// All [_navItems] are shown in a [SingleChildScrollView] so the user can
/// reach every section regardless of screen width or orientation.
/// The selected item gets a primary-colour pill background.
class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.child,
    required this.currentRoute,
    required this.selectedIndex,
  });

  final Widget child;
  final String currentRoute;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _ScrollableBottomNav(
        selectedIndex: selectedIndex,
        onItemSelected: (i) => context.go(_navItems[i].route),
      ),
    );
  }
}

// ── Scrollable bottom navigation ──────────────────────────────────────────────

class _ScrollableBottomNav extends StatelessWidget {
  const _ScrollableBottomNav({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final void Function(int) onItemSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: List.generate(_navItems.length, (i) {
                return _BottomNavItem(
                  item: _navItems[i],
                  selected: i == selectedIndex,
                  onTap: () => onItemSelected(i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurface.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pill indicator for selected state
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: selected
                  ? BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.effectiveMobileLabel,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Web shell ─────────────────────────────────────────────────────────────────

/// Web/desktop layout: Scaffold body = scrollable rail + divider + content.
///
/// The custom [_ScrollableRail] replaces [NavigationRail] so that the
/// destinations are wrapped in a [SingleChildScrollView].  This prevents
/// overflow on small-height windows (e.g. 900×500) while keeping the same
/// visual style at both compact (900–1199 px) and extended (≥ 1200 px) widths.
class _WebShell extends StatelessWidget {
  const _WebShell({
    required this.child,
    required this.currentRoute,
    required this.selectedIndex,
  });

  final Widget child;
  final String currentRoute;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final extended =
        screenWidth >= ResponsiveBreakpoints.navExtendedBreakpoint;

    return Scaffold(
      body: Row(
        children: [
          _ScrollableRail(
            selectedIndex: selectedIndex,
            extended: extended,
            onDestinationSelected: (i) => context.go(_navItems[i].route),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Scrollable side rail ──────────────────────────────────────────────────────

/// Custom navigation rail that wraps its destinations in a
/// [SingleChildScrollView], preventing vertical overflow on small windows.
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({
    required this.selectedIndex,
    required this.extended,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool extended;
  final void Function(int) onDestinationSelected;

  // Width constants matching the original NavigationRail behaviour.
  static const double _compactWidth = 72;
  static const double _extendedWidth = 256;

  @override
  Widget build(BuildContext context) {
    final width = extended ? _extendedWidth : _compactWidth;
    final cs = Theme.of(context).colorScheme;
    final bgColor = Theme.of(context).navigationRailTheme.backgroundColor ??
        cs.surface;
    final brandColor = cs.primary;

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: bgColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Leading: app logo / name ─────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: extended ? 8 : 0,
              ),
              child: extended
                  ? Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 24,
                          color: brandColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppStrings.appName,
                          style: AppTextStyles.titleLarge
                              .copyWith(color: brandColor),
                        ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 28,
                        color: brandColor,
                      ),
                    ),
            ),

            // ── Scrollable destination list ──────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(_navItems.length, (i) {
                    return _RailDestination(
                      item: _navItems[i],
                      selected: i == selectedIndex,
                      extended: extended,
                      onTap: () => onDestinationSelected(i),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rail destination item ─────────────────────────────────────────────────────

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color =
        selected ? cs.primary : cs.onSurface.withValues(alpha: 0.55);

    if (extended) {
      // Extended rail: icon + label in a ListTile-style row
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Compact rail: icon only with tooltip
    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 52,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: selected
                  ? BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
