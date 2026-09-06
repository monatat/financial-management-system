/// AI-only helper models — never stored in Firestore, never sent to the UI.
///
/// Used by [AiAssistantService.buildFinancialContext] to build the context
/// payload that is serialized and sent to the Firebase Cloud Function.

// ── Monthly summary ───────────────────────────────────────────────────────────

class AiMonthlySummary {
  const AiMonthlySummary({
    required this.monthKey,
    required this.monthLabel,
    required this.income,
    required this.expense,
    required this.balance,
    required this.transactionCount,
    required this.savingsRate,
  });

  /// "YYYY-MM", e.g. "2026-05".
  final String monthKey;

  /// Full month name, e.g. "May 2026".
  final String monthLabel;

  final double income;
  final double expense;
  final double balance;
  final int transactionCount;

  /// Fraction of income retained: (income − expense) / income.
  /// 0.0 when income is zero.
  final double savingsRate;

  Map<String, dynamic> toMap() => {
        'monthKey': monthKey,
        'monthLabel': monthLabel,
        'income': income,
        'expense': expense,
        'balance': balance,
        'transactionCount': transactionCount,
        'savingsRatePercent': (savingsRate * 100).toStringAsFixed(1),
      };
}

// ── Saving goal summary ───────────────────────────────────────────────────────

class AiSavingGoalSummary {
  const AiSavingGoalSummary({
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.progressPercent,
    required this.status,
  });

  final String name;
  final double targetAmount;
  final double savedAmount;

  /// 0.0 – 100.0+ (may exceed 100 when over-saved).
  final double progressPercent;

  /// 'active' or 'completed'.
  final String status;

  Map<String, dynamic> toMap() => {
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'progressPercent': progressPercent.toStringAsFixed(1),
        'status': status,
      };
}

// ── Top expense category ──────────────────────────────────────────────────────

class AiTopCategory {
  const AiTopCategory({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  final String category;
  final double amount;

  /// Fraction of total current-month expenses (0.0 – 1.0).
  final double percentage;

  Map<String, dynamic> toMap() => {
        'category': category,
        'amount': amount,
        'percentageOfExpenses': (percentage * 100).toStringAsFixed(1),
      };
}

// ── Subscription entry ────────────────────────────────────────────────────────

class AiSubscriptionEntry {
  const AiSubscriptionEntry({
    required this.description,
    required this.monthlyAmount,
    required this.annualAmount,
    required this.status,
  });

  final String description;
  final double monthlyAmount;
  final double annualAmount;

  /// 'review' or 'notReviewed'.
  final String status;

  Map<String, dynamic> toMap() => {
        'description': description,
        'monthlyAmount': monthlyAmount,
        'annualAmount': annualAmount,
        'status': status,
      };
}

// ── Main context model ────────────────────────────────────────────────────────

/// A privacy-safe summarised snapshot of the user's financial position.
///
/// Contains ONLY aggregated numbers and compact lists — no raw transaction
/// records, no merchant names, no personal identifiers beyond anonymous totals.
/// It is safe to send to an external AI backend.
///
/// Built by [AiAssistantService.buildFinancialContext].
class FinancialContextModel {
  const FinancialContextModel({
    // ── Existing fields (preserved exactly) ──────────────────────────────────
    required this.month,
    required this.currency,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    this.topExpenseCategory,
    required this.topExpenseAmount,
    required this.budgetAllocated,
    required this.budgetSpent,
    required this.budgetRemaining,
    required this.savingGoalProgress,
    required this.totalDebtRemaining,
    required this.invisibleLeakageAmount,
    required this.lastSweepLeftoverAmount,
    required this.lastSweepAllocatedAmount,
    required this.lastSweepUnallocatedAmount,
    // ── New: monthly history ──────────────────────────────────────────────────
    required this.monthlyHistory,
    // ── New: current-month transaction insights ───────────────────────────────
    required this.transactionCount,
    required this.largestTransactionDescription,
    required this.largestTransactionAmount,
    required this.largestTransactionCategory,
    required this.topExpenseCategories,
    // ── New: saving goals expanded ────────────────────────────────────────────
    required this.savingGoalTotalTarget,
    required this.savingGoalTotalSaved,
    required this.activeGoalCount,
    required this.completedGoalCount,
    required this.savingGoals,
    // ── New: budget context ───────────────────────────────────────────────────
    required this.budgetUsagePercent,
    required this.overBudgetCategoryNames,
    required this.nearLimitCategoryNames,
    // ── New: debt context ─────────────────────────────────────────────────────
    required this.totalDebt,
    required this.totalDebtPaid,
    required this.debtRepaymentPercent,
    required this.activeDebtCount,
    // ── New: invisible expense context ────────────────────────────────────────
    required this.actionableAnnualLeakage,
    required this.detectedAnnualLeakage,
    required this.confirmedSubscriptionCount,
    required this.reviewSubscriptionCount,
    required this.ignoredSubscriptionCount,
    required this.notReviewedSubscriptionCount,
    required this.subscriptionsToReview,
  });

  // ── Existing fields ────────────────────────────────────────────────────────

  /// "YYYY-MM" — the month this context covers.
  final String month;

  /// User's base currency code (e.g. "MYR").
  final String currency;

  final double totalIncome;
  final double totalExpense;

  /// totalIncome − totalExpense.
  final double balance;

  /// Name of the highest-spending expense category, or null if no expenses.
  final String? topExpenseCategory;

  /// Total amount spent in [topExpenseCategory].
  final double topExpenseAmount;

  final double budgetAllocated;
  final double budgetSpent;
  final double budgetRemaining;

  /// Overall saving progress across all goals (0.0 – 1.0+).
  final double savingGoalProgress;

  /// Total remaining across unsettled debts only.
  final double totalDebtRemaining;

  /// Total monthly leakage from the current-month invisible expense audit.
  final double invisibleLeakageAmount;

  final double lastSweepLeftoverAmount;
  final double lastSweepAllocatedAmount;
  final double lastSweepUnallocatedAmount;

  // ── New: monthly history ───────────────────────────────────────────────────

  /// Up to 6 calendar months, oldest first. Always includes the current month.
  final List<AiMonthlySummary> monthlyHistory;

  // ── New: current-month transaction insights ────────────────────────────────

  final int transactionCount;
  final String largestTransactionDescription;
  final double largestTransactionAmount;
  final String largestTransactionCategory;

  /// Top 3 expense categories by spending amount for the current month.
  final List<AiTopCategory> topExpenseCategories;

  // ── New: saving goals expanded ─────────────────────────────────────────────

  final double savingGoalTotalTarget;
  final double savingGoalTotalSaved;
  final int activeGoalCount;
  final int completedGoalCount;

  /// Compact list of all saving goals (name, target, saved, progress, status).
  final List<AiSavingGoalSummary> savingGoals;

  // ── New: budget context ────────────────────────────────────────────────────

  /// budgetSpent / budgetAllocated × 100. 0.0 when no budgets are set.
  final double budgetUsagePercent;

  /// Category names where spending exceeded the allocated budget.
  final List<String> overBudgetCategoryNames;

  /// Category names where spending reached 80–100% of the allocated budget.
  final List<String> nearLimitCategoryNames;

  // ── New: debt context ──────────────────────────────────────────────────────

  /// Original total across ALL debts (settled + unsettled).
  final double totalDebt;

  /// Amount repaid across all debts: totalDebt − totalDebtRemaining.
  final double totalDebtPaid;

  /// totalDebtPaid / totalDebt × 100. 0.0 when no debts.
  final double debtRepaymentPercent;

  /// Number of debts that are not yet settled.
  final int activeDebtCount;

  // ── New: invisible expense context ────────────────────────────────────────

  /// Projected annual cost of subscriptions in 'review' or 'notReviewed' state.
  final double actionableAnnualLeakage;

  /// Projected annual cost across all detected subscriptions.
  final double detectedAnnualLeakage;

  final int confirmedSubscriptionCount;
  final int reviewSubscriptionCount;
  final int ignoredSubscriptionCount;
  final int notReviewedSubscriptionCount;

  /// Subscriptions the user has not yet decided to keep or cancel.
  final List<AiSubscriptionEntry> subscriptionsToReview;

  // ── Serialization (sent to AI backend — never stored in Firestore) ─────────

  Map<String, dynamic> toMap() => {
        // ── Existing fields ──────────────────────────────────────────────────
        'month': month,
        'currency': currency,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': balance,
        'topExpenseCategory': topExpenseCategory ?? 'N/A',
        'topExpenseAmount': topExpenseAmount,
        'budgetAllocated': budgetAllocated,
        'budgetSpent': budgetSpent,
        'budgetRemaining': budgetRemaining,
        'savingGoalProgressPercent':
            (savingGoalProgress * 100).toStringAsFixed(1),
        'totalDebtRemaining': totalDebtRemaining,
        'invisibleLeakageAmount': invisibleLeakageAmount,
        'lastSweepLeftoverAmount': lastSweepLeftoverAmount,
        'lastSweepAllocatedAmount': lastSweepAllocatedAmount,
        'lastSweepUnallocatedAmount': lastSweepUnallocatedAmount,
        // ── Monthly history ──────────────────────────────────────────────────
        'monthlyHistory': monthlyHistory.map((m) => m.toMap()).toList(),
        // ── Current-month transaction insights ───────────────────────────────
        'transactionCount': transactionCount,
        'largestTransactionDescription': largestTransactionDescription,
        'largestTransactionAmount': largestTransactionAmount,
        'largestTransactionCategory': largestTransactionCategory,
        'topExpenseCategories':
            topExpenseCategories.map((c) => c.toMap()).toList(),
        // ── Saving goals expanded ────────────────────────────────────────────
        'savingGoalTotalTarget': savingGoalTotalTarget,
        'savingGoalTotalSaved': savingGoalTotalSaved,
        'activeGoalCount': activeGoalCount,
        'completedGoalCount': completedGoalCount,
        'savingGoals': savingGoals.map((g) => g.toMap()).toList(),
        // ── Budget context ───────────────────────────────────────────────────
        'budgetUsagePercent': budgetUsagePercent.toStringAsFixed(1),
        'overBudgetCategories': overBudgetCategoryNames,
        'nearLimitCategories': nearLimitCategoryNames,
        // ── Debt context ─────────────────────────────────────────────────────
        'totalDebt': totalDebt,
        'totalDebtPaid': totalDebtPaid,
        'debtRepaymentPercent': debtRepaymentPercent.toStringAsFixed(1),
        'activeDebtCount': activeDebtCount,
        // ── Invisible expense context ────────────────────────────────────────
        'actionableAnnualLeakage': actionableAnnualLeakage,
        'detectedAnnualLeakage': detectedAnnualLeakage,
        'confirmedSubscriptionCount': confirmedSubscriptionCount,
        'reviewSubscriptionCount': reviewSubscriptionCount,
        'ignoredSubscriptionCount': ignoredSubscriptionCount,
        'notReviewedSubscriptionCount': notReviewedSubscriptionCount,
        'subscriptionsToReview':
            subscriptionsToReview.map((s) => s.toMap()).toList(),
      };
}
