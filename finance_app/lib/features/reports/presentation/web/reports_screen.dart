import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/placeholder_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Reports',
      icon: Icons.analytics_rounded,
      description:
          'Income vs expense trends, category breakdowns, budget performance, and PDF/CSV export will appear here.',
      color: AppColors.info,
    );
  }
}
