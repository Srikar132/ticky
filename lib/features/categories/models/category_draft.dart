import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/features/categories/models/category_options.dart';

/// Editable category fields, as entered when creating or editing a category.
class CategoryDraft {
  const CategoryDraft({
    required this.title,
    required this.iconKey,
    required this.colorValue,
  });

  final String title;

  /// Key into [categoryIcons].
  final String iconKey;

  /// Opaque ARGB colour.
  final int colorValue;

  String get trimmedTitle => title.trim();

  /// Throws [InvalidCategoryException] when a domain rule is broken.
  void validate() {
    final length = trimmedTitle.length;
    if (length < 1 || length > 40) {
      throw const InvalidCategoryException('Name must be 1-40 characters');
    }
    if (!categoryIcons.containsKey(iconKey)) {
      throw const InvalidCategoryException('Pick an icon from the list');
    }
    if ((colorValue >> 24) & 0xFF != 0xFF) {
      throw const InvalidCategoryException('Colour must be fully opaque');
    }
  }
}
