import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/categories/models/category_options.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';
import 'package:ticky/features/categories/widgets/create_category_sheet.dart';

/// Categories: tap to rename, recolour or delete; add a new one.
class CategoriesSection extends ConsumerWidget {
  const CategoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(activeCategoriesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Categories'),
        FormCard(
          children: [
            for (final category in categories) ...[
              FormRow(
                key: ValueKey('category-${category.id}'),
                icon: iconForCategoryKey(category.iconKey),
                iconColor: Color(category.colorValue),
                label: category.title,
                value: category.key == generalCategoryKey ? 'Default' : null,
                onTap: () => showEditCategorySheet(context, category),
              ),
              const Divider(),
            ],
            FormRow(
              icon: Icons.add_rounded,
              label: 'New category',
              onTap: () => showCreateCategorySheet(context),
            ),
          ],
        ),
      ],
    );
  }
}
