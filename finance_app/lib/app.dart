import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/settings/appearance_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // appRouterProvider creates GoRouter once and keeps it alive.
    // The router automatically redirects based on auth state changes.
    final router = ref.watch(appRouterProvider);
    final isDark = ref.watch(appearanceProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
