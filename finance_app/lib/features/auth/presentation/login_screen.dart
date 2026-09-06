import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_service.dart';
import '../domain/user_model.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _anyLoading => _isLoading || _isGoogleLoading;

  // ── Email login ────────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).loginWithEmail(
            _emailController.text.trim().toLowerCase(),
            _passwordController.text,
          );
      // GoRouter auth redirect handles navigation to dashboard automatically.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = AuthService.errorMessage(e.code));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  //
  // Creates a Firestore profile only on the first Google sign-in.
  // If a profile already exists (returning user), it is never overwritten.

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final credential =
          await ref.read(authServiceProvider).signInWithGoogle();
      final uid = credential.user!.uid;

      final existing =
          await ref.read(userServiceProvider).getUserProfile(uid);

      if (existing == null) {
        final now = DateTime.now();
        final profile = UserModel(
          uid: uid,
          name: credential.user!.displayName ?? 'User',
          email: (credential.user!.email ?? '').toLowerCase(),
          currency: '', // Set during CurrencySetupScreen
          monthlyIncome: 0,
          notificationsEnabled: true,
          darkModeEnabled: false,
          isDefaultDataInitialized: false,
          hasCompletedCurrencySetup: false,
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(userServiceProvider).createUserProfile(profile);
      }
      // Router automatically navigates to dashboard when auth state updates.
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign-in-cancelled') return;
      if (mounted) setState(() => _errorMessage = AuthService.errorMessage(e.code));
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: context.isMobile && context.isLandscape
                ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
                : context.responsivePadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.responsiveFormMaxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    Text(AppStrings.login, style: AppTextStyles.headlineLarge),
                    const SizedBox(height: 20),
                    _buildEmailField(),
                    const SizedBox(height: 14),
                    _buildPasswordField(),
                    const SizedBox(height: 4),
                    _buildForgotPassword(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                      label: AppStrings.login,
                      onPressed: _anyLoading ? null : _login,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 20),
                    const _OrDivider(),
                    const SizedBox(height: 20),
                    _GoogleButton(
                      onPressed: _anyLoading ? null : _signInWithGoogle,
                      isLoading: _isGoogleLoading,
                    ),
                    const SizedBox(height: 24),
                    _buildRegisterLink(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        const Icon(
          Icons.account_balance_wallet_rounded,
          size: 56,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.appName,
          style: AppTextStyles.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.appTagline,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: !_anyLoading,
      decoration: const InputDecoration(
        labelText: AppStrings.email,
        hintText: 'you@example.com',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Please enter your email.';
        final emailRegex =
            RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(v)) {
          return 'Please enter a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      enabled: !_anyLoading,
      onFieldSubmitted: (_) => _login(),
      decoration: InputDecoration(
        labelText: AppStrings.password,
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password.';
        }
        return null;
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _anyLoading
            ? null
            : () => context.go(RouteNames.forgotPassword),
        child: const Text(AppStrings.forgotPassword),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(AppStrings.dontHaveAccount, style: AppTextStyles.bodyMedium),
        TextButton(
          onPressed:
              _anyLoading ? null : () => context.go(RouteNames.register),
          child: const Text(AppStrings.register),
        ),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.expense, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.expense, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: AppTextStyles.labelLarge),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({this.onPressed, required this.isLoading});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GoogleIcon(),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
