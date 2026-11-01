import 'package:flutter/material.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/features/categories/models/category_options.dart';
import 'package:ticky/features/categories/widgets/create_category_sheet.dart';

/// Bottom sheet to pick a category, or create a new one. Returns the chosen
/// category id, or null when dismissed.
Future<int?> showCategoryPickerSheet(
  BuildContext context, {
  required List<Category> categories,
  required int selectedId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _CategoryPickerSheet(categories: categories, selectedId: selectedId),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
  });

  final List<Category> categories;
  final int selectedId;

  Future<void> _createNew(BuildContext context) async {
    final id = await showCreateCategorySheet(context);
    if (id != null && context.mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text('Category', style: text.titleLarge),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final category in categories)
                  ListTile(
                    leading: _CategoryDot(category: category),
                    title: Text(category.title),
                    trailing: category.id == selectedId
                        ? Icon(Icons.check_rounded, color: scheme.secondary)
                        : null,
                    selected: category.id == selectedId,
                    selectedColor: scheme.onSurface,
                    onTap: () => Navigator.of(context).pop(category.id),
                  ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: scheme.secondary,
                    ),
                  ),
                  title: const Text('New category'),
                  onTap: () => _createNew(context),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
      child: Icon(iconForCategoryKey(category.iconKey), size: 22, color: color),
    );
  }
}
