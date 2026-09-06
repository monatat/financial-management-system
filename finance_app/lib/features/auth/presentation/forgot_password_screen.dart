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
import 'auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  /// Switches the view from the input form to the success confirmation.
  bool _emailSent = false;

  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ── Action ─────────────────────────────────────────────────────────────────

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(
            _emailController.text.trim().toLowerCase(),
          );
      // Show success state — no navigation, keeps the email visible for reference.
      if (mounted) setState(() => _emailSent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = AuthService.resetPasswordErrorMessage(e.code));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            'Unable to send password reset email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              child: _emailSent ? _buildSuccessState() : _buildFormState(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form state (before sending) ────────────────────────────────────────────

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _buildBackButton(),
          const SizedBox(height: 16),
          _buildIcon(),
          const SizedBox(height: 20),
          Text('Forgot Password', style: AppTextStyles.displayMedium),
          const SizedBox(height: 10),
          Text(
            'Enter your registered email address and we will send you a password reset link.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          _buildEmailField(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Send Reset Link',
            onPressed: _isLoading ? null : _sendResetEmail,
            isLoading: _isLoading,
            icon: Icons.send_rounded,
          ),
          const SizedBox(height: 20),
          _buildBackToLoginLink(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Success state (after sending) ──────────────────────────────────────────

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),

        // Success icon
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 44,
              color: AppColors.income,
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Email Sent!',
          style: AppTextStyles.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        Text(
          'Password reset email sent. Please check your inbox and follow the link to reset your password.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          "Didn't receive it? Check your spam or junk folder.",
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Show which email was used so the user can confirm
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                _emailController.text.trim().toLowerCase(),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        AppButton(
          label: 'Back to Login',
          onPressed: () => context.go(RouteNames.login),
          icon: Icons.arrow_back_rounded,
        ),
        const SizedBox(height: 16),

        // Allow re-sending if the email didn't arrive
        Center(
          child: TextButton(
            onPressed: () => setState(() => _emailSent = false),
            child: Text(
              'Try a different email address',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _buildIcon() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lock_reset_rounded,
          size: 36,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed:
              _isLoading ? null : () => context.go(RouteNames.login),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      enabled: !_isLoading,
      onFieldSubmitted: (_) => _sendResetEmail(),
      decoration: const InputDecoration(
        labelText: AppStrings.email,
        hintText: 'you@example.com',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Please enter your email address.';
        final emailRegex =
            RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(v)) {
          return 'Please enter a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _buildBackToLoginLink() {
    return Center(
      child: TextButton.icon(
        onPressed: _isLoading ? null : () => context.go(RouteNames.login),
        icon: const Icon(Icons.arrow_back_rounded, size: 16),
        label: const Text('Back to Login'),
      ),
    );
  }
}

// ── Error banner widget ───────────────────────────────────────────────────────

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
