import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/category_model.dart';
import '../domain/description_preset_model.dart';
import 'category_provider.dart';

/// Screen for viewing and managing description presets for one category.
class PresetManagementScreen extends ConsumerWidget {
  const PresetManagementScreen({super.key, required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(presetsForCategoryProvider(category.categoryId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Description Presets'),
            Text(
              category.name,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: presetsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load presets',
              style: AppTextStyles.bodyMedium),
        ),
        data: (presets) {
          if (presets.isEmpty) {
            return EmptyState(
              title: 'No presets yet',
              subtitle:
                  'Tap + to add a description preset for ${category.name}.',
              icon: Icons.label_outline_rounded,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: presets.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _PresetTile(
              preset: presets[index],
              categoryColor: category.color,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPresetBottomSheet(context, ref, preset: null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showPresetBottomSheet(
    BuildContext context,
    WidgetRef ref, {
    required DescriptionPresetModel? preset,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PresetFormSheet(
        category: category,
        preset: preset,
      ),
    );
  }
}

// ── Preset list tile ──────────────────────────────────────────────────────────

class _PresetTile extends ConsumerWidget {
  const _PresetTile({
    required this.preset,
    required this.categoryColor,
  });

  final DescriptionPresetModel preset;
  final Color categoryColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.label_rounded,
                size: 18, color: categoryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.label, style: AppTextStyles.bodyMedium),
                  if (preset.isDefault)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _DefaultBadge(),
                    ),
                ],
              ),
            ),
            if (!preset.isDefault) ...[
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: AppColors.textSecondary,
                tooltip: 'Edit',
                onPressed: () => _showEditSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.expense,
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PresetFormSheet(
        category: null,
        preset: preset,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Delete preset "${preset.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uid =
                  ref.read(authStateChangesProvider).asData?.value?.uid;
              if (uid == null) return;
              try {
                await ref
                    .read(categoryServiceProvider)
                    .softDeleteDescriptionPreset(uid, preset.presetId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Preset add/edit bottom sheet ──────────────────────────────────────────────

class _PresetFormSheet extends ConsumerStatefulWidget {
  const _PresetFormSheet({
    required this.category,
    required this.preset,
  });

  /// The parent category — only provided when adding a new preset.
  final CategoryModel? category;

  /// The preset to edit — null means add mode.
  final DescriptionPresetModel? preset;

  @override
  ConsumerState<_PresetFormSheet> createState() => _PresetFormSheetState();
}

class _PresetFormSheetState extends ConsumerState<_PresetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.preset != null;

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.preset?.label ?? '';
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(categoryServiceProvider);

      if (_isEditing) {
        await service.updateDescriptionPreset(
          uid,
          widget.preset!.presetId,
          {'label': _labelController.text.trim()},
        );
      } else {
        final now = DateTime.now();
        final newPreset = DescriptionPresetModel(
          presetId: '',
          categoryId: widget.category!.categoryId,
          label: _labelController.text.trim(),
          isDefault: false,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        );
        await service.addDescriptionPreset(uid, newPreset);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit Preset' : 'New Preset',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _labelController,
              enabled: !_isLoading,
              maxLength: 50,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Morning Coffee',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Label is required.';
                if (s.length > 50) return 'Label must be 50 characters or less.';
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.expense),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Preset'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Default badge ─────────────────────────────────────────────────────────────

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
