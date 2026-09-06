import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/category_model.dart';
import 'category_form_screen.dart';
import 'category_provider.dart';
import 'preset_management_screen.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
            labelStyle: AppTextStyles.titleMedium,
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoryTab(type: 'expense'),
            _CategoryTab(type: 'income'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _pushAddCategory(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Category'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

// ── Tab view ──────────────────────────────────────────────────────────────────

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == 'expense'
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    return provider.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Failed to load categories',
            style: AppTextStyles.bodyMedium),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return EmptyState(
            title: 'No categories yet',
            subtitle:
                'Tap the button below to add your first $type category.',
            icon: Icons.category_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: categories.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _CategoryTile(category: categories[index]),
        );
      },
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pushPresets(context),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Coloured icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  materialIconData(category.iconCode),
                  color: category.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Name + default badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name,
                        style: AppTextStyles.titleMedium),
                    if (category.isDefault)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _DefaultBadge(),
                      ),
                  ],
                ),
              ),

              // Edit / delete — only for custom categories
              if (!category.isDefault) ...[
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Edit',
                  onPressed: () => _pushEditCategory(context),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.expense,
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],

              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _pushPresets(BuildContext context) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => PresetManagementScreen(category: category),
    ));
  }

  void _pushEditCategory(BuildContext context) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => CategoryFormScreen(category: category),
    ));
  }

  // ── Delete confirmation ──────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Delete "${category.name}"?\n\n'
          'All its description presets will also be deleted. '
          'Existing transactions will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = ref
                  .read(authStateChangesProvider)
                  .asData
                  ?.value
                  ?.uid;
              if (uid == null) return;
              try {
                await ref
                    .read(categoryServiceProvider)
                    .softDeleteCategory(uid, category.categoryId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Navigation helper (top-level, not inside ShellRoute) ──────────────────────

void _pushAddCategory(BuildContext context) {
  Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => const CategoryFormScreen(category: null),
  ));
}

// ── Shared badge ──────────────────────────────────────────────────────────────

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withValues(alpha: 0.35)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark
              ? cs.onSurfaceVariant.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Text(
        'Default',
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 10,
          color: isDark ? cs.onSurfaceVariant.withValues(alpha: 0.75) : null,
        ),
      ),
    );
  }
}
