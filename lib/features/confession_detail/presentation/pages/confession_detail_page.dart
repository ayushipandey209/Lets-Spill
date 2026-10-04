import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../../../reports/presentation/report_sheet.dart';
import '../bloc/confession_detail_cubit.dart';

/// Full reading view with like, share and report.
class ConfessionDetailPage extends StatelessWidget {
  const ConfessionDetailPage({
    super.key,
    required this.confessionId,
    this.initial,
  });

  final String confessionId;
  final Confession? initial;

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    return BlocProvider(
      create: (context) => ConfessionDetailCubit(
        repository: context.read<ConfessionRepository>(),
        shareService: context.read<ShareService>(),
        confessionId: confessionId,
        initial: initial,
        viewThreshold: config.viewThreshold,
      )..load(),
      child: const ConfessionDetailView(),
    );
  }
}

class ConfessionDetailView extends StatefulWidget {
  const ConfessionDetailView({super.key});

  @override
  State<ConfessionDetailView> createState() => _ConfessionDetailViewState();
}

/// Bridges route visibility + app lifecycle into the cubit's view timer:
/// * app paused/hidden → timer cancelled; resumed → restarts from zero;
/// * another route pushed on top → cancelled; popped back → restarts;
/// * this route disposed → cubit closed, timer cancelled.
class _ConfessionDetailViewState extends State<ConfessionDetailView>
    with WidgetsBindingObserver {
  late final ConfessionDetailCubit _cubit;
  final _shareKey = GlobalKey();
  ModalRoute<dynamic>? _route;
  bool _routeCurrent = true;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ConfessionDetailCubit>();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.secondaryAnimation?.removeStatusListener(_onSecondaryAnimation);
      _route = route;
      route?.secondaryAnimation?.addStatusListener(_onSecondaryAnimation);
    }
  }

  /// The secondary animation runs when another route covers this one.
  void _onSecondaryAnimation(AnimationStatus status) {
    final covered = status == AnimationStatus.completed ||
        status == AnimationStatus.forward;
    final next = !covered;
    if (next != _routeCurrent) {
      _routeCurrent = next;
      _updateVisibility();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updateVisibility();

  void _updateVisibility() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (foreground && _routeCurrent) {
      _cubit.onVisible();
    } else {
      _cubit.onHidden();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _route?.secondaryAnimation?.removeStatusListener(_onSecondaryAnimation);
    _cubit.onHidden();
    super.dispose();
  }

  Rect? _shareOrigin() {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<CategoryCatalog>();
    return BlocConsumer<ConfessionDetailCubit, ConfessionDetailState>(
      listenWhen: (p, c) => p.notice != c.notice && c.notice != null,
      listener: (context, state) => showNotice(context, state.notice!),
      builder: (context, state) {
        final confession = state.confession;
        return Scaffold(
          appBar: AppBar(
            title: confession == null
                ? null
                : Text(categories.nameOf(confession.categoryId)),
            actions: [
              if (confession != null)
                IconButton(
                  key: const ValueKey('detail-save'),
                  tooltip: state.isSaved ? 'Remove from saved' : 'Save',
                  onPressed: _cubit.toggleSaved,
                  icon: Icon(
                    state.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                ),
              if (confession != null)
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == 'report') _report(context, confession);
                    if (value == 'guidelines') {
                      Navigator.of(context).pushNamed(AppRoutes.guidelines);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: ListTile(
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Report confession'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'guidelines',
                      child: ListTile(
                        leading: Icon(Icons.menu_book_outlined),
                        title: Text('Community guidelines'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: switch (state.status) {
            DetailStatus.loading => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            DetailStatus.failure => StatusMessage(
              icon: Icons.hide_source_outlined,
              title: 'Unavailable',
              message: state.errorMessage,
              actionLabel: 'Try again',
              onAction: _cubit.load,
            ),
            DetailStatus.ready => _Body(
              state: state,
              categories: categories,
              shareKey: _shareKey,
              onLike: _cubit.toggleLike,
              onReact: _cubit.react,
              onShare: () => _cubit.share(origin: _shareOrigin()),
              onReport: () => _report(context, confession!),
            ),
          },
        );
      },
    );
  }

  Future<void> _report(BuildContext context, Confession confession) async {
    final submitted = await showReportSheet(context, confessionId: confession.id);
    if (submitted == true && context.mounted) {
      showMessage(
        context,
        'Thanks for reporting. Our moderators will review it.',
      );
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.categories,
    required this.shareKey,
    required this.onLike,
    required this.onReact,
    required this.onShare,
    required this.onReport,
  });

  final ConfessionDetailState state;
  final CategoryCatalog categories;
  final GlobalKey shareKey;
  final VoidCallback onLike;
  final ValueChanged<Reaction> onReact;
  final VoidCallback onShare;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = state.confession!;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Eyebrow(
              '${categories.nameOf(c.categoryId)} · ${c.authorDisplayName}'
              '${c.mature ? ' · 18+' : ''}',
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label: 'Confession text',
              child: Text(
                c.text,
                style: context.text.bodyLarge!.copyWith(fontSize: 19, height: 1.65),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ConfessionMeta(confession: c, fullDate: true, showLikes: false),
            const SizedBox(height: AppSpacing.lg),
            const HairlineDivider(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _LikeButton(
                    liked: state.isLiked,
                    count: c.likeCount,
                    busy: state.likeInFlight,
                    onPressed: onLike,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: shareKey,
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share, size: 20),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('How does this land?', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _ReactionBar(confession: c, mine: state.reaction, onReact: onReact),
            const SizedBox(height: AppSpacing.md),
            const HairlineDivider(),
            const SizedBox(height: AppSpacing.lg),
            NoteBox(
              icon: Icons.shield_outlined,
              child: Text(
                'Confessions are anonymous, unverified personal accounts — '
                'not established facts. If this names or identifies a real '
                'person, school or company, or feels harmful, please report it.',
                style: context.text.bodySmall!.copyWith(color: t.ink),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: onReport,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Report this confession'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.busy,
    required this.onPressed,
  });

  final bool liked;
  final int count;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = liked ? t.onInk : t.ink;
    final label = Formatters.compactCount(count);
    return Semantics(
      button: true,
      toggled: liked,
      label: liked ? 'Unlike. $count likes' : 'Like. $count likes',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: liked ? t.ink : Colors.transparent,
          borderRadius: AppRadii.button,
          border: Border.all(color: t.ink, width: 1.2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.button,
            onTap: busy ? null : onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(liked),
                      color: fg,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      liked ? 'Liked · $label' : 'Like · $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge!.copyWith(color: fg),
                    ),
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


/// Four one-tap reactions with live counts.
class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.confession,
    required this.mine,
    required this.onReact,
  });

  final Confession confession;
  final Reaction? mine;
  final ValueChanged<Reaction> onReact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (final r in Reaction.values) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: mine == r,
              label: '${r.label}, ${confession.reactionCount(r)}',
              excludeSemantics: true,
              child: AnimatedContainer(
                key: ValueKey('reaction-${r.name}'),
                duration: AppMotion.fast,
                decoration: BoxDecoration(
                  color: mine == r ? t.ink : t.background,
                  borderRadius: AppRadii.button,
                  border: Border.all(color: mine == r ? t.ink : t.border),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: AppRadii.button,
                    onTap: () => onReact(r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Icon(
                            reactionIcon(r),
                            size: 20,
                            color: mine == r ? t.onInk : t.ink,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.label,
                            style: context.text.labelMedium!.copyWith(
                              color: mine == r ? t.onInk : t.ink,
                            ),
                          ),
                          Text(
                            Formatters.compactCount(confession.reactionCount(r)),
                            style: context.text.labelSmall!.copyWith(
                              color: mine == r ? t.onInk : t.inkMuted,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (r != Reaction.values.last) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}
