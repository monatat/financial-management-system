import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../leftover_allocator/data/sweep_service.dart';
import '../../reports/data/report_service.dart';
import '../../reports/domain/monthly_trend_model.dart';
import '../domain/chat_message_model.dart';
import '../domain/financial_context_model.dart';

/// AI Financial Assistant service.
///
/// Architecture:
///   Flutter → [callAiBackend] → Firebase Cloud Function → External AI API
///
/// API keys are NEVER stored in Flutter. All sensitive calls go through
/// the Cloud Function backend. If the backend is unavailable, the service
/// falls back to [generateFallbackResponse], which provides rule-based
/// context-aware responses without any external API call.
class AiAssistantService {
  AiAssistantService(this._firestore);

  final FirebaseFirestore _firestore;

  // ── Backend configuration ──────────────────────────────────────────────────
  //
  // Replace this constant with your deployed Firebase Cloud Function URL.
  // The Cloud Function is responsible for calling the external AI API.
  // Flutter NEVER calls the AI API directly.

  /// Replace with your actual Firebase Cloud Function URL.
  static const String _backendUrl =
      'https://us-central1-finance-app-f7cb9.cloudfunctions.net/financialAssistant';

  static const Duration _backendTimeout = Duration(seconds: 15);

  // ── Safety rules sent to the backend ──────────────────────────────────────

  static const List<String> _safetyRules = [
    'You are a personal finance assistant for budgeting and personal finance only.',
    'You may discuss spending, budgets, saving goals, debt repayment, invisible expenses, and leftover allocation.',
    'You must NOT recommend stocks, shares, or equity investments.',
    'You must NOT recommend cryptocurrency or NFTs.',
    'You must NOT promise profit or guaranteed returns.',
    'You must NOT provide tax filing, legal, or loan approval advice.',
    'You must NOT act as a licensed financial advisor.',
    'Keep responses short (under 5 sentences), practical, and beginner-friendly.',
    'Always end with: "This is general financial guidance only, not professional financial advice."',
  ];

  // ── Blocked topic detection ────────────────────────────────────────────────

  static const List<String> _blockedKeywords = [
    'stock pick', 'buy stock', 'invest in stock',
    'crypto', 'bitcoin', 'ethereum', 'nft', 'altcoin',
    'guaranteed return', 'guaranteed profit', 'get rich',
    'tax filing', 'tax return', 'file tax',
    'loan approval', 'credit score check',
    'gambling', 'casino', 'forex signal', 'trading signal',
  ];

  static const String _blockedResponse =
      'I cannot help with that type of financial advice. '
      'I can help you review your budget, spending, saving goals, and debt instead. '
      '\n\nThis is general financial guidance only, not professional financial advice.';

  bool _isBlockedTopic(String message) {
    final lower = message.toLowerCase();
    return _blockedKeywords.any((kw) => lower.contains(kw));
  }

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _chatHistory(String uid) =>
      _firestore.collection('users').doc(uid).collection('chatHistory');

  CollectionReference<Map<String, dynamic>> _savingGoals(String uid) =>
      _firestore.collection('users').doc(uid).collection('savingGoals');

  CollectionReference<Map<String, dynamic>> _debts(String uid) =>
      _firestore.collection('users').doc(uid).collection('debts');

  CollectionReference<Map<String, dynamic>> _audits(String uid) =>
      _firestore.collection('users').doc(uid).collection('invisibleExpenseAudits');

  CollectionReference<Map<String, dynamic>> _sweeps(String uid) =>
      _firestore.collection('users').doc(uid).collection('monthEndSweeps');

  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _budgets(String uid) =>
      _firestore.collection('users').doc(uid).collection('budgets');

  // ── Financial context ──────────────────────────────────────────────────────

  /// Builds a privacy-safe summarised context from Firestore.
  ///
  /// All queries run in parallel. Raw transaction records are NEVER
  /// included — only aggregated totals and compact summaries are collected.
  Future<FinancialContextModel> buildFinancialContext(String uid) async {
    final month = _currentMonthKey();
    final prevMonth = SweepService.previousMonthKey();
    final reportService = ReportService(_firestore);

    final results = await Future.wait([
      reportService.getFinancialSummary(uid, month),                        // 0
      reportService.getCategorySpending(uid, month),                        // 1
      _savingGoals(uid).get(),                                              // 2
      _debts(uid).where('isSettled', isEqualTo: false).get(),               // 3
      _audits(uid).doc(month).get(),                                        // 4
      _sweeps(uid).doc(prevMonth).get(),                                    // 5
      _firestore.collection('users').doc(uid).get(),                        // 6
      reportService.getMonthlyTrend(uid, 6),                                // 7
      _transactions(uid).where('month', isEqualTo: month).get(),            // 8
      _budgets(uid).where('month', isEqualTo: month).get(),                 // 9
      _debts(uid).get(),                                                    // 10
    ]);

    final summary = results[0] as dynamic;
    final categories = results[1] as List;
    final goalSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final debtSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final auditDoc = results[4] as DocumentSnapshot<Map<String, dynamic>>;
    final sweepDoc = results[5] as DocumentSnapshot<Map<String, dynamic>>;
    final userDoc = results[6] as DocumentSnapshot<Map<String, dynamic>>;
    final trendList = results[7] as List<MonthlyTrendModel>;
    final txSnap = results[8] as QuerySnapshot<Map<String, dynamic>>;
    final budgetSnap = results[9] as QuerySnapshot<Map<String, dynamic>>;
    final allDebtSnap = results[10] as QuerySnapshot<Map<String, dynamic>>;

    // Currency
    final currency = userDoc.data()?['currency'] as String? ?? 'MYR';

    // ── Existing: unsettled debt total (preserved) ────────────────────────────
    double debtRemaining = 0;
    for (final doc in debtSnap.docs) {
      debtRemaining += (doc.data()['remainingAmount'] as num?)?.toDouble() ?? 0;
    }

    // ── Existing: invisible expense leakage (preserved) ───────────────────────
    double leakage = 0;
    if (auditDoc.exists && auditDoc.data() != null) {
      leakage = (auditDoc.data()!['totalLeakage'] as num?)?.toDouble() ?? 0;
    }

    // ── Existing: last sweep (preserved) ──────────────────────────────────────
    double sweepLeftover = 0, sweepAllocated = 0, sweepUnallocated = 0;
    if (sweepDoc.exists && sweepDoc.data() != null) {
      sweepLeftover =
          (sweepDoc.data()!['leftoverAmount'] as num?)?.toDouble() ?? 0;
      final allocs = sweepDoc.data()!['allocations'] as List? ?? [];
      sweepAllocated = allocs.fold<double>(
          0.0, (s, a) => s + ((a['amount'] as num?)?.toDouble() ?? 0));
      sweepUnallocated =
          (sweepDoc.data()!['remainingUnallocatedAmount'] as num?)
                  ?.toDouble() ??
              0;
    }

    // ── New: monthly history (last 6 months) ──────────────────────────────────
    final monthlyHistory = trendList
        .map((t) => AiMonthlySummary(
              monthKey: t.month,
              monthLabel: _monthName(t.month),
              income: t.income,
              expense: t.expense,
              balance: t.balance,
              transactionCount: 0,
              savingsRate:
                  t.income > 0 ? (t.income - t.expense) / t.income : 0.0,
            ))
        .toList();

    // ── New: current-month transaction insights ───────────────────────────────
    final transactionCount = txSnap.docs.length;
    String largestTxDescription = '';
    double largestTxAmount = 0;
    String largestTxCategory = '';
    for (final doc in txSnap.docs) {
      final data = doc.data();
      if (data['type'] == 'expense') {
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        if (amount > largestTxAmount) {
          largestTxAmount = amount;
          largestTxDescription = data['description'] as String? ?? '';
          largestTxCategory = data['categoryName'] as String? ?? '';
        }
      }
    }
    final top3Categories = categories.take(3).map((c) {
      final cat = c as dynamic;
      return AiTopCategory(
        category: (cat.categoryName as String?) ?? 'Other',
        amount: (cat.totalSpent as double?) ?? 0.0,
        percentage: (cat.percentage as double?) ?? 0.0,
      );
    }).toList();

    // ── New: saving goals expanded ────────────────────────────────────────────
    double goalTarget = 0, goalSaved = 0;
    int activeGoalCount = 0, completedGoalCount = 0;
    final goalSummaries = <AiSavingGoalSummary>[];
    for (final doc in goalSnap.docs) {
      final data = doc.data();
      final target = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
      final saved = (data['savedAmount'] as num?)?.toDouble() ?? 0.0;
      final isCompleted = data['isCompleted'] as bool? ?? false;
      goalTarget += target;
      goalSaved += saved;
      if (isCompleted) {
        completedGoalCount++;
      } else {
        activeGoalCount++;
      }
      goalSummaries.add(AiSavingGoalSummary(
        name: data['title'] as String? ?? 'Unnamed Goal',
        targetAmount: target,
        savedAmount: saved,
        progressPercent: target > 0 ? saved / target * 100 : 0.0,
        status: isCompleted ? 'completed' : 'active',
      ));
    }

    // ── New: per-category budget usage ────────────────────────────────────────
    final Map<String, double> spentPerCategory = {};
    for (final doc in txSnap.docs) {
      final data = doc.data();
      if (data['type'] == 'expense') {
        final catId = data['categoryId'] as String? ?? '';
        if (catId.isNotEmpty) {
          spentPerCategory[catId] = (spentPerCategory[catId] ?? 0) +
              ((data['amount'] as num?)?.toDouble() ?? 0);
        }
      }
    }
    final overBudgetCategoryNames = <String>[];
    final nearLimitCategoryNames = <String>[];
    for (final doc in budgetSnap.docs) {
      final data = doc.data();
      final catId = data['categoryId'] as String? ?? '';
      final catName = data['categoryName'] as String? ?? catId;
      final allocated = (data['allocatedAmount'] as num?)?.toDouble() ?? 0.0;
      if (allocated <= 0) continue;
      final ratio = (spentPerCategory[catId] ?? 0.0) / allocated;
      if (ratio > 1.0) {
        overBudgetCategoryNames.add(catName);
      } else if (ratio >= 0.8) {
        nearLimitCategoryNames.add(catName);
      }
    }
    final summaryBudgetAllocated = summary.budgetAllocated as double;
    final budgetUsagePercent = summaryBudgetAllocated > 0
        ? (summary.budgetSpent as double) / summaryBudgetAllocated * 100
        : 0.0;

    // ── New: all-debt context ─────────────────────────────────────────────────
    double totalDebt = 0, totalDebtPaid = 0;
    int activeDebtCount = 0;
    for (final doc in allDebtSnap.docs) {
      final data = doc.data();
      final tAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final rAmount = (data['remainingAmount'] as num?)?.toDouble() ?? 0.0;
      final isSettled = data['isSettled'] as bool? ?? false;
      totalDebt += tAmount;
      totalDebtPaid += (tAmount - rAmount).clamp(0.0, tAmount);
      if (!isSettled) activeDebtCount++;
    }
    final debtRepaymentPercent =
        totalDebt > 0 ? totalDebtPaid / totalDebt * 100 : 0.0;

    // ── New: invisible expense subscription details ────────────────────────────
    double actionableAnnualLeakage = 0, detectedAnnualLeakage = 0;
    int confirmedSubscriptionCount = 0,
        reviewSubscriptionCount = 0,
        ignoredSubscriptionCount = 0,
        notReviewedSubscriptionCount = 0;
    final subscriptionsToReview = <AiSubscriptionEntry>[];

    if (auditDoc.exists && auditDoc.data() != null) {
      final rawSubs = auditDoc.data()!['subscriptions'] as List? ?? [];
      for (final sub in rawSubs) {
        final subMap = sub as Map<String, dynamic>;
        final amount = (subMap['amount'] as num?)?.toDouble() ?? 0.0;
        final annual = (subMap['projectedAnnual'] as num?)?.toDouble() ?? 0.0;
        final description = subMap['description'] as String? ?? '';
        final decision =
            (subMap['decision'] as String? ?? '').toLowerCase().trim();
        detectedAnnualLeakage += annual;
        if (decision == 'keep' || decision == 'confirmed') {
          confirmedSubscriptionCount++;
        } else if (decision == 'ignore' || decision == 'ignored') {
          ignoredSubscriptionCount++;
        } else if (decision == 'review') {
          reviewSubscriptionCount++;
          actionableAnnualLeakage += annual;
          subscriptionsToReview.add(AiSubscriptionEntry(
            description: description,
            monthlyAmount: amount,
            annualAmount: annual,
            status: 'review',
          ));
        } else {
          notReviewedSubscriptionCount++;
          actionableAnnualLeakage += annual;
          subscriptionsToReview.add(AiSubscriptionEntry(
            description: description,
            monthlyAmount: amount,
            annualAmount: annual,
            status: 'notReviewed',
          ));
        }
      }
    }

    return FinancialContextModel(
      // ── Existing fields (preserved) ──────────────────────────────────────────
      month: month,
      currency: currency,
      totalIncome: summary.totalIncome as double,
      totalExpense: summary.totalExpense as double,
      balance: summary.netBalance as double,
      topExpenseCategory: categories.isNotEmpty
          ? (categories[0] as dynamic).categoryName as String?
          : null,
      topExpenseAmount: categories.isNotEmpty
          ? (categories[0] as dynamic).totalSpent as double
          : 0.0,
      budgetAllocated: summary.budgetAllocated as double,
      budgetSpent: summary.budgetSpent as double,
      budgetRemaining: summary.budgetRemaining as double,
      savingGoalProgress: goalTarget > 0 ? goalSaved / goalTarget : 0.0,
      totalDebtRemaining: debtRemaining,
      invisibleLeakageAmount: leakage,
      lastSweepLeftoverAmount: sweepLeftover,
      lastSweepAllocatedAmount: sweepAllocated,
      lastSweepUnallocatedAmount: sweepUnallocated,
      // ── New fields ────────────────────────────────────────────────────────────
      monthlyHistory: monthlyHistory,
      transactionCount: transactionCount,
      largestTransactionDescription: largestTxDescription,
      largestTransactionAmount: largestTxAmount,
      largestTransactionCategory: largestTxCategory,
      topExpenseCategories: top3Categories,
      savingGoalTotalTarget: goalTarget,
      savingGoalTotalSaved: goalSaved,
      activeGoalCount: activeGoalCount,
      completedGoalCount: completedGoalCount,
      savingGoals: goalSummaries,
      budgetUsagePercent: budgetUsagePercent,
      overBudgetCategoryNames: overBudgetCategoryNames,
      nearLimitCategoryNames: nearLimitCategoryNames,
      totalDebt: totalDebt,
      totalDebtPaid: totalDebtPaid,
      debtRepaymentPercent: debtRepaymentPercent,
      activeDebtCount: activeDebtCount,
      actionableAnnualLeakage: actionableAnnualLeakage,
      detectedAnnualLeakage: detectedAnnualLeakage,
      confirmedSubscriptionCount: confirmedSubscriptionCount,
      reviewSubscriptionCount: reviewSubscriptionCount,
      ignoredSubscriptionCount: ignoredSubscriptionCount,
      notReviewedSubscriptionCount: notReviewedSubscriptionCount,
      subscriptionsToReview: subscriptionsToReview,
    );
  }

  // ── Main chat function ─────────────────────────────────────────────────────

  /// Processes a user message, calls the AI backend (or falls back to
  /// local responses), and saves both messages to Firestore.
  ///
  /// Returns the assistant's [ChatMessageModel].
  Future<ChatMessageModel> sendMessage(
    String uid,
    String userMessage,
  ) async {
    // Save user message
    final userMsg = ChatMessageModel(
      messageId: '',
      role: 'user',
      content: userMessage.trim(),
      timestamp: DateTime.now(),
    );
    await saveChatMessage(uid, userMsg);

    // Build context + get response
    final context = await buildFinancialContext(uid);
    final responseText =
        await callAiBackend(userMessage, context) ??
            generateFallbackResponse(userMessage, context);

    // Save + return assistant response
    final suggestions = generateSuggestedQuestions(context);
    final assistantMsg = ChatMessageModel(
      messageId: '',
      role: 'assistant',
      content: responseText,
      timestamp: DateTime.now(),
      suggestedActions: suggestions.take(3).toList(),
    );
    await saveChatMessage(uid, assistantMsg);
    return assistantMsg;
  }

  // ── Backend call ───────────────────────────────────────────────────────────

  /// Calls the Firebase Cloud Function backend.
  ///
  /// Returns the AI response string on success, or null on any failure.
  /// The Cloud Function is responsible for calling the external AI API with
  /// the API key — the key is NEVER stored in Flutter.
  Future<String?> callAiBackend(
    String userMessage,
    FinancialContextModel context,
  ) async {
    if (_backendUrl.contains('YOUR_FIREBASE')) {
      // Placeholder URL not yet configured — skip network call
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': userMessage,
              'context': context.toMap(),
              'safetyRules': _safetyRules,
            }),
          )
          .timeout(_backendTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['reply'] as String?;
      }
    } catch (_) {
      // Network error, timeout, or invalid response — use fallback
    }
    return null;
  }

  // ── Fallback responses ─────────────────────────────────────────────────────

  /// Generates a rule-based context-aware response without any external API.
  ///
  /// Used automatically when [callAiBackend] fails or the backend URL is
  /// not yet configured.
  String generateFallbackResponse(
    String userMessage,
    FinancialContextModel context,
  ) {
    final lower = userMessage.toLowerCase();
    final c = context.currency;
    const disc =
        '\n\nThis is general financial guidance only, not professional financial advice.';

    // ── Blocked topics ────────────────────────────────────────────────────
    if (_isBlockedTopic(lower)) return _blockedResponse;

    // ── Historical month lookup ───────────────────────────────────────────
    // If the message names a specific past month, answer from history first.
    final historicalMonth = _findHistoricalMonth(lower, context.monthlyHistory);
    if (historicalMonth != null) {
      if (lower.contains('earn') ||
          lower.contains('income') ||
          lower.contains('salary')) {
        return 'In ${historicalMonth.monthLabel} you earned $c ${historicalMonth.income.toStringAsFixed(2)}. '
            'Your balance for that month was $c ${historicalMonth.balance.toStringAsFixed(2)}.$disc';
      }
      if (lower.contains('spend') ||
          lower.contains('spent') ||
          lower.contains('expense')) {
        return 'In ${historicalMonth.monthLabel} you spent $c ${historicalMonth.expense.toStringAsFixed(2)}. '
            'Your balance for that month was $c ${historicalMonth.balance.toStringAsFixed(2)}.$disc';
      }
      return 'For ${historicalMonth.monthLabel}: '
          'Income $c ${historicalMonth.income.toStringAsFixed(2)}, '
          'Expenses $c ${historicalMonth.expense.toStringAsFixed(2)}, '
          'Balance $c ${historicalMonth.balance.toStringAsFixed(2)}.$disc';
    }

    // ── Month comparison ──────────────────────────────────────────────────
    if ((lower.contains('compare') || lower.contains('comparison') ||
            lower.contains('vs') ||
            (lower.contains('last') && lower.contains('this month'))) &&
        context.monthlyHistory.length >= 2) {
      final curr = context.monthlyHistory.last;
      final prev =
          context.monthlyHistory[context.monthlyHistory.length - 2];
      final diff = curr.expense - prev.expense;
      final direction = diff > 0 ? 'more' : 'less';
      return 'In ${curr.monthLabel} you spent $c ${curr.expense.toStringAsFixed(2)}, '
          'compared to $c ${prev.expense.toStringAsFixed(2)} in ${prev.monthLabel}. '
          'That is $c ${diff.abs().toStringAsFixed(2)} $direction than the previous month.$disc';
    }

    // ── Highest spending month ────────────────────────────────────────────
    if (context.monthlyHistory.isNotEmpty &&
        (lower.contains('highest') ||
            lower.contains('most expensive month') ||
            (lower.contains('which month') &&
                (lower.contains('spend') || lower.contains('most'))))) {
      final peak = context.monthlyHistory
          .reduce((a, b) => a.expense > b.expense ? a : b);
      return '${peak.monthLabel} had your highest spending at $c ${peak.expense.toStringAsFixed(2)} '
          'over the last ${context.monthlyHistory.length} months.$disc';
    }

    // ── Spending / expense ────────────────────────────────────────────────
    if (lower.contains('spend') ||
        lower.contains('spent') ||
        lower.contains('expense') ||
        lower.contains('biggest')) {
      if (context.totalExpense == 0) {
        return 'No expense transactions recorded for ${_monthName(context.month)} yet.$disc';
      }
      return 'In ${_monthName(context.month)} you spent $c ${context.totalExpense.toStringAsFixed(2)}. '
          'Your biggest spending category was "${context.topExpenseCategory ?? "N/A"}" at $c ${context.topExpenseAmount.toStringAsFixed(2)}.$disc';
    }

    // ── Largest single transaction ────────────────────────────────────────
    if (lower.contains('largest transaction') ||
        lower.contains('biggest transaction') ||
        lower.contains('most expensive purchase')) {
      if (context.largestTransactionAmount == 0) {
        return 'No expense transactions found for ${_monthName(context.month)} yet.$disc';
      }
      return 'Your largest expense this month was "${ context.largestTransactionDescription}" '
          'at $c ${context.largestTransactionAmount.toStringAsFixed(2)} '
          '(${context.largestTransactionCategory}).$disc';
    }

    // ── Budget ────────────────────────────────────────────────────────────
    if (lower.contains('budget') || lower.contains('over budget')) {
      if (context.budgetAllocated == 0) {
        return 'You have no budgets set for ${_monthName(context.month)}. Go to the Budget tab to set spending limits for each category.$disc';
      }
      final pct =
          (context.budgetSpent / context.budgetAllocated * 100).round();
      final status = context.budgetRemaining < 0
          ? 'You are over budget by $c ${context.budgetRemaining.abs().toStringAsFixed(2)}.'
          : 'You have $c ${context.budgetRemaining.toStringAsFixed(2)} remaining.';
      final overWarn = context.overBudgetCategoryNames.isNotEmpty
          ? ' Over-budget: ${context.overBudgetCategoryNames.join(", ")}.'
          : '';
      final nearWarn = context.nearLimitCategoryNames.isNotEmpty
          ? ' Near limit: ${context.nearLimitCategoryNames.join(", ")}.'
          : '';
      return 'You have used $pct% of your $c ${context.budgetAllocated.toStringAsFixed(2)} monthly budget. '
          '$status$overWarn$nearWarn$disc';
    }

    // ── Saving goals ──────────────────────────────────────────────────────
    if (lower.contains('saving') ||
        lower.contains('goal') ||
        (lower.contains('save') && !lower.contains('how'))) {
      if (context.savingGoalTotalTarget == 0) {
        return 'No saving goals found. Go to the Saving Goals tab to set up your first goal.$disc';
      }
      final pct = (context.savingGoalProgress * 100).toStringAsFixed(0);
      final encouragement = context.savingGoalProgress < 0.25
          ? 'You are in the early stages — keep contributing!'
          : context.savingGoalProgress < 0.75
              ? 'Good progress! Stay consistent.'
              : 'Excellent — you are close to your goals!';
      return 'Your saving goals are $pct% funded overall '
          '($c ${context.savingGoalTotalSaved.toStringAsFixed(2)} of $c ${context.savingGoalTotalTarget.toStringAsFixed(2)}). '
          '$encouragement '
          '${context.activeGoalCount} active, ${context.completedGoalCount} completed.$disc';
    }

    // ── Debt / PTPTN ──────────────────────────────────────────────────────
    if (lower.contains('debt') ||
        lower.contains('loan') ||
        lower.contains('ptptn')) {
      if (context.totalDebt == 0) {
        return 'You have no debts tracked in the app. Great work if they are all settled!$disc';
      }
      return 'You have $c ${context.totalDebtRemaining.toStringAsFixed(2)} remaining '
          'out of $c ${context.totalDebt.toStringAsFixed(2)} total debt '
          '(${context.debtRepaymentPercent.toStringAsFixed(0)}% repaid, ${context.activeDebtCount} active). '
          'Keep making consistent payments to reduce the balance.$disc';
    }

    // ── Invisible expenses / subscriptions ────────────────────────────────
    if (lower.contains('invisible') ||
        lower.contains('subscription') ||
        lower.contains('leak') ||
        lower.contains('micro')) {
      if (context.invisibleLeakageAmount == 0) {
        return 'No invisible expense audit has been run for ${_monthName(context.month)} yet. '
            'Go to Reports → Invisible Expense Audit to scan for forgotten subscriptions and micro-habits.$disc';
      }
      final actionable =
          context.reviewSubscriptionCount + context.notReviewedSubscriptionCount;
      final reviewNote = actionable > 0
          ? ' $actionable subscription(s) still need your review.'
          : '';
      return 'The invisible expense audit found $c ${context.invisibleLeakageAmount.toStringAsFixed(2)} in monthly leakage.$reviewNote '
          'Review your subscriptions and small recurring expenses in the audit report.$disc';
    }

    // ── Leftover / month-end sweep ────────────────────────────────────────
    if (lower.contains('leftover') || lower.contains('sweep')) {
      if (context.lastSweepLeftoverAmount == 0) {
        return 'No month-end leftover was detected last month, or the sweep has not run yet.$disc';
      }
      final allocated =
          'Allocated: $c ${context.lastSweepAllocatedAmount.toStringAsFixed(2)}.';
      final unallocated = context.lastSweepUnallocatedAmount > 0
          ? ' $c ${context.lastSweepUnallocatedAmount.toStringAsFixed(2)} was not allocated.'
          : ' The full leftover was allocated.';
      return 'Last month you had $c ${context.lastSweepLeftoverAmount.toStringAsFixed(2)} leftover. '
          '$allocated$unallocated$disc';
    }

    // ── Income ────────────────────────────────────────────────────────────
    if (lower.contains('income') ||
        lower.contains('earn') ||
        lower.contains('salary')) {
      return 'In ${_monthName(context.month)} you earned $c ${context.totalIncome.toStringAsFixed(2)} '
          'with a net balance of $c ${context.balance.toStringAsFixed(2)}.$disc';
    }

    // ── "How can I save more" ─────────────────────────────────────────────
    if ((lower.contains('how') || lower.contains('tips')) &&
        (lower.contains('save') ||
            lower.contains('reduce') ||
            lower.contains('cut'))) {
      return 'Here are practical steps to save more:\n'
          '1. Review your biggest expense — currently "${context.topExpenseCategory ?? "check your categories"}".\n'
          '2. Set a monthly budget for each category.\n'
          '3. Run an Invisible Expense Audit for forgotten subscriptions.\n'
          '4. Allocate any month-end leftover to a saving goal.$disc';
    }

    // ── Summary / overview ────────────────────────────────────────────────
    if (lower.contains('summary') ||
        lower.contains('overview') ||
        lower.contains('how am i doing')) {
      return 'For ${_monthName(context.month)}: Income $c ${context.totalIncome.toStringAsFixed(2)}, '
          'Expenses $c ${context.totalExpense.toStringAsFixed(2)}, '
          'Balance $c ${context.balance.toStringAsFixed(2)}. '
          'Budget used: ${context.budgetAllocated > 0 ? "${(context.budgetSpent / context.budgetAllocated * 100).round()}%" : "no budgets set"}. '
          'Saving goals: ${(context.savingGoalProgress * 100).toStringAsFixed(0)}% funded.$disc';
    }

    // ── Default ───────────────────────────────────────────────────────────
    return 'I can help you understand your spending, budgets, saving goals, and debts. '
        'Try asking about your expenses, budget usage, saving progress, or a specific past month.$disc';
  }

  // ── Suggested questions ────────────────────────────────────────────────────

  /// Returns a list of context-relevant suggested follow-up questions.
  List<String> generateSuggestedQuestions(FinancialContextModel context) {
    return const [
      'How much did I spend this month?',
      'What is my biggest expense?',
      'Am I over budget?',
      'How are my saving goals?',
      'How much debt do I have left?',
      'Do I have invisible expenses?',
      "What happened to last month's leftover?",
      'How can I save more this month?',
    ];
  }

  // ── Chat history ───────────────────────────────────────────────────────────

  /// Saves [message] to Firestore. The document ID is auto-generated.
  Future<void> saveChatMessage(String uid, ChatMessageModel message) async {
    final docRef = _chatHistory(uid).doc();
    await docRef.set(message.toMap()..['messageId'] = docRef.id);
  }

  /// Returns the last 50 messages sorted oldest-first.
  Future<List<ChatMessageModel>> getChatHistory(String uid) async {
    final snap = await _chatHistory(uid)
        .orderBy('timestamp')
        .limitToLast(50)
        .get();
    return snap.docs
        .map((doc) => ChatMessageModel.fromMap(doc.data()))
        .toList();
  }

  /// Permanently deletes all messages in the chat history.
  Future<void> clearChatHistory(String uid) async {
    final snap = await _chatHistory(uid).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static AiMonthlySummary? _findHistoricalMonth(
    String lower,
    List<AiMonthlySummary> history,
  ) {
    const monthKeywords = {
      'january': 1, 'jan': 1,
      'february': 2, 'feb': 2,
      'march': 3, 'mar': 3,
      'april': 4, 'apr': 4,
      'may': 5,
      'june': 6, 'jun': 6,
      'july': 7, 'jul': 7,
      'august': 8, 'aug': 8,
      'september': 9, 'sep': 9,
      'october': 10, 'oct': 10,
      'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };
    for (final entry in monthKeywords.entries) {
      if (lower.contains(entry.key)) {
        for (final hist in history) {
          final parts = hist.monthKey.split('-');
          if (parts.length >= 2 &&
              int.tryParse(parts[1]) == entry.value) {
            return hist;
          }
        }
      }
    }
    return null;
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static const _monthNames = [
    '',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _monthName(String key) {
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]) ?? 0;
    return '${m > 0 && m < 13 ? _monthNames[m] : parts[1]} ${parts[0]}';
  }
}
