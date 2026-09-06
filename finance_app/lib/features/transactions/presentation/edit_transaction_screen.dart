import 'package:flutter/material.dart';
import '../domain/transaction_model.dart';
import 'add_transaction_screen.dart';

/// Thin wrapper that opens [AddTransactionScreen] in edit mode.
///
/// Passing [transaction] pre-fills all form fields and enables the
/// delete button in the AppBar.
class EditTransactionScreen extends StatelessWidget {
  const EditTransactionScreen({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    return AddTransactionScreen(existingTransaction: transaction);
  }
}
