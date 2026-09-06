import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/category_service.dart';
import '../domain/category_model.dart';
import '../domain/description_preset_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(FirebaseFirestore.instance);
});

// ── Seeding ────────────────────────────────────────────────────────────────────

/// Seeds default categories and presets for the given [uid] exactly once.
///
/// Uses [FutureProvider.autoDispose.family] so:
///   - A separate instance runs per UID (different users get independent seeding).
///   - The instance auto-disposes when the user logs out and AppShell unmounts.
///   - Re-running when the same user logs back in is safe because the
///     isDefaultDataInitialized flag prevents double-seeding.
///
/// Watched by [AppShell]. While this provider is loading, the shell shows
/// a "Setting up your account…" overlay.
final seedingProvider =
    FutureProvider.autoDispose.family<void, String>((ref, uid) async {
  final userService = ref.read(userServiceProvider);
  final categoryService = ref.read(categoryServiceProvider);

  final profile = await userService.getUserProfile(uid);

  // Skip if profile is missing or seeding already completed.
  if (profile == null || profile.isDefaultDataInitialized) return;

  await categoryService.seedDefaultCategoriesAndPresets(uid);

  // Mark the user as initialised so seeding never runs again for this account.
  await userService.updateUserProfile(uid, {'isDefaultDataInitialized': true});
});

// ── Category list providers ────────────────────────────────────────────────────

/// Streams all non-deleted expense categories for the currently logged-in user.
///
/// Used by: Categories screen, Transaction add/edit form, Budget module.
/// The Budget module MUST use this provider — expense categories are the
/// single source of truth for budget categories.
final expenseCategoriesProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(categoryServiceProvider).getExpenseCategories(user.uid);
});

/// Streams all non-deleted income categories for the currently logged-in user.
final incomeCategoriesProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(categoryServiceProvider).getIncomeCategories(user.uid);
});

// ── Preset provider ────────────────────────────────────────────────────────────

/// Streams non-deleted description presets for a specific [categoryId].
/// Keyed by categoryId so each category gets its own cached stream.
final presetsForCategoryProvider = StreamProvider.autoDispose
    .family<List<DescriptionPresetModel>, String>((ref, categoryId) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(categoryServiceProvider)
      .getDescriptionPresets(user.uid, categoryId);
});
