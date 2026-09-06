import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/category_model.dart';
import 'category_provider.dart';

/// Screen for adding or editing a category.
///
/// Pass [category] = null to create a new category.
/// Pass an existing [CategoryModel] to edit it.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, required this.category});

  final CategoryModel? category;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late String _selectedType;
  late int _selectedIconCode;
  late String _selectedColorHex;

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameController.text = cat?.name ?? '';
    _selectedType = cat?.type ?? 'expense';
    _selectedIconCode =
        cat?.iconCode ?? DefaultCategories.selectableIconCodes.first;
    _selectedColorHex =
        cat?.colorHex ?? DefaultCategories.selectableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

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
        await service.updateCategory(uid, widget.category!.categoryId, {
          'name': _nameController.text.trim(),
          'iconCode': _selectedIconCode,
          'colorHex': _selectedColorHex,
        });
      } else {
        final now = DateTime.now();
        final newCategory = CategoryModel(
          categoryId: '',
          name: _nameController.text.trim(),
          type: _selectedType,
          isDefault: false,
          isDeleted: false,
          iconCode: _selectedIconCode,
          colorHex: _selectedColorHex,
          createdAt: now,
          updatedAt: now,
        );
        await service.addCategory(uid, newCategory);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Category' : 'New Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Coffee Runs',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Name is required.';
                if (s.length > 30) return 'Name must be 30 characters or less.';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Type selector (only for new categories)
            if (!_isEditing) ...[
              Text('Type', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              _TypeSelector(
                selected: _selectedType,
                onChanged: _isLoading ? null : (t) => setState(() => _selectedType = t),
              ),
              const SizedBox(height: 20),
            ],

            // Icon picker
            Text('Icon', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            _IconPicker(
              selectedCode: _selectedIconCode,
              selectedColor: _selectedColorHex,
              onChanged: _isLoading
                  ? null
                  : (code) => setState(() => _selectedIconCode = code),
            ),
            const SizedBox(height: 20),

            // Colour picker
            Text('Colour', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            _ColorPicker(
              selectedHex: _selectedColorHex,
              onChanged: _isLoading
                  ? null
                  : (hex) => setState(() => _selectedColorHex = hex),
            ),

            // Error banner
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _errorMessage!),
            ],

            const SizedBox(height: 28),
            AppButton(
              label: _isEditing ? 'Save Changes' : 'Add Category',
              onPressed: _isLoading ? null : _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type selector ─────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, this.onChanged});

  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Expense',
          isSelected: selected == 'expense',
          color: AppColors.expense,
          onTap: onChanged == null ? null : () => onChanged!('expense'),
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: 'Income',
          isSelected: selected == 'income',
          color: AppColors.income,
          onTap: onChanged == null ? null : () => onChanged!('income'),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.titleMedium.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Icon picker ───────────────────────────────────────────────────────────────

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selectedCode,
    required this.selectedColor,
    this.onChanged,
  });

  final int selectedCode;
  final String selectedColor;
  final ValueChanged<int>? onChanged;

  Color get _activeColor {
    final hex = selectedColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final codes = DefaultCategories.selectableIconCodes;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: codes.length,
      itemBuilder: (_, i) {
        final code = codes[i];
        final isSelected = code == selectedCode;
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isSelected
                  ? _activeColor.withValues(alpha: 0.15)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? _activeColor : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              materialIconData(code),
              size: 22,
              color: isSelected ? _activeColor : AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

// ── Colour picker ─────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selectedHex, this.onChanged});

  final String selectedHex;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: DefaultCategories.selectableColors.map((hex) {
        final isSelected = hex == selectedHex;
        final color =
            Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.textPrimary : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

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
