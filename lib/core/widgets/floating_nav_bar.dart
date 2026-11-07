import 'package:flutter/material.dart';
import 'package:ticky/core/feedback/app_feedback.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// One tab in the [FloatingNavBar].
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Used for tooltips and screen readers. No visible text.
  final String label;
}

/// A white pill that floats above the page with two tabs and a round add
/// button between them. The selected tab is a near-black rounded square with a
/// white icon.
///
/// Height of the bar plus its margin is [FloatingNavBar.reservedHeight]; pad
/// scrolling content by it so nothing hides behind the bar.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.left,
    required this.right,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    this.addLabel = 'New task',
  });

  /// Space the bar takes at the bottom, excluding the system inset.
  static const reservedHeight = 96.0;

  static const _tab = 54.0;

  final NavDestination left;
  final NavDestination right;

  /// 0 for [left], 1 for [right].
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm - 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavTab(
                    destination: left,
                    selected: selectedIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _AddButton(label: addLabel, onTap: onAdd),
                  const SizedBox(width: AppSpacing.xs),
                  _NavTab(
                    destination: right,
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Tooltip(
        message: destination.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            AppFeedback.tap();
            onTap();
          },
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            width: FloatingNavBar._tab + 8,
            height: FloatingNavBar._tab,
            decoration: BoxDecoration(
              color: selected ? scheme.inverseSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  key: ValueKey(selected),
                  size: 26,
                  color: selected ? scheme.onInverseSurface : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: scheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            enableFeedback: false,
            onTap: () {
              AppFeedback.tap();
              onTap();
            },
            child: SizedBox(
              width: FloatingNavBar._tab,
              height: FloatingNavBar._tab,
              child: Icon(Icons.add_rounded, size: 30, color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
