import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// A group of related form rows, set off by a hairline above and below. No box
/// and no fill: whitespace and the lines do the grouping.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const line = BorderSide(
      color: AppColors.outlineSoft,
      width: AppStroke.hairline,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: line),
      ),
      child: Column(children: children),
    );
  }
}

/// A text field with no box at all, for a title or notes that read like plain
/// text on the page. Validation messages still show underneath.
InputDecoration bareInputDecoration(
  BuildContext context, {
  required String hint,
  TextStyle? hintStyle,
  String? errorText,
}) {
  const none = InputBorder.none;
  return InputDecoration(
    hintText: hint,
    hintStyle: hintStyle,
    errorText: errorText,
    counterText: '',
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    border: none,
    enabledBorder: none,
    focusedBorder: none,
    errorBorder: none,
    focusedErrorBorder: none,
  );
}

/// A tappable row: icon, label, current value and an optional trailing widget.
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.error,
    this.subtitle,
    this.iconColor,
    this.dimmed = false,
  });

  final IconData icon;
  final String label;

  /// Colour of the icon. Defaults to the muted text colour.
  final Color? iconColor;

  /// Fades the whole row, for a setting that is currently switched off.
  final bool dimmed;

  /// What is currently chosen, shown on the right.
  final String? value;

  /// Small explanation under the label.
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the default chevron.
  final Widget? trailing;

  /// Validation message shown under the row.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: iconColor ?? scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: text.bodyLarge),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          value!,
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    trailing ??
                        (onTap == null
                            ? const SizedBox.shrink()
                            : Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              )),
                  ],
                ),
              ),
            ),
          ),
          if (error != null)
            FieldError(
              error!,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.md),
            ),
        ],
      ),
    );
  }
}

/// A [FormRow] whose trailing control is a switch. Tapping anywhere on the row
/// flips it. With a null [onChanged] the row is shown dimmed and does nothing.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return FormRow(
      icon: icon,
      label: label,
      subtitle: subtitle,
      dimmed: change == null,
      onTap: change == null ? null : () => change(!value),
      trailing: Switch(value: value, onChanged: change),
    );
  }
}

/// A small validation message in the error colour.
class FieldError extends StatelessWidget {
  const FieldError(
    this.message, {
    super.key,
    this.padding = const EdgeInsets.only(top: AppSpacing.xs),
  });

  final String message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small caption above a group of inputs.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
        top: AppSpacing.lg,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
