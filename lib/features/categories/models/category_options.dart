import 'package:flutter/material.dart';

/// Curated icons a category can use. The database stores only the key, never
/// an icon code point, so icon tree-shaking keeps working.
///
/// Keys of the seeded default categories must stay in this map.
const categoryIcons = <String, IconData>{
  'check_circle': Icons.check_circle_outline,
  'favorite': Icons.favorite_border,
  'work': Icons.work_outline,
  'school': Icons.school_outlined,
  'home': Icons.home_outlined,
  'self_improvement': Icons.self_improvement,
  'fitness_center': Icons.fitness_center,
  'directions_run': Icons.directions_run,
  'water_drop': Icons.water_drop_outlined,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe_outlined,
  'medication': Icons.medication_outlined,
  'bedtime': Icons.bedtime_outlined,
  'wb_sunny': Icons.wb_sunny_outlined,
  'menu_book': Icons.menu_book_outlined,
  'lightbulb': Icons.lightbulb_outline,
  'code': Icons.code,
  'brush': Icons.brush_outlined,
  'music_note': Icons.music_note,
  'sports_esports': Icons.sports_esports_outlined,
  'groups': Icons.groups_outlined,
  'family_restroom': Icons.family_restroom,
  'pets': Icons.pets,
  'cleaning_services': Icons.cleaning_services_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
  'savings': Icons.savings_outlined,
  'flight': Icons.flight_takeoff,
};

/// Shown when a stored key is no longer in [categoryIcons].
const fallbackCategoryIcon = Icons.label_outline;

IconData iconForCategoryKey(String key) =>
    categoryIcons[key] ?? fallbackCategoryIcon;

/// Colour choices offered when creating or editing a category (ARGB).
const categoryColors = <int>[
  0xFF7C8DB5, // slate (General)
  0xFFE57373, // red (Health)
  0xFF64B5F6, // blue (Work)
  0xFFBA68C8, // purple (Study)
  0xFFFFB74D, // orange (Home)
  0xFF81C784, // green (Personal)
  0xFFF06292, // pink
  0xFF4DB6AC, // teal
  0xFFFFD54F, // amber
  0xFF7986CB, // indigo
  0xFFA1887F, // brown
  0xFF90A4AE, // blue grey
];
