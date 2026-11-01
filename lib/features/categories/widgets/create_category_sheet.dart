import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/widgets/confirm_sheet.dart';
import 'package:ticky/features/categories/models/category_draft.dart';
import 'package:ticky/features/categories/models/category_options.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';

/// Bottom sheet to create a category. Returns the new category's id, or null
/// when dismissed.
Future<int?> showCreateCategorySheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const CreateCategorySheet(),
  );
}

/// Bottom sheet to rename, recolour or delete [category]. Returns its id when
/// saved, or null when dismissed or deleted.
Future<int?> showEditCategorySheet(BuildContext context, Category category) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CreateCategorySheet(category: category),
  );
}

/// Creates a category, or edits [category] when one is given.
class CreateCategorySheet extends ConsumerStatefulWidget {
  const CreateCategorySheet({super.key, this.category});

  final Category? category;

  @override
  ConsumerState<CreateCategorySheet> createState() =>
      _CreateCategorySheetState();
}

class _CreateCategorySheetState extends ConsumerState<CreateCategorySheet> {
  late final _name = TextEditingController(text: widget.category?.title);
  late String _iconKey = widget.category?.iconKey ?? categoryIcons.keys.first;
  late int _color = widget.category?.colorValue ?? categoryColors.first;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.category != null;

  /// General is the fallback for deleted categories, so it stays.
  bool get _canDelete => _editing && widget.category!.key != generalCategoryKey;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = CategoryDraft(
      title: _name.text,
      iconKey: _iconKey,
      colorValue: _color,
    );
    try {
      final repository = ref.read(categoryRepositoryProvider);
      final existing = widget.category;
      final int id;
      if (existing == null) {
        id = await repository.create(draft);
      } else {
        await repository.update(existing.id, draft);
        id = existing.id;
      }
      if (mounted) Navigator.of(context).pop(id);
    } on DataException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _delete() async {
    final category = widget.category!;
    final confirmed = await showConfirmSheet(
      context,
      title: 'Delete "${category.title}"?',
      message:
          'Its tasks move to General. Days you already finished keep their history.',
      keepLabel: 'Keep category',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(categoryRepositoryProvider).archive(category.id);
      if (mounted) Navigator.of(context).pop();
    } on DataException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: AppMotion.fast,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing ? 'Edit category' : 'New category',
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Name',
                counterText: '',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Icon',
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in categoryIcons.entries)
                  _IconChoice(
                    icon: entry.value,
                    label: entry.key.replaceAll('_', ' '),
                    color: Color(_color),
                    selected: entry.key == _iconKey,
                    onTap: () => setState(() => _iconKey = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Colour',
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final value in categoryColors)
                  _ColorChoice(
                    color: Color(value),
                    selected: value == _color,
                    onTap: () => setState(() => _color = value),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_editing ? 'Save' : 'Create category'),
            ),
            if (_canDelete) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: scheme.error,
                ),
                child: const Text('Delete category'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? color.withValues(alpha: 0.2)
                : scheme.surfaceContainerHigh,
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? color : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Colour',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 20, color: scheme.surface)
              : null,
        ),
      ),
    );
  }
}
