import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../features/reports/data/report_service.dart';

// Conditional import: web download vs stub
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

/// Generates and downloads CSV/PDF exports client-side.
///
/// All exports are built in memory from Firestore data and triggered as
/// browser file downloads (web) or no-ops (mobile — ExportScreen directs
/// users to the web version).
///
/// No Firestore data is modified. API keys are never used here.
class ExportService {
  ExportService(this._firestore);

  final FirebaseFirestore _firestore;

  // ── Collection helpers ─────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _budgets(String uid) =>
      _firestore.collection('users').doc(uid).collection('budgets');

  CollectionReference<Map<String, dynamic>> _savingGoals(String uid) =>
      _firestore.collection('users').doc(uid).collection('savingGoals');

  CollectionReference<Map<String, dynamic>> _debts(String uid) =>
      _firestore.collection('users').doc(uid).collection('debts');

  // ── Date / month helpers ───────────────────────────────────────────────────

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _monthName(String key) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]) ?? 0;
    return '${m > 0 && m < 13 ? names[m] : parts[1]} ${parts[0]}';
  }

  // ── CSV helper ─────────────────────────────────────────────────────────────

  /// Converts [rows] to RFC 4180 CSV bytes (UTF-8 with BOM for Excel compat).
  static List<int> _toCsvBytes(List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      final cells = row.map((cell) {
        final str = cell.toString();
        // Wrap in double-quotes if the value contains comma, quote, or newline
        if (str.contains(',') ||
            str.contains('"') ||
            str.contains('\n') ||
            str.contains('\r')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      });
      buffer.writeln(cells.join(','));
    }
    // Prepend UTF-8 BOM so Excel opens the file with correct encoding
    final bom = [0xEF, 0xBB, 0xBF];
    return bom + utf8.encode(buffer.toString());
  }

  // ── 1. Transactions CSV ────────────────────────────────────────────────────

  /// Downloads a CSV of all transactions for [month].
  /// Throws [ExportEmptyException] if no transactions exist.
  Future<void> exportTransactionsCsv(String uid, String month) async {
    final snap = await _transactions(uid)
        .where('month', isEqualTo: month)
        .get();

    if (snap.docs.isEmpty) throw const ExportEmptyException('transactions');

    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Category', 'Description', 'Amount', 'Currency', 'Note'],
    ];

    for (final doc in snap.docs) {
      final d = doc.data();
      final date = (d['date'] as Timestamp?)?.toDate();
      rows.add([
        date != null ? _fmtDate(date) : '',
        d['type'] ?? '',
        d['categoryName'] ?? '',
        d['description'] ?? '',
        (d['amount'] as num?)?.toStringAsFixed(2) ?? '',
        d['currency'] ?? '',
        d['note'] ?? '',
      ]);
    }

    rows.sort((a, b) => a[0].toString().compareTo(b[0].toString()));
    await downloadBytes(
      'transactions_$month.csv',
      _toCsvBytes(rows),
      'text/csv',
    );
  }

  // ── 2. Budget CSV ──────────────────────────────────────────────────────────

  /// Downloads a CSV of budgets vs actual spending for [month].
  Future<void> exportBudgetCsv(String uid, String month) async {
    final budgetSnap = await _budgets(uid)
        .where('month', isEqualTo: month)
        .get();

    if (budgetSnap.docs.isEmpty) throw const ExportEmptyException('budgets');

    // Sum expense transactions per category for the month
    final txSnap = await _transactions(uid)
        .where('month', isEqualTo: month)
        .where('type', isEqualTo: 'expense')
        .get();

    final Map<String, double> spentByCategory = {};
    for (final doc in txSnap.docs) {
      final catId = doc.data()['categoryId'] as String? ?? '';
      spentByCategory[catId] =
          (spentByCategory[catId] ?? 0.0) +
          ((doc.data()['amount'] as num?)?.toDouble() ?? 0.0);
    }

    final rows = <List<dynamic>>[
      [
        'Month', 'Category', 'Allocated Amount',
        'Spent Amount', 'Remaining Amount', 'Usage %',
      ],
    ];

    for (final doc in budgetSnap.docs) {
      final d = doc.data();
      final catId = d['categoryId'] as String? ?? '';
      final allocated = (d['allocatedAmount'] as num?)?.toDouble() ?? 0.0;
      final spent = spentByCategory[catId] ?? 0.0;
      final remaining = allocated - spent;
      final usagePct = allocated > 0
          ? '${(spent / allocated * 100).toStringAsFixed(1)}%'
          : '0%';
      rows.add([
        month,
        d['categoryName'] ?? '',
        allocated.toStringAsFixed(2),
        spent.toStringAsFixed(2),
        remaining.toStringAsFixed(2),
        usagePct,
      ]);
    }

    await downloadBytes(
      'budget_$month.csv',
      _toCsvBytes(rows),
      'text/csv',
    );
  }

  // ── 3. Category spending CSV ───────────────────────────────────────────────

  /// Downloads a CSV of expense spending grouped by category for [month].
  Future<void> exportCategorySpendingCsv(String uid, String month) async {
    final reportService = ReportService(_firestore);
    final categories = await reportService.getCategorySpending(uid, month);

    if (categories.isEmpty) throw const ExportEmptyException('spending data');

    final rows = <List<dynamic>>[
      ['Month', 'Category', 'Total Spent', 'Percentage'],
    ];

    for (final cat in categories) {
      rows.add([
        month,
        cat.categoryName,
        cat.totalSpent.toStringAsFixed(2),
        cat.percentLabel,
      ]);
    }

    await downloadBytes(
      'category_spending_$month.csv',
      _toCsvBytes(rows),
      'text/csv',
    );
  }

  // ── 4. Saving goals CSV ────────────────────────────────────────────────────

  /// Downloads a CSV of all saving goals (not month-specific).
  Future<void> exportSavingGoalsCsv(String uid) async {
    final snap = await _savingGoals(uid).get();

    if (snap.docs.isEmpty) throw const ExportEmptyException('saving goals');

    final rows = <List<dynamic>>[
      [
        'Goal Title', 'Target Amount', 'Saved Amount',
        'Remaining Amount', 'Progress %', 'Target Date', 'Completed',
      ],
    ];

    for (final doc in snap.docs) {
      final d = doc.data();
      final target = (d['targetAmount'] as num?)?.toDouble() ?? 0.0;
      final saved = (d['savedAmount'] as num?)?.toDouble() ?? 0.0;
      final remaining = target - saved;
      final pct = target > 0
          ? '${(saved / target * 100).toStringAsFixed(1)}%'
          : '0%';
      final targetDate =
          (d['targetDate'] as Timestamp?)?.toDate();
      rows.add([
        d['title'] ?? '',
        target.toStringAsFixed(2),
        saved.toStringAsFixed(2),
        remaining.toStringAsFixed(2),
        pct,
        targetDate != null ? _fmtDate(targetDate) : '',
        (d['isCompleted'] as bool? ?? false) ? 'Yes' : 'No',
      ]);
    }

    await downloadBytes(
      'saving_goals.csv',
      _toCsvBytes(rows),
      'text/csv',
    );
  }

  // ── 5. Debt summary CSV ────────────────────────────────────────────────────

  /// Downloads a CSV of all debts (not month-specific).
  Future<void> exportDebtSummaryCsv(String uid) async {
    final snap = await _debts(uid).get();

    if (snap.docs.isEmpty) throw const ExportEmptyException('debts');

    final rows = <List<dynamic>>[
      [
        'Debt Title', 'Total Amount', 'Paid Amount',
        'Remaining Amount', 'Monthly Due', 'Due Date', 'Settled',
      ],
    ];

    for (final doc in snap.docs) {
      final d = doc.data();
      final total = (d['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final remaining = (d['remainingAmount'] as num?)?.toDouble() ?? 0.0;
      final paid = total - remaining;
      final dueDate = (d['dueDate'] as Timestamp?)?.toDate();
      rows.add([
        d['title'] ?? '',
        total.toStringAsFixed(2),
        paid.toStringAsFixed(2),
        remaining.toStringAsFixed(2),
        (d['monthlyDue'] as num?)?.toStringAsFixed(2) ?? '',
        dueDate != null ? _fmtDate(dueDate) : '',
        (d['isSettled'] as bool? ?? false) ? 'Yes' : 'No',
      ]);
    }

    await downloadBytes(
      'debt_summary.csv',
      _toCsvBytes(rows),
      'text/csv',
    );
  }

  // ── 6. Monthly summary PDF ─────────────────────────────────────────────────

  /// Generates and downloads a PDF summary for [month].
  Future<void> generateMonthlySummaryPdf(String uid, String month) async {
    final reportService = ReportService(_firestore);

    final results = await Future.wait([
      reportService.getFinancialSummary(uid, month),
      reportService.getCategorySpending(uid, month),
      _savingGoals(uid).get(),
      _debts(uid).get(),
      _firestore.collection('users').doc(uid).get(),
    ]);

    final summary = results[0] as dynamic;
    final categories = results[1] as List;
    final goalSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final debtSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final userDoc = results[4] as DocumentSnapshot<Map<String, dynamic>>;

    final currency = userDoc.data()?['currency'] as String? ?? 'MYR';
    final userName = userDoc.data()?['name'] as String? ?? 'User';

    // Saving goals aggregate
    final goalCount = goalSnap.docs.length;
    double goalTarget = 0, goalSaved = 0;
    for (final doc in goalSnap.docs) {
      goalTarget += (doc.data()['targetAmount'] as num?)?.toDouble() ?? 0;
      goalSaved += (doc.data()['savedAmount'] as num?)?.toDouble() ?? 0;
    }
    final goalPct = goalTarget > 0
        ? '${(goalSaved / goalTarget * 100).toStringAsFixed(1)}%'
        : 'N/A';

    // Debt aggregate
    double totalDebt = 0, debtRemaining = 0;
    int activeDebts = 0;
    for (final doc in debtSnap.docs) {
      final settled = doc.data()['isSettled'] as bool? ?? false;
      totalDebt += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
      if (!settled) {
        debtRemaining +=
            (doc.data()['remainingAmount'] as num?)?.toDouble() ?? 0;
        activeDebts++;
      }
    }

    // ── Build PDF ────────────────────────────────────────────────────────────
    final pdf = pw.Document();
    final generated = _fmtDate(DateTime.now());
    final monthLabel = _monthName(month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FinanceApp — Monthly Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.Text(
                  'Generated: $generated',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.Text(
              '$monthLabel · $userName',
              style: const pw.TextStyle(
                  fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.blue200),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Text(
              'This report is generated from user-entered data and is for personal '
              'financial tracking only.',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500),
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
        build: (ctx) => [
          // ── Financial Summary ────────────────────────────────────────────
          _pdfSection('Financial Summary'),
          _pdfTable([
            ['Income', '$currency ${(summary.totalIncome as double).toStringAsFixed(2)}'],
            ['Expenses', '$currency ${(summary.totalExpense as double).toStringAsFixed(2)}'],
            ['Net Balance', '$currency ${(summary.netBalance as double).toStringAsFixed(2)}'],
          ]),
          pw.SizedBox(height: 12),

          // ── Budget Summary ───────────────────────────────────────────────
          _pdfSection('Budget Summary'),
          _pdfTable([
            ['Budget Allocated', '$currency ${(summary.budgetAllocated as double).toStringAsFixed(2)}'],
            ['Budget Spent', '$currency ${(summary.budgetSpent as double).toStringAsFixed(2)}'],
            ['Budget Remaining', '$currency ${(summary.budgetRemaining as double).toStringAsFixed(2)}'],
          ]),
          pw.SizedBox(height: 12),

          // ── Saving Goals ─────────────────────────────────────────────────
          _pdfSection('Saving Goals Progress'),
          _pdfTable([
            ['Total Goals', '$goalCount'],
            ['Total Target', '$currency ${goalTarget.toStringAsFixed(2)}'],
            ['Total Saved', '$currency ${goalSaved.toStringAsFixed(2)}'],
            ['Overall Progress', goalPct],
          ]),
          pw.SizedBox(height: 12),

          // ── Debt Summary ─────────────────────────────────────────────────
          _pdfSection('Debt Summary'),
          _pdfTable([
            ['Active Debts', '$activeDebts'],
            ['Total Debt Value', '$currency ${totalDebt.toStringAsFixed(2)}'],
            ['Total Remaining', '$currency ${debtRemaining.toStringAsFixed(2)}'],
            ['Total Repaid', '$currency ${(totalDebt - debtRemaining).toStringAsFixed(2)}'],
          ]),
          pw.SizedBox(height: 12),

          // ── Top Categories ───────────────────────────────────────────────
          _pdfSection('Top Spending Categories'),
          if (categories.isEmpty)
            pw.Text('No expense data for $monthLabel.',
                style: const pw.TextStyle(color: PdfColors.grey600))
          else
            _pdfTable([
              ['#', 'Category', 'Amount', '%'],
              ...List.generate(
                categories.length > 5 ? 5 : categories.length,
                (i) {
                  final cat = categories[i] as dynamic;
                  return [
                    '${i + 1}',
                    cat.categoryName as String,
                    '$currency ${(cat.totalSpent as double).toStringAsFixed(2)}',
                    cat.percentLabel as String,
                  ];
                },
              ),
            ], hasHeader: true),
        ],
      ),
    );

    final bytes = await pdf.save();
    await downloadBytes(
      'monthly_summary_$month.pdf',
      bytes,
      'application/pdf',
    );
  }

  // ── PDF layout helpers ─────────────────────────────────────────────────────

  static pw.Widget _pdfSection(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _pdfTable(
    List<List<String>> rows, {
    bool hasHeader = false,
  }) {
    return pw.TableHelper.fromTextArray(
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
        color: PdfColors.white,
      ),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.blue700),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      oddRowDecoration:
          const pw.BoxDecoration(color: PdfColors.grey100),
      headerCount: hasHeader ? 1 : 0,
    );
  }

// ── Section constants ─────────────────────────────────────────────────────────

  static const String sectionIncome = 'income';
  static const String sectionExpenses = 'expenses';
  static const String sectionTransactions = 'transactions';
  static const String sectionBudget = 'budget';
  static const String sectionCategorySpending = 'categorySpending';
  static const String sectionSavingGoals = 'savingGoals';
  static const String sectionDebts = 'debts';
  static const String sectionMonthlySummary = 'monthlySummary';

  static const List<String> allSections = [
    sectionIncome, sectionExpenses, sectionTransactions,
    sectionBudget, sectionCategorySpending, sectionSavingGoals,
    sectionDebts, sectionMonthlySummary,
  ];

  static const Map<String, String> sectionLabels = {
    sectionIncome: 'Income',
    sectionExpenses: 'Expenses',
    sectionTransactions: 'Transactions',
    sectionBudget: 'Budget',
    sectionCategorySpending: 'Category Spending',
    sectionSavingGoals: 'Saving Goals',
    sectionDebts: 'Debts',
    sectionMonthlySummary: 'Monthly Summary',
  };

// ── Custom export — public API ─────────────────────────────────────────────────

  /// Returns every "YYYY-MM" key between [startMonth] and [endMonth] inclusive.
  List<String> getMonthsInRange(String startMonth, String endMonth) {
    final start = _parseMonthDate(startMonth);
    final end = _parseMonthDate(endMonth);
    final months = <String>[];
    var current = DateTime(start.year, start.month);
    while (!current.isAfter(end)) {
      months.add(
          '${current.year}-${current.month.toString().padLeft(2, '0')}');
      current = DateTime(current.year, current.month + 1);
    }
    return months;
  }

  static DateTime _parseMonthDate(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]));
  }

  /// Generates a combined CSV report covering [startMonth]–[endMonth] for the
  /// requested [sections].  All selected sections are written into one file
  /// separated by `=== SECTION NAME ===` headers.
  Future<void> generateCustomCsvReport(
    String uid,
    String startMonth,
    String endMonth,
    List<String> sections,
  ) async {
    final needsTx = sections.any({
      sectionIncome, sectionExpenses, sectionTransactions,
      sectionCategorySpending, sectionMonthlySummary,
    }.contains);
    final needsBudget = sections.contains(sectionBudget) ||
        sections.contains(sectionMonthlySummary);

    // ── Parallel Firestore reads ─────────────────────────────────────────────
    final txFuture = needsTx
        ? _transactions(uid)
              .where('month', isGreaterThanOrEqualTo: startMonth)
              .where('month', isLessThanOrEqualTo: endMonth)
              .get()
        : null;
    final budgetFuture = needsBudget
        ? _budgets(uid)
              .where('month', isGreaterThanOrEqualTo: startMonth)
              .where('month', isLessThanOrEqualTo: endMonth)
              .get()
        : null;
    final goalFuture = sections.contains(sectionSavingGoals)
        ? _savingGoals(uid).get()
        : null;
    final debtFuture = sections.contains(sectionDebts)
        ? _debts(uid).get()
        : null;
    final userFuture = _firestore.collection('users').doc(uid).get();

    await Future.wait([
      ?txFuture,
      ?budgetFuture,
      ?goalFuture,
      ?debtFuture,
      userFuture,
    ]);

    final txDocs = txFuture != null ? (await txFuture).docs : [];
    final budgetDocs = budgetFuture != null ? (await budgetFuture).docs : [];
    final goalDocs = goalFuture != null ? (await goalFuture).docs : [];
    final debtDocs = debtFuture != null ? (await debtFuture).docs : [];
    final userData = (await userFuture).data();
    final currency = userData?['currency'] as String? ?? 'MYR';

    final incomeDocs = txDocs.where((d) => d.data()['type'] == 'income').toList()
      ..sort((a, b) => (a.data()['month'] as String? ?? '').compareTo(b.data()['month'] as String? ?? ''));
    final expenseDocs = txDocs.where((d) => d.data()['type'] == 'expense').toList()
      ..sort((a, b) => (a.data()['month'] as String? ?? '').compareTo(b.data()['month'] as String? ?? ''));

    if (txDocs.isEmpty && budgetDocs.isEmpty && goalDocs.isEmpty && debtDocs.isEmpty) {
      throw const ExportEmptyException('data');
    }

    final months = getMonthsInRange(startMonth, endMonth);

    // ── Build CSV ────────────────────────────────────────────────────────────
    final buf = StringBuffer();
    final rangeLabel = startMonth == endMonth ? startMonth : '$startMonth to $endMonth';
    buf.writeln('FinanceApp — Financial Report ($rangeLabel)');
    buf.writeln('Generated: ${_fmtDate(DateTime.now())} · Currency: $currency');

    void appendSection(String title, List<List<dynamic>> rows) {
      buf.writeln();
      buf.writeln('=== $title ===');
      for (final row in rows) {
        buf.writeln(row.map((c) => _csvCell(c.toString())).join(','));
      }
    }

    // Income
    if (sections.contains(sectionIncome)) {
      final rows = <List<dynamic>>[
        ['Date', 'Month', 'Category', 'Description', 'Amount', 'Note'],
        ...incomeDocs.map((d) {
          final data = d.data();
          final date = (data['date'] as Timestamp?)?.toDate();
          return [
            date != null ? _fmtDate(date) : '',
            data['month'] ?? '',
            data['categoryName'] ?? '',
            data['description'] ?? '',
            (data['amount'] as num?)?.toStringAsFixed(2) ?? '',
            data['note'] ?? '',
          ];
        }),
      ];
      appendSection('INCOME', rows);
    }

    // Expenses
    if (sections.contains(sectionExpenses)) {
      final rows = <List<dynamic>>[
        ['Date', 'Month', 'Category', 'Description', 'Amount', 'Note'],
        ...expenseDocs.map((d) {
          final data = d.data();
          final date = (data['date'] as Timestamp?)?.toDate();
          return [
            date != null ? _fmtDate(date) : '',
            data['month'] ?? '',
            data['categoryName'] ?? '',
            data['description'] ?? '',
            (data['amount'] as num?)?.toStringAsFixed(2) ?? '',
            data['note'] ?? '',
          ];
        }),
      ];
      appendSection('EXPENSES', rows);
    }

    // Transactions (all)
    if (sections.contains(sectionTransactions)) {
      final allSorted = [...txDocs]
        ..sort((a, b) => (a.data()['month'] as String? ?? '').compareTo(b.data()['month'] as String? ?? ''));
      final rows = <List<dynamic>>[
        ['Date', 'Month', 'Type', 'Category', 'Description', 'Amount', 'Note'],
        ...allSorted.map((d) {
          final data = d.data();
          final date = (data['date'] as Timestamp?)?.toDate();
          return [
            date != null ? _fmtDate(date) : '',
            data['month'] ?? '',
            data['type'] ?? '',
            data['categoryName'] ?? '',
            data['description'] ?? '',
            (data['amount'] as num?)?.toStringAsFixed(2) ?? '',
            data['note'] ?? '',
          ];
        }),
      ];
      appendSection('TRANSACTIONS', rows);
    }

    // Budget
    if (sections.contains(sectionBudget)) {
      final spentByMonthCat = <String, Map<String, double>>{};
      for (final d in expenseDocs) {
        final m = d.data()['month'] as String? ?? '';
        final cat = d.data()['categoryId'] as String? ?? '';
        spentByMonthCat.putIfAbsent(m, () => {})[cat] =
            (spentByMonthCat[m]![cat] ?? 0) +
            ((d.data()['amount'] as num?)?.toDouble() ?? 0);
      }
      final budgetSorted = [...budgetDocs]
        ..sort((a, b) => (a.data()['month'] as String? ?? '').compareTo(b.data()['month'] as String? ?? ''));
      final rows = <List<dynamic>>[
        ['Month', 'Category', 'Allocated', 'Spent', 'Remaining', 'Usage %'],
        ...budgetSorted.map((d) {
          final data = d.data();
          final m = data['month'] as String? ?? '';
          final cat = data['categoryId'] as String? ?? '';
          final allocated = (data['allocatedAmount'] as num?)?.toDouble() ?? 0;
          final spent = spentByMonthCat[m]?[cat] ?? 0;
          final remaining = allocated - spent;
          final pct = allocated > 0
              ? '${(spent / allocated * 100).toStringAsFixed(1)}%'
              : '0%';
          return [m, data['categoryName'] ?? '', allocated.toStringAsFixed(2),
              spent.toStringAsFixed(2), remaining.toStringAsFixed(2), pct];
        }),
      ];
      appendSection('BUDGET', rows);
    }

    // Category Spending
    if (sections.contains(sectionCategorySpending)) {
      final catByMonth = <String, Map<String, double>>{};
      for (final d in expenseDocs) {
        final m = d.data()['month'] as String? ?? '';
        final cat = d.data()['categoryName'] as String? ?? 'Other';
        catByMonth.putIfAbsent(m, () => <String, double>{})[cat] =
            (catByMonth[m]![cat] ?? 0) +
            ((d.data()['amount'] as num?)?.toDouble() ?? 0);
      }
      final rows = <List<dynamic>>[
        ['Month', 'Category', 'Total Spent', 'Percentage'],
      ];
      for (final month in months) {
        final catMap = catByMonth[month] ?? {};
        final total = catMap.values.fold<double>(0, (s, v) => s + v);
        final sorted = catMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final e in sorted) {
          final pct = total > 0
              ? '${(e.value / total * 100).toStringAsFixed(1)}%'
              : '0%';
          rows.add([month, e.key, e.value.toStringAsFixed(2), pct]);
        }
      }
      appendSection('CATEGORY SPENDING', rows);
    }

    // Saving Goals
    if (sections.contains(sectionSavingGoals)) {
      final rows = <List<dynamic>>[
        ['Goal Title', 'Target', 'Saved', 'Remaining', 'Progress %', 'Target Date', 'Completed'],
        ...goalDocs.map((d) {
          final data = d.data();
          final target = (data['targetAmount'] as num?)?.toDouble() ?? 0;
          final saved = (data['savedAmount'] as num?)?.toDouble() ?? 0;
          final pct = target > 0 ? '${(saved / target * 100).toStringAsFixed(1)}%' : '0%';
          final tDate = (data['targetDate'] as Timestamp?)?.toDate();
          return [data['title'] ?? '', target.toStringAsFixed(2),
              saved.toStringAsFixed(2), (target - saved).toStringAsFixed(2),
              pct, tDate != null ? _fmtDate(tDate) : '',
              (data['isCompleted'] as bool? ?? false) ? 'Yes' : 'No'];
        }),
      ];
      appendSection('SAVING GOALS', rows);
    }

    // Debts
    if (sections.contains(sectionDebts)) {
      final rows = <List<dynamic>>[
        ['Debt Title', 'Total', 'Paid', 'Remaining', 'Monthly Due', 'Due Date', 'Settled'],
        ...debtDocs.map((d) {
          final data = d.data();
          final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
          final remaining = (data['remainingAmount'] as num?)?.toDouble() ?? 0;
          final dDate = (data['dueDate'] as Timestamp?)?.toDate();
          return [data['title'] ?? '', total.toStringAsFixed(2),
              (total - remaining).toStringAsFixed(2), remaining.toStringAsFixed(2),
              (data['monthlyDue'] as num?)?.toStringAsFixed(2) ?? '',
              dDate != null ? _fmtDate(dDate) : '',
              (data['isSettled'] as bool? ?? false) ? 'Yes' : 'No'];
        }),
      ];
      appendSection('DEBTS', rows);
    }

    // Monthly Summary
    if (sections.contains(sectionMonthlySummary)) {
      final rows = <List<dynamic>>[
        ['Month', 'Income', 'Expenses', 'Balance',
         'Budget Allocated', 'Budget Spent', 'Budget Remaining'],
      ];
      for (final month in months) {
        final mIncome = incomeDocs.where((d) => d.data()['month'] == month)
            .fold<double>(0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
        final mExpense = expenseDocs.where((d) => d.data()['month'] == month)
            .fold<double>(0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
        final mBudgets = budgetDocs.where((d) => d.data()['month'] == month).toList();
        final mAllocated = mBudgets.fold<double>(0, (s, d) =>
            s + ((d.data()['allocatedAmount'] as num?)?.toDouble() ?? 0));
        final mSpent = expenseDocs
            .where((d) => d.data()['month'] == month &&
                mBudgets.any((b) => b.data()['categoryId'] == d.data()['categoryId']))
            .fold<double>(0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
        rows.add([month, mIncome.toStringAsFixed(2), mExpense.toStringAsFixed(2),
            (mIncome - mExpense).toStringAsFixed(2), mAllocated.toStringAsFixed(2),
            mSpent.toStringAsFixed(2), (mAllocated - mSpent).toStringAsFixed(2)]);
      }
      appendSection('MONTHLY SUMMARY', rows);
    }

    final filename = startMonth == endMonth
        ? 'financial_report_$startMonth.csv'
        : 'financial_report_${startMonth}_to_$endMonth.csv';

    // Debug: verify the CSV string content before encoding.
    // This must show readable text (e.g. "FinanceApp — Financial Report..."),
    // NOT a list of numbers. If you see numbers here, the bug is upstream.
    final csvString = buf.toString();
    final preview = csvString.length > 300 ? csvString.substring(0, 300) : csvString;
    // ignore: avoid_print
    print('[Export CSV] First 300 chars of CSV string:\n$preview');

    final bom = [0xEF, 0xBB, 0xBF];
    // utf8.encode() produces a Uint8List; Uint8List.fromList is used inside
    // downloadBytes to ensure the Blob receives binary data, not toString().
    await downloadBytes(filename, bom + utf8.encode(csvString), 'text/csv');
  }

  static String _csvCell(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Generates a combined PDF report covering [startMonth]–[endMonth] for the
  /// requested [sections].
  Future<void> generateCustomPdfReport(
    String uid,
    String startMonth,
    String endMonth,
    List<String> sections,
  ) async {
    final needsTx = sections.any({
      sectionIncome, sectionExpenses, sectionTransactions,
      sectionCategorySpending, sectionMonthlySummary,
    }.contains);
    final needsBudget = sections.contains(sectionBudget) ||
        sections.contains(sectionMonthlySummary);

    final txFuture = needsTx
        ? _transactions(uid)
              .where('month', isGreaterThanOrEqualTo: startMonth)
              .where('month', isLessThanOrEqualTo: endMonth)
              .get()
        : null;
    final budgetFuture = needsBudget
        ? _budgets(uid)
              .where('month', isGreaterThanOrEqualTo: startMonth)
              .where('month', isLessThanOrEqualTo: endMonth)
              .get()
        : null;
    final goalFuture = sections.contains(sectionSavingGoals)
        ? _savingGoals(uid).get()
        : null;
    final debtFuture = sections.contains(sectionDebts)
        ? _debts(uid).get()
        : null;
    final userFuture = _firestore.collection('users').doc(uid).get();

    await Future.wait([
      ?txFuture,
      ?budgetFuture,
      ?goalFuture,
      ?debtFuture,
      userFuture,
    ]);

    final txDocs = txFuture != null ? (await txFuture).docs : [];
    final budgetDocs = budgetFuture != null ? (await budgetFuture).docs : [];
    final goalDocs = goalFuture != null ? (await goalFuture).docs : [];
    final debtDocs = debtFuture != null ? (await debtFuture).docs : [];
    final userData = (await userFuture).data();
    final currency = userData?['currency'] as String? ?? 'MYR';
    final userName = userData?['name'] as String? ?? 'User';

    final incomeDocs = txDocs.where((d) => d.data()['type'] == 'income').toList();
    final expenseDocs = txDocs.where((d) => d.data()['type'] == 'expense').toList();
    final months = getMonthsInRange(startMonth, endMonth);
    final rangeLabel = startMonth == endMonth
        ? _monthName(startMonth)
        : '${_monthName(startMonth)} – ${_monthName(endMonth)}';

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('FinanceApp — Financial Report',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('Generated: ${_fmtDate(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
          pw.Text('$rangeLabel · $userName · $currency',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.blue200),
          pw.SizedBox(height: 2),
        ]),
        footer: (ctx) => pw.Column(children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Text(
            'This report is generated from user-entered data and is for personal financial tracking only.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              textAlign: pw.TextAlign.right),
        ]),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // Income
          if (sections.contains(sectionIncome) && incomeDocs.isNotEmpty) {
            widgets.add(_pdfSection('Income'));
            widgets.add(_pdfTable([
              ['Date', 'Month', 'Category', 'Description', 'Amount'],
              ...incomeDocs.take(100).map((d) {
                final data = d.data();
                final date = (data['date'] as Timestamp?)?.toDate();
                return [date != null ? _fmtDate(date) : '', data['month'] ?? '',
                    data['categoryName'] ?? '', data['description'] ?? '',
                    '$currency ${(data['amount'] as num?)?.toStringAsFixed(2) ?? ''}'];
              }),
            ], hasHeader: true));
            if (incomeDocs.length > 100) {
              widgets.add(pw.Text('(Showing first 100 of ${incomeDocs.length} records)',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)));
            }
            widgets.add(pw.SizedBox(height: 12));
          }

          // Expenses
          if (sections.contains(sectionExpenses) && expenseDocs.isNotEmpty) {
            widgets.add(_pdfSection('Expenses'));
            widgets.add(_pdfTable([
              ['Date', 'Month', 'Category', 'Description', 'Amount'],
              ...expenseDocs.take(100).map((d) {
                final data = d.data();
                final date = (data['date'] as Timestamp?)?.toDate();
                return [date != null ? _fmtDate(date) : '', data['month'] ?? '',
                    data['categoryName'] ?? '', data['description'] ?? '',
                    '$currency ${(data['amount'] as num?)?.toStringAsFixed(2) ?? ''}'];
              }),
            ], hasHeader: true));
            widgets.add(pw.SizedBox(height: 12));
          }

          // Monthly Summary
          if (sections.contains(sectionMonthlySummary)) {
            widgets.add(_pdfSection('Monthly Summary'));
            final summaryRows = <List<String>>[
              ['Month', 'Income', 'Expenses', 'Balance'],
            ];
            for (final month in months) {
              final mInc = incomeDocs.where((d) => d.data()['month'] == month)
                  .fold<double>(0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
              final mExp = expenseDocs.where((d) => d.data()['month'] == month)
                  .fold<double>(0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
              summaryRows.add([_monthName(month),
                  '$currency ${mInc.toStringAsFixed(2)}',
                  '$currency ${mExp.toStringAsFixed(2)}',
                  '$currency ${(mInc - mExp).toStringAsFixed(2)}']);
            }
            widgets.add(_pdfTable(summaryRows, hasHeader: true));
            widgets.add(pw.SizedBox(height: 12));
          }

          // Budget
          if (sections.contains(sectionBudget) && budgetDocs.isNotEmpty) {
            widgets.add(_pdfSection('Budget'));
            final spentByCat = <String, Map<String, double>>{};
            for (final d in expenseDocs) {
              final m = d.data()['month'] as String? ?? '';
              final cat = d.data()['categoryId'] as String? ?? '';
              spentByCat.putIfAbsent(m, () => <String, double>{})[cat] =
                  (spentByCat[m]![cat] ?? 0) + ((d.data()['amount'] as num?)?.toDouble() ?? 0);
            }
            final budgetRows = <List<String>>[
              ['Month', 'Category', 'Allocated', 'Spent', 'Remaining'],
            ];
            for (final d in budgetDocs) {
              final data = d.data();
              final m = data['month'] as String? ?? '';
              final cat = data['categoryId'] as String? ?? '';
              final allocated = (data['allocatedAmount'] as num?)?.toDouble() ?? 0;
              final spent = spentByCat[m]?[cat] ?? 0;
              budgetRows.add([_monthName(m), data['categoryName'] ?? '',
                  '$currency ${allocated.toStringAsFixed(2)}',
                  '$currency ${spent.toStringAsFixed(2)}',
                  '$currency ${(allocated - spent).toStringAsFixed(2)}']);
            }
            widgets.add(_pdfTable(budgetRows, hasHeader: true));
            widgets.add(pw.SizedBox(height: 12));
          }

          // Category Spending
          if (sections.contains(sectionCategorySpending) && expenseDocs.isNotEmpty) {
            widgets.add(_pdfSection('Category Spending'));
            final catRows = <List<String>>[['Month', 'Category', 'Total', '%']];
            for (final month in months) {
              final catMap = <String, double>{};
              for (final d in expenseDocs.where((d) => d.data()['month'] == month)) {
                final cat = d.data()['categoryName'] as String? ?? 'Other';
                catMap[cat] = (catMap[cat] ?? 0) + ((d.data()['amount'] as num?)?.toDouble() ?? 0);
              }
              final total = catMap.values.fold<double>(0, (s, v) => s + v);
              final sorted = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              for (final e in sorted) {
                catRows.add([_monthName(month), e.key,
                    '$currency ${e.value.toStringAsFixed(2)}',
                    total > 0 ? '${(e.value / total * 100).toStringAsFixed(1)}%' : '0%']);
              }
            }
            widgets.add(_pdfTable(catRows, hasHeader: true));
            widgets.add(pw.SizedBox(height: 12));
          }

          // Saving Goals
          if (sections.contains(sectionSavingGoals) && goalDocs.isNotEmpty) {
            widgets.add(_pdfSection('Saving Goals'));
            final goalRows = <List<String>>[
              ['Goal', 'Target', 'Saved', 'Progress', 'Completed'],
            ];
            for (final d in goalDocs) {
              final data = d.data();
              final target = (data['targetAmount'] as num?)?.toDouble() ?? 0;
              final saved = (data['savedAmount'] as num?)?.toDouble() ?? 0;
              goalRows.add([data['title'] ?? '',
                  '$currency ${target.toStringAsFixed(2)}',
                  '$currency ${saved.toStringAsFixed(2)}',
                  target > 0 ? '${(saved / target * 100).toStringAsFixed(0)}%' : '0%',
                  (data['isCompleted'] as bool? ?? false) ? 'Yes' : 'No']);
            }
            widgets.add(_pdfTable(goalRows, hasHeader: true));
            widgets.add(pw.SizedBox(height: 12));
          }

          // Debts
          if (sections.contains(sectionDebts) && debtDocs.isNotEmpty) {
            widgets.add(_pdfSection('Debts'));
            final debtRows = <List<String>>[
              ['Debt', 'Total', 'Paid', 'Remaining', 'Settled'],
            ];
            for (final d in debtDocs) {
              final data = d.data();
              final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
              final remaining = (data['remainingAmount'] as num?)?.toDouble() ?? 0;
              debtRows.add([data['title'] ?? '',
                  '$currency ${total.toStringAsFixed(2)}',
                  '$currency ${(total - remaining).toStringAsFixed(2)}',
                  '$currency ${remaining.toStringAsFixed(2)}',
                  (data['isSettled'] as bool? ?? false) ? 'Yes' : 'No']);
            }
            widgets.add(_pdfTable(debtRows, hasHeader: true));
          }

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();
    final filename = startMonth == endMonth
        ? 'financial_report_$startMonth.pdf'
        : 'financial_report_${startMonth}_to_$endMonth.pdf';

    await downloadBytes(filename, bytes, 'application/pdf');
  }
} // end ExportService

// ── Exception ─────────────────────────────────────────────────────────────────

class ExportEmptyException implements Exception {
  const ExportEmptyException(this.dataType);

  final String dataType;

  @override
  String toString() => 'No $dataType data found for the selected period.';
}
