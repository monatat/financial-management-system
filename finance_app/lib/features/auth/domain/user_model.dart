import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.currency,
    required this.monthlyIncome,
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.isDefaultDataInitialized,
    required this.hasCompletedCurrencySetup,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String name;

  /// Always stored in lowercase.
  final String email;

  /// ISO 4217 currency code chosen during first-time setup (e.g. "MYR").
  /// Empty string ("") means the user has NOT yet completed currency setup.
  final String currency;

  final double monthlyIncome;
  final bool notificationsEnabled;
  final bool darkModeEnabled;

  /// False until default categories and description presets are seeded.
  final bool isDefaultDataInitialized;

  /// True once the user has selected their base currency in CurrencySetupScreen.
  /// New accounts start with false and are redirected to setup before app access.
  ///
  /// Backward-compatibility: existing accounts that already have a non-empty
  /// [currency] field are treated as complete by the router even if this flag
  /// is still false.
  final bool hasCompletedCurrencySetup;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Firestore serialization ────────────────────────────────────────────────

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      // Empty string for new users; "MYR" (or other code) for existing ones.
      currency: map['currency'] as String? ?? '',
      monthlyIncome: (map['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      darkModeEnabled: map['darkModeEnabled'] as bool? ?? false,
      isDefaultDataInitialized:
          map['isDefaultDataInitialized'] as bool? ?? false,
      hasCompletedCurrencySetup:
          map['hasCompletedCurrencySetup'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'currency': currency,
      'monthlyIncome': monthlyIncome,
      'notificationsEnabled': notificationsEnabled,
      'darkModeEnabled': darkModeEnabled,
      'isDefaultDataInitialized': isDefaultDataInitialized,
      'hasCompletedCurrencySetup': hasCompletedCurrencySetup,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? currency,
    double? monthlyIncome,
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    bool? isDefaultDataInitialized,
    bool? hasCompletedCurrencySetup,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      isDefaultDataInitialized:
          isDefaultDataInitialized ?? this.isDefaultDataInitialized,
      hasCompletedCurrencySetup:
          hasCompletedCurrencySetup ?? this.hasCompletedCurrencySetup,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
