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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // Tracks whether to show the live password requirements panel.
  bool _showPasswordRequirements = false;

  @override
  void initState() {
    super.initState();
    // Show password requirements as soon as the user starts typing.
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final show = _passwordController.text.isNotEmpty;
    if (show != _showPasswordRequirements) {
      setState(() => _showPasswordRequirements = show);
    } else {
      // Still rebuild so requirement indicators update.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _anyLoading => _isLoading || _isGoogleLoading;

  // ── Email registration flow ────────────────────────────────────────────────
  //
  // 1. Validate form.
  // 2. Create Firebase Auth account.
  // 3. Create Firestore user profile with isDefaultDataInitialized: false.
  // 4. Roll back auth account if Firestore write fails.
  // 5. GoRouter redirect handles navigation to dashboard.

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    UserCredential? credential;

    try {
      credential = await ref.read(authServiceProvider).registerWithEmail(
            _emailController.text.trim().toLowerCase(),
            _passwordController.text,
          );

      final now = DateTime.now();
      final profile = UserModel(
        uid: credential.user!.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
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
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = AuthService.errorMessage(e.code));
    } catch (e) {
      // Firestore write failed — delete the auth account so the user can retry.
      try {
        await credential?.user?.delete();
      } catch (_) {}
      if (mounted) {
        setState(() => _errorMessage = 'Registration failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google sign-in flow ────────────────────────────────────────────────────
  //
  // 1. Authenticate with Google.
  // 2. Check if Firestore profile already exists.
  // 3. Create profile only if it doesn't exist (never overwrite).
  // 4. GoRouter redirect handles navigation to dashboard.

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
      // If profile exists, do not overwrite — user is already set up.
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign-in-cancelled') return; // silent cancel
      if (mounted) setState(() => _errorMessage = AuthService.errorMessage(e.code));
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Google sign-in failed. Please try again.');
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
                ? const EdgeInsets.symmetric(horizontal: 20, vertical: 4)
                : context.responsivePadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.responsiveFormMaxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBackButton(),
                    const SizedBox(height: 8),
                    Text(AppStrings.register, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Create your free account',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 28),

                    // ── Fields ──────────────────────────────────────────────
                    _buildNameField(),
                    const SizedBox(height: 14),
                    _buildEmailField(),
                    const SizedBox(height: 14),
                    _buildPasswordField(),

                    // Password requirements panel — shown while typing
                    if (_showPasswordRequirements) ...[
                      const SizedBox(height: 8),
                      _PasswordRequirementsPanel(
                        password: _passwordController.text,
                      ),
                    ],

                    const SizedBox(height: 14),
                    _buildConfirmPasswordField(),

                    // Error banner
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _errorMessage!),
                    ],

                    const SizedBox(height: 20),

                    // ── Register button ──────────────────────────────────────
                    AppButton(
                      label: AppStrings.register,
                      onPressed: _anyLoading ? null : _register,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 20),

                    // ── Divider ──────────────────────────────────────────────
                    const _OrDivider(),
                    const SizedBox(height: 20),

                    // ── Google button ────────────────────────────────────────
                    _GoogleButton(
                      onPressed: _anyLoading ? null : _signInWithGoogle,
                      isLoading: _isGoogleLoading,
                    ),

                    const SizedBox(height: 24),

                    // ── Login link ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppStrings.alreadyHaveAccount,
                            style: AppTextStyles.bodyMedium),
                        TextButton(
                          onPressed: _anyLoading
                              ? null
                              : () => context.go(RouteNames.login),
                          child: const Text(AppStrings.login),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Field builders ─────────────────────────────────────────────────────────

  Widget _buildBackButton() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _anyLoading ? null : () => context.go(RouteNames.login),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      enabled: !_anyLoading,
      decoration: const InputDecoration(
        labelText: AppStrings.fullName,
        hintText: 'Your full name',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Please enter your name.';
        if (v.length < 3) return 'Name must be at least 3 characters.';
        if (v.length > 50) return 'Name must be 50 characters or less.';
        if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v)) {
          return 'Name can only contain letters and spaces.';
        }
        return null;
      },
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
        if (!emailRegex.hasMatch(v)) return 'Please enter a valid email address.';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.next,
      enabled: !_anyLoading,
      decoration: InputDecoration(
        labelText: AppStrings.password,
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        final v = value ?? '';
        if (v.isEmpty) return 'Please enter a password.';
        if (v.length < 8) return 'Password must be at least 8 characters.';
        if (v.length > 12) return 'Password must be 12 characters or less.';
        if (!v.contains(RegExp(r'[A-Z]'))) {
          return 'Password needs at least 1 uppercase letter.';
        }
        if (!v.contains(RegExp(r'[a-z]'))) {
          return 'Password needs at least 1 lowercase letter.';
        }
        if (!v.contains(RegExp(r'[0-9]'))) {
          return 'Password needs at least 1 number.';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      enabled: !_anyLoading,
      onFieldSubmitted: (_) => _register(),
      decoration: InputDecoration(
        labelText: AppStrings.confirmPassword,
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(_obscureConfirmPassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password.';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match.';
        }
        return null;
      },
    );
  }
}

// ── Shared small widgets used only within this file ───────────────────────────

/// Live password requirements panel shown while the user types their password.
class _PasswordRequirementsPanel extends StatelessWidget {
  const _PasswordRequirementsPanel({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final hasMin = password.length >= 8;
    final hasMax = password.length <= 12;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements',
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: 8),
          _RequirementRow(label: '8 to 12 characters', met: hasMin && hasMax),
          _RequirementRow(label: 'At least 1 uppercase letter (A–Z)', met: hasUpper),
          _RequirementRow(label: 'At least 1 lowercase letter (a–z)', met: hasLower),
          _RequirementRow(label: 'At least 1 number (0–9)', met: hasDigit),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? AppColors.income : AppColors.textDisabled,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met ? AppColors.income : AppColors.textSecondary,
              fontWeight: met ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

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
    // Simple "G" badge in Google's brand colours.
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4), // Google blue
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
