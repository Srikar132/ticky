import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/feedback/app_feedback.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/providers/focus_providers.dart';
import 'package:ticky/features/focus/widgets/focus_block_views.dart';
import 'package:ticky/features/focus/widgets/focus_marks.dart';
import 'package:ticky/features/focus/widgets/focus_offer_panel.dart';
import 'package:ticky/features/focus/widgets/focus_sheet.dart';
import 'package:ticky/features/home/providers/home_providers.dart';

/// How many lines of the notebook the card previews.
const focusPreviewRows = 3;

/// Home: today's notebook, drawn as a sheet of dotted paper with a strip of
/// tape on top. A different material from the checklist's white cards, since
/// it holds the user's own words rather than routine tasks.
///
/// It stays small on purpose: the checklist below is what Home is for.
/// - Empty: one slim invitation.
/// - Yesterday's page to bring over: the question, once a day.
/// - Written: progress and the first few lines. Goals can be ticked right here.
class FocusCard extends ConsumerStatefulWidget {
  const FocusCard({super.key});

  @override
  ConsumerState<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends ConsumerState<FocusCard>
    with WidgetsBindingObserver {
  String? _key;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Save what is typed the moment the app leaves the screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final key = _key;
    if (key == null || state == AppLifecycleState.resumed) return;
    ref.read(focusDocProvider(key).notifier).flush();
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(todayKeyProvider).value;
    _key = key;
    if (key == null) return const SizedBox.shrink();
    final doc = ref.watch(focusDocProvider(key)).value;
    if (doc == null) return const SizedBox.shrink();

    final controller = ref.read(focusDocProvider(key).notifier);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.tickyColors;
    final progress = doc.progress;
    final offer = doc.offer;
    final empty = doc.isBlank;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final tint = progress.allDone ? colors.tileMint : colors.tileButter;

    void open({bool focusEnd = false}) =>
        showFocusSheet(context, key, focusEnd: focusEnd);

    final Widget body;
    if (empty && offer != null) {
      body = Column(
        key: const ValueKey('offer'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(progress: null),
          const SizedBox(height: AppSpacing.lg),
          FocusOfferPanel(
            offer: offer,
            todayKey: key,
            onAccept: ({required bool unfinishedOnly}) =>
                controller.acceptOffer(unfinishedOnly: unfinishedOnly),
            onDecline: controller.declineOffer,
          ),
        ],
      );
    } else if (empty) {
      body = _Invitation(
        key: const ValueKey('empty'),
        onStart: () => open(focusEnd: true),
      );
    } else {
      body = _Filled(
        key: const ValueKey('filled'),
        blocks: doc.blocks,
        progress: progress,
        onToggle: (block) {
          if (block.checked) {
            AppFeedback.tap();
          } else {
            AppFeedback.success();
          }
          controller.toggleTodo(block.id);
        },
      );
    }

    return Semantics(
      container: true,
      label: "Today's focus",
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : AppMotion.slow,
        curve: AppMotion.curve,
        decoration: BoxDecoration(color: tint, borderRadius: AppRadius.xlAll),
        child: ClipRRect(
          borderRadius: AppRadius.xlAll,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: DotGridPainter(
                      color: scheme.onSurface.withValues(alpha: 0.11),
                    ),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  enableFeedback: false,
                  onTap: () {
                    AppFeedback.tap();
                    open(focusEnd: empty && offer == null);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.lg + 4,
                    ),
                    child: AnimatedSize(
                      duration: reduce ? Duration.zero : AppMotion.medium,
                      curve: AppMotion.curve,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: reduce ? Duration.zero : AppMotion.medium,
                        child: body,
                      ),
                    ),
                  ),
                ),
              ),
              // A strip of washi tape holding the page to the screen.
              Positioned(
                top: -2,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.035,
                      child: Container(
                        width: 76,
                        height: 16,
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small caps label with its ink badge, and the progress ring when there
/// are goals.
class _Header extends StatelessWidget {
  const _Header({required this.progress});

  final FocusProgress? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final data = progress;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.inverseSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.edit_note_rounded,
            size: 18,
            color: scheme.onInverseSurface,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              "TODAY'S FOCUS",
              style: text.labelLarge?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        if (data != null && data.hasGoals) FocusRing(progress: data, size: 48),
      ],
    );
  }
}

/// An empty page: one slim line that invites writing.
class _Invitation extends StatelessWidget {
  const _Invitation({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  "TODAY'S FOCUS",
                  style: text.labelLarge?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text("What's the plan today?", style: text.titleLarge),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Semantics(
          button: true,
          label: 'Start writing',
          excludeSemantics: true,
          child: Material(
            color: scheme.inverseSurface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              enableFeedback: false,
              onTap: () {
                AppFeedback.tap();
                onStart();
              },
              child: SizedBox(
                width: AppSizes.roundButton + 2,
                height: AppSizes.roundButton + 2,
                child: Icon(
                  Icons.edit_rounded,
                  size: 20,
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Filled extends StatelessWidget {
  const _Filled({
    super.key,
    required this.blocks,
    required this.progress,
    required this.onToggle,
  });

  final List<FocusBlock> blocks;
  final FocusProgress progress;
  final void Function(FocusBlock block) onToggle;

  String get _headline {
    if (!progress.hasGoals) return 'Your notes for today';
    if (progress.allDone) {
      return progress.total == 1 ? 'Goal done' : 'All goals done';
    }
    return progress.total == 1
        ? '${progress.done} of 1 goal'
        : '${progress.done} of ${progress.total} goals';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(progress: progress),
        const SizedBox(height: AppSpacing.md),
        Text(_headline, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        FocusPreviewList(
          blocks: blocks,
          maxRows: focusPreviewRows,
          onToggle: onToggle,
        ),
      ],
    );
  }
}
