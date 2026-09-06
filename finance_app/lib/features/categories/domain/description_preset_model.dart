import 'package:cloud_firestore/cloud_firestore.dart';

/// A suggested description text linked to one expense category.
///
/// Stored at: users/{uid}/descriptionPresets/{presetId}
///
/// When a user selects an expense category on the Add Transaction screen,
/// the app loads all non-deleted presets for that category and surfaces them
/// as quick-select chips or a dropdown.
class DescriptionPresetModel {
  const DescriptionPresetModel({
    required this.presetId,
    required this.categoryId,
    required this.label,
    required this.isDefault,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String presetId;

  /// FK → users/{uid}/categories/{categoryId}
  final String categoryId;

  final String label;

  /// True for the seeded default presets. Default presets cannot be hard-deleted.
  final bool isDefault;

  /// Soft-delete flag. Always filter isDeleted == false when querying.
  final bool isDeleted;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Firestore serialization ────────────────────────────────────────────────

  factory DescriptionPresetModel.fromMap(Map<String, dynamic> map) {
    return DescriptionPresetModel(
      presetId: map['presetId'] as String,
      categoryId: map['categoryId'] as String,
      label: map['label'] as String,
      isDefault: map['isDefault'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'presetId': presetId,
      'categoryId': categoryId,
      'label': label,
      'isDefault': isDefault,
      'isDeleted': isDeleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ── Immutable update ───────────────────────────────────────────────────────

  DescriptionPresetModel copyWith({
    String? presetId,
    String? categoryId,
    String? label,
    bool? isDefault,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DescriptionPresetModel(
      presetId: presetId ?? this.presetId,
      categoryId: categoryId ?? this.categoryId,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
