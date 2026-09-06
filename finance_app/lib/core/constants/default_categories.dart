import 'package:flutter/material.dart';

/// Seed data for one default category.
class DefaultCategoryData {
  const DefaultCategoryData({
    required this.name,
    required this.iconCode,
    required this.colorHex,
    this.presets = const [],
  });

  final String name;
  final int iconCode;
  final String colorHex;

  /// Default description presets for this category (expense categories only).
  final List<String> presets;
}

/// All default categories and their description presets.
///
/// Called once per user by [CategoryService.seedDefaultCategoriesAndPresets]
/// immediately after account creation, then never again
/// (guarded by users/{uid}.isDefaultDataInitialized).
class DefaultCategories {
  DefaultCategories._();

  // ── Expense categories ─────────────────────────────────────────────────────

  static final List<DefaultCategoryData> expense = [
    DefaultCategoryData(
      name: 'Subscription',
      iconCode: Icons.subscriptions_rounded.codePoint,
      colorHex: '#8B5CF6',
      presets: [
        'Netflix',
        'Spotify',
        'YouTube Premium',
        'Disney+ Hotstar',
        'iCloud / Google One (Cloud Storage)',
        'Gym Membership',
        'Coway / Cuckoo (Water filter/appliance subscriptions)',
      ],
    ),
    DefaultCategoryData(
      name: 'Food & Drinks',
      iconCode: Icons.restaurant_rounded.codePoint,
      colorHex: '#F59E0B',
      presets: [
        'Breakfast',
        'Lunch',
        'Dinner',
        'Coffee / Boba',
        'Snacks / Desserts',
        'GrabFood / Foodpanda',
        'Groceries',
      ],
    ),
    DefaultCategoryData(
      name: 'Entertainment',
      iconCode: Icons.movie_rounded.codePoint,
      colorHex: '#EC4899',
      presets: [
        'Cinema / Movies',
        'Concert / Event Tickets',
        'Gaming / Steam Purchases',
        'Karaoke / Outing with Friends',
        'Hobbies',
      ],
    ),
    DefaultCategoryData(
      name: 'Shopping',
      iconCode: Icons.shopping_bag_rounded.codePoint,
      colorHex: '#3B82F6',
      presets: [
        'Clothing & Apparel',
        'Gadgets & Electronics',
        'Skincare / Cosmetics',
        'Home Decor / Personal Items',
        'Online Retail (Shopee/Lazada)',
      ],
    ),
    DefaultCategoryData(
      name: 'Transport',
      iconCode: Icons.directions_car_rounded.codePoint,
      colorHex: '#10B981',
      presets: [
        'Petrol / Fuel',
        "Touch 'n Go / Tolls",
        'Parking Fees',
        'E-Hailing (Grab/InDrive)',
        'Public Transport (LRT/MRT/Bus)',
        'Car Maintenance / Insurance',
      ],
    ),
    DefaultCategoryData(
      name: 'Utilities',
      iconCode: Icons.bolt_rounded.codePoint,
      colorHex: '#6366F1',
      presets: [
        'Electricity (TNB)',
        'Water Bill',
        'Mobile Phone Plan / Postpaid',
        'Home Internet (Unifi/Maxis Home)',
      ],
    ),
    DefaultCategoryData(
      name: 'Health',
      iconCode: Icons.medical_services_rounded.codePoint,
      colorHex: '#EF4444',
      presets: [
        'Clinic / Doctor Visit',
        'Pharmacy / Medicine',
        'Supplements / Vitamins',
        'Dental Checkup',
      ],
    ),
    DefaultCategoryData(
      name: 'Education',
      iconCode: Icons.school_rounded.codePoint,
      colorHex: '#0EA5E9',
      presets: [
        'Tuition Fees / Course Materials',
        'Books & Stationery',
        'Online Courses / Certifications',
      ],
    ),
    DefaultCategoryData(
      name: 'Rent',
      iconCode: Icons.home_rounded.codePoint,
      colorHex: '#64748B',
      presets: [
        'Monthly Room/House Rental',
        'Maintenance Fees',
      ],
    ),
    DefaultCategoryData(
      name: 'Other Expense',
      iconCode: Icons.category_rounded.codePoint,
      colorHex: '#9CA3AF',
      presets: [
        'Gifts / Donations',
        'Cash Withdrawal / Pocket Money',
        'Emergency Contingency',
      ],
    ),
  ];

  // ── Income categories ──────────────────────────────────────────────────────
  // Income categories do not have description presets.

  static final List<DefaultCategoryData> income = [
    DefaultCategoryData(
      name: 'Salary',
      iconCode: Icons.work_rounded.codePoint,
      colorHex: '#10B981',
    ),
    DefaultCategoryData(
      name: 'Allowance',
      iconCode: Icons.account_balance_wallet_rounded.codePoint,
      colorHex: '#22D3EE',
    ),
    DefaultCategoryData(
      name: 'Freelance',
      iconCode: Icons.laptop_rounded.codePoint,
      colorHex: '#A78BFA',
    ),
    DefaultCategoryData(
      name: 'Gift',
      iconCode: Icons.card_giftcard_rounded.codePoint,
      colorHex: '#F472B6',
    ),
    DefaultCategoryData(
      name: 'Scholarship',
      iconCode: Icons.emoji_events_rounded.codePoint,
      colorHex: '#FBBF24',
    ),
    DefaultCategoryData(
      name: 'Part-Time Job',
      iconCode: Icons.punch_clock_rounded.codePoint,
      colorHex: '#34D399',
    ),
    DefaultCategoryData(
      name: 'Other Income',
      iconCode: Icons.attach_money_rounded.codePoint,
      colorHex: '#6EE7B7',
    ),
  ];

  // ── Icon + colour palette offered in CategoryFormScreen ───────────────────

  /// Selectable icons for custom categories.
  static final List<int> selectableIconCodes = [
    Icons.subscriptions_rounded.codePoint,
    Icons.restaurant_rounded.codePoint,
    Icons.movie_rounded.codePoint,
    Icons.shopping_bag_rounded.codePoint,
    Icons.directions_car_rounded.codePoint,
    Icons.bolt_rounded.codePoint,
    Icons.medical_services_rounded.codePoint,
    Icons.school_rounded.codePoint,
    Icons.home_rounded.codePoint,
    Icons.category_rounded.codePoint,
    Icons.work_rounded.codePoint,
    Icons.account_balance_wallet_rounded.codePoint,
    Icons.laptop_rounded.codePoint,
    Icons.card_giftcard_rounded.codePoint,
    Icons.emoji_events_rounded.codePoint,
    Icons.attach_money_rounded.codePoint,
    Icons.coffee_rounded.codePoint,
    Icons.fitness_center_rounded.codePoint,
    Icons.local_atm_rounded.codePoint,
    Icons.savings_rounded.codePoint,
    Icons.flight_rounded.codePoint,
    Icons.pets_rounded.codePoint,
    Icons.phone_rounded.codePoint,
    Icons.local_grocery_store_rounded.codePoint,
  ];

  /// Selectable hex colours for custom categories.
  static const List<String> selectableColors = [
    '#8B5CF6', // Purple
    '#F59E0B', // Amber
    '#EC4899', // Pink
    '#3B82F6', // Blue
    '#10B981', // Green
    '#6366F1', // Indigo
    '#EF4444', // Red
    '#0EA5E9', // Cyan
    '#64748B', // Slate
    '#F97316', // Orange
    '#84CC16', // Lime
    '#06B6D4', // Teal
    '#A78BFA', // Violet
    '#FB923C', // Light orange
    '#34D399', // Emerald
    '#60A5FA', // Light blue
  ];
}
