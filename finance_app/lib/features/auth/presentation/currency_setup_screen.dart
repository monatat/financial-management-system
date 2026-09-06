import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_provider.dart';

/// Shown once after registration or first login.
///
/// Forces the user to choose a base currency before they can access the app.
/// After a valid selection the [UserService.completeCurrencySetup] function
/// updates Firestore and the router automatically redirects to the dashboard.
class CurrencySetupScreen extends ConsumerStatefulWidget {
  const CurrencySetupScreen({super.key});

  @override
  ConsumerState<CurrencySetupScreen> createState() =>
      _CurrencySetupScreenState();
}

class _CurrencySetupScreenState extends ConsumerState<CurrencySetupScreen> {
  String? _selectedCurrency;
  bool _isLoading = false;
  String? _errorMessage;

  // All supported currencies: (code, flag, name)
  static const _currencies = [
    ('MYR', '🇲🇾', 'Malaysian Ringgit'),
    ('USD', '🇺🇸', 'US Dollar'),
    ('SGD', '🇸🇬', 'Singapore Dollar'),
    ('EUR', '🇪🇺', 'Euro'),
    ('GBP', '🇬🇧', 'British Pound'),
    ('JPY', '🇯🇵', 'Japanese Yen'),
    ('CNY', '🇨🇳', 'Chinese Yuan'),
    ('AUD', '🇦🇺', 'Australian Dollar'),
  ];

  Future<void> _continue() async {
    if (_selectedCurrency == null) return;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(userServiceProvider)
          .completeCurrencySetup(uid, _selectedCurrency!);

      // The userProfileStreamProvider will emit the updated profile.
      // The router detects currency.isNotEmpty → redirects to /dashboard.
      // No explicit navigation is needed here.
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not save your selection. Please try again.';
        });
      }
    }
    // Do NOT set isLoading = false on success: the screen will be replaced
    // by the router redirect before the user notices it.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: context.isMobile && context.isLandscape
                    ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
                    : context.responsivePadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.responsiveFormMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),

                      // Icon
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.currency_exchange_rounded,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Choose Your Base Currency',
                        style: AppTextStyles.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Explanation
                      Text(
                        'This currency will be used as the default for your '
                        'budgets, transactions, goals, and reports.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Currency options
                      ...(_currencies.map(
                        (entry) {
                          final (code, flag, name) = entry;
                          final isSelected = _selectedCurrency == code;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CurrencyOption(
                              code: code,
                              flag: flag,
                              name: name,
                              isSelected: isSelected,
                              enabled: !_isLoading,
                              onTap: () =>
                                  setState(() => _selectedCurrency = code),
                            ),
                          );
                        },
                      )),

                      // Error
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.expense
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.expense),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Continue button — fixed at bottom
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.responsivePaddingValue,
                12,
                context.responsivePaddingValue,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.responsiveFormMaxWidth),
                child: AppButton(
                  label: 'Continue',
                  onPressed:
                      (_selectedCurrency == null || _isLoading) ? null : _continue,
                  isLoading: _isLoading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Currency option card ──────────────────────────────────────────────────────

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.code,
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String code;
  final String flag;
  final String name;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Text(flag, style: const TextStyle(fontSize: 28)),
        title: Text(code, style: AppTextStyles.titleMedium),
        subtitle: Text(name, style: AppTextStyles.bodySmall),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.primary)
            : const Icon(Icons.radio_button_unchecked_rounded,
                color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
