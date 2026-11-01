/// Stable key of the fallback category. It can never be archived.
const generalCategoryKey = 'general';

/// A category seeded on first launch.
class DefaultCategory {
  const DefaultCategory({
    required this.key,
    required this.title,
    required this.iconKey,
    required this.colorValue,
  });

  final String key;
  final String title;
  final String iconKey;
  final int colorValue;
}

/// Seeded in order, so `sortOrder` follows list position.
const defaultCategories = <DefaultCategory>[
  DefaultCategory(
    key: generalCategoryKey,
    title: 'General',
    iconKey: 'check_circle',
    colorValue: 0xFF7C8DB5,
  ),
  DefaultCategory(
    key: 'health',
    title: 'Health',
    iconKey: 'favorite',
    colorValue: 0xFFE57373,
  ),
  DefaultCategory(
    key: 'work',
    title: 'Work',
    iconKey: 'work',
    colorValue: 0xFF64B5F6,
  ),
  DefaultCategory(
    key: 'study',
    title: 'Study',
    iconKey: 'school',
    colorValue: 0xFFBA68C8,
  ),
  DefaultCategory(
    key: 'home',
    title: 'Home',
    iconKey: 'home',
    colorValue: 0xFFFFB74D,
  ),
  DefaultCategory(
    key: 'personal',
    title: 'Personal',
    iconKey: 'self_improvement',
    colorValue: 0xFF81C784,
  ),
];
