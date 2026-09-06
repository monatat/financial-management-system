import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Visual variant controlling which [AppTypography] money style is applied.
enum MoneyVariant {
  /// [AppTypography.moneySmall] — list rows, secondary amounts.
  small,

  /// [AppTypography.money] — standard card and form amounts.
  normal,

  /// [AppTypography.moneyLarge] — KPI totals, dashboard hero values.
  large,
}

/// Displays a monetary amount with consistent typography and optional
/// sign-based colouring.
///
/// All money styles include [FontFeature.tabularFigures] so digits remain
/// equal-width across a column regardless of the number of characters.
///
/// Example:
/// ```dart
/// MoneyText(amount: 1234.50, currency: 'MYR')
/// MoneyText(amount: -250.00, currency: 'MYR', colorSign: true, showSign: true)
/// MoneyText(amount: 1500000, currency: 'MYR', compact: true, variant: MoneyVariant.large)
/// ```
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amount,
    this.currency = 'MYR',
    this.variant = MoneyVariant.normal,
    this.colorSign = false,
    this.showSign = false,
    this.compact = false,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// The monetary value to display.
  final double amount;

  /// ISO 4217 currency code prepended to the formatted number (e.g. "MYR").
  final String currency;

  /// Typography scale: [MoneyVariant.small], [.normal] (default), or [.large].
  final MoneyVariant variant;

  /// If true, positive amounts use [AppColors.success] and negative amounts
  /// use [AppColors.danger]. Neutral (zero) uses [AppColors.textPrimary].
  final bool colorSign;

  /// If true, a leading '+' is prepended for positive amounts.
  /// Negative amounts always show '-'.
  final bool showSign;

  /// If true, large values are abbreviated:
  ///   1 200       → "MYR 1.2K"
  ///   1 500 000   → "MYR 1.5M"
  ///   2 000 000 000 → "MYR 2.0B"
  final bool compact;

  /// Merge on top of the variant base style. Useful to override font weight
  /// or size without losing the tabular-figures feature.
  final TextStyle? style;

  /// Override the resolved colour. Takes precedence over [colorSign].
  final Color? color;

  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  // ── Private helpers ──────────────────────────────────────────────────────

  TextStyle get _baseStyle {
    switch (variant) {
      case MoneyVariant.small:
        return AppTypography.moneySmall;
      case MoneyVariant.large:
        return AppTypography.moneyLarge;
      case MoneyVariant.normal:
        return AppTypography.money;
    }
  }

  Color _resolvedColor() {
    if (color != null) return color!;
    if (colorSign) {
      if (amount > 0) return AppColors.success;
      if (amount < 0) return AppColors.danger;
    }
    return AppColors.textPrimary;
  }

  String get _formatted {
    final abs = amount.abs();
    final String numStr;

    if (compact) {
      if (abs >= 1e9) {
        numStr = '${(abs / 1e9).toStringAsFixed(1)}B';
      } else if (abs >= 1e6) {
        numStr = '${(abs / 1e6).toStringAsFixed(1)}M';
      } else if (abs >= 1e3) {
        numStr = '${(abs / 1e3).toStringAsFixed(1)}K';
      } else {
        numStr = abs.toStringAsFixed(2);
      }
    } else {
      numStr = abs.toStringAsFixed(2);
    }

    if (amount < 0) return '-$currency $numStr';
    if (showSign && amount > 0) return '+$currency $numStr';
    return '$currency $numStr';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _baseStyle.merge(style).copyWith(color: _resolvedColor());
    return Text(
      _formatted,
      style: resolved,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
