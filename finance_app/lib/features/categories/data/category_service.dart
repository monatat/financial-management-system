import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/default_categories.dart';
import '../domain/category_model.dart';
import '../domain/description_preset_model.dart';

/// Manages categories and description presets in Firestore.
///
/// Firestore paths:
///   users/{uid}/categories/{categoryId}
///   users/{uid}/descriptionPresets/{presetId}
///
/// IMPORTANT — Budget relationship:
/// Expense categories are the single source of truth for budget categories.
/// The Budget module must call [getExpenseCategories] — never maintain a
/// separate budget-category collection.
class CategoryService {
  CategoryService(this._firestore);

  final FirebaseFirestore _firestore;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _categories(String uid) =>
      _firestore.collection('users').doc(uid).collection('categories');

  CollectionReference<Map<String, dynamic>> _presets(String uid) =>
      _firestore.collection('users').doc(uid).collection('descriptionPresets');

  // ── Seeding ────────────────────────────────────────────────────────────────

  /// Seeds all default expense categories, income categories, and their
  /// description presets for a new user in a single batch write.
  ///
  /// This must be called only once per user. The caller is responsible for
  /// checking users/{uid}.isDefaultDataInitialized before calling this and
  /// for setting it to true after this completes.
  Future<void> seedDefaultCategoriesAndPresets(String uid) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    // Seed expense categories + their presets
    for (final data in DefaultCategories.expense) {
      final catRef = _categories(uid).doc();
      final catId = catRef.id;

      batch.set(catRef, {
        'categoryId': catId,
        'name': data.name,
        'type': 'expense',
        'isDefault': true,
        'isDeleted': false,
        'iconCode': data.iconCode,
        'colorHex': data.colorHex,
        'createdAt': now,
        'updatedAt': now,
      });

      for (final label in data.presets) {
        final presetRef = _presets(uid).doc();
        batch.set(presetRef, {
          'presetId': presetRef.id,
          'categoryId': catId,
          'label': label,
          'isDefault': true,
          'isDeleted': false,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    }

    // Seed income categories (no presets for income)
    for (final data in DefaultCategories.income) {
      final catRef = _categories(uid).doc();
      final catId = catRef.id;

      batch.set(catRef, {
        'categoryId': catId,
        'name': data.name,
        'type': 'income',
        'isDefault': true,
        'isDeleted': false,
        'iconCode': data.iconCode,
        'colorHex': data.colorHex,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    await batch.commit();
  }

  // ── Category reads ─────────────────────────────────────────────────────────

  /// Streams all non-deleted categories of a given type ("expense"/"income").
  /// Results are sorted: defaults first, then alphabetically.
  Stream<List<CategoryModel>> getCategories(String uid, String type) {
    return _categories(uid)
        .where('type', isEqualTo: type)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => CategoryModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      return list;
    });
  }

  /// Streams non-deleted expense categories.
  ///
  /// Used by: Transactions module (category picker),
  ///          Budget module (budget category list — expense categories ARE
  ///          budget categories; no separate collection needed).
  Stream<List<CategoryModel>> getExpenseCategories(String uid) =>
      getCategories(uid, 'expense');

  /// Streams non-deleted income categories.
  Stream<List<CategoryModel>> getIncomeCategories(String uid) =>
      getCategories(uid, 'income');

  // ── Category writes ────────────────────────────────────────────────────────

  /// Adds a new custom category.
  /// Throws [Exception] if a non-deleted category with the same name and type
  /// already exists for this user.
  Future<void> addCategory(String uid, CategoryModel category) async {
    await _checkDuplicateCategoryName(
      uid,
      name: category.name,
      type: category.type,
      excludeId: null,
    );

    final docRef = _categories(uid).doc();
    await docRef.set(
      category.copyWith(categoryId: docRef.id).toMap(),
    );
  }

  /// Updates fields on an existing category document.
  ///
  /// If 'name' is included in [data], a duplicate-name check is performed.
  ///
  /// TODO Phase 4/6: When name changes, batch-update the denormalized
  /// categoryName field on all existing transactions and budget documents
  /// that reference this categoryId. See blueprint Phase 8.
  Future<void> updateCategory(
    String uid,
    String categoryId,
    Map<String, dynamic> data,
  ) async {
    if (data.containsKey('name')) {
      final doc = await _categories(uid).doc(categoryId).get();
      final type = doc.data()?['type'] as String? ?? 'expense';
      await _checkDuplicateCategoryName(
        uid,
        name: data['name'] as String,
        type: type,
        excludeId: categoryId,
      );
    }

    await _categories(uid).doc(categoryId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-deletes a category and all its presets atomically.
  /// Hard delete is intentionally not supported to preserve referential
  /// integrity for transactions and budgets that reference this categoryId.
  Future<void> softDeleteCategory(String uid, String categoryId) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    batch.update(_categories(uid).doc(categoryId), {
      'isDeleted': true,
      'updatedAt': now,
    });

    // Soft-delete all presets belonging to this category.
    final presetSnap = await _presets(uid)
        .where('categoryId', isEqualTo: categoryId)
        .where('isDeleted', isEqualTo: false)
        .get();

    for (final doc in presetSnap.docs) {
      batch.update(doc.reference, {
        'isDeleted': true,
        'updatedAt': now,
      });
    }

    await batch.commit();
  }

  // ── Description preset reads ───────────────────────────────────────────────

  /// Streams non-deleted presets for [categoryId].
  /// Results are sorted: defaults first, then alphabetically.
  Stream<List<DescriptionPresetModel>> getDescriptionPresets(
    String uid,
    String categoryId,
  ) {
    return _presets(uid)
        .where('categoryId', isEqualTo: categoryId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => DescriptionPresetModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          return a.label.compareTo(b.label);
        });
      return list;
    });
  }

  // ── Description preset writes ──────────────────────────────────────────────

  /// Adds a new custom description preset.
  /// Throws [Exception] if a non-deleted preset with the same label already
  /// exists for this category.
  Future<void> addDescriptionPreset(
    String uid,
    DescriptionPresetModel preset,
  ) async {
    await _checkDuplicatePresetLabel(
      uid,
      categoryId: preset.categoryId,
      label: preset.label,
      excludeId: null,
    );

    final docRef = _presets(uid).doc();
    await docRef.set(
      preset.copyWith(presetId: docRef.id).toMap(),
    );
  }

  /// Updates fields on an existing preset document.
  /// If 'label' is included in [data], a duplicate-label check is performed.
  Future<void> updateDescriptionPreset(
    String uid,
    String presetId,
    Map<String, dynamic> data,
  ) async {
    if (data.containsKey('label')) {
      final doc = await _presets(uid).doc(presetId).get();
      final categoryId = doc.data()?['categoryId'] as String? ?? '';
      await _checkDuplicatePresetLabel(
        uid,
        categoryId: categoryId,
        label: data['label'] as String,
        excludeId: presetId,
      );
    }

    await _presets(uid).doc(presetId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-deletes a description preset.
  Future<void> softDeleteDescriptionPreset(
    String uid,
    String presetId,
  ) async {
    await _presets(uid).doc(presetId).update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _checkDuplicateCategoryName(
    String uid, {
    required String name,
    required String type,
    required String? excludeId,
  }) async {
    final snap = await _categories(uid)
        .where('type', isEqualTo: type)
        .where('name', isEqualTo: name.trim())
        .where('isDeleted', isEqualTo: false)
        .get();

    final conflict = snap.docs.any((doc) => doc.id != excludeId);
    if (conflict) {
      throw Exception('A $type category named "$name" already exists.');
    }
  }

  Future<void> _checkDuplicatePresetLabel(
    String uid, {
    required String categoryId,
    required String label,
    required String? excludeId,
  }) async {
    final snap = await _presets(uid)
        .where('categoryId', isEqualTo: categoryId)
        .where('label', isEqualTo: label.trim())
        .where('isDeleted', isEqualTo: false)
        .get();

    final conflict = snap.docs.any((doc) => doc.id != excludeId);
    if (conflict) {
      throw Exception('A preset labelled "$label" already exists for this category.');
    }
  }
}
