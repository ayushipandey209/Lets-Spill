import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../confessions/presentation/confession_actions.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../settings/presentation/settings_cubit.dart';
import '../../domain/user_profile.dart';
import '../bloc/profile_cubit.dart';

/// "You" tab: anonymous identity, stats, and your Posts, Saved and Liked.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.reselect, this.active = true});

  final ValueNotifier<int>? reselect;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final profile = context.read<SessionCubit>().state.profile;
    if (profile == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => ProfileCubit(
        profile: profile,
        confessionRepository: context.read<ConfessionRepository>(),
        analytics: context.read<Analytics>(),
      )..load(),
      child: BlocListener<SessionCubit, SessionState>(
        listenWhen: (p, c) => p.profile != c.profile && c.profile != null,
        listener: (context, state) =>
            context.read<ProfileCubit>().profileChanged(state.profile!),
        child: ProfileView(reselect: reselect, active: active),
      ),
    );
  }
}

class ProfileView extends StatefulWidget {
  const ProfileView({super.key, this.reselect, this.active = true});

  final ValueNotifier<int>? reselect;
  final bool active;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.reselect?.addListener(_onReselect);
  }

  @override
  void didUpdateWidget(ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh counts when the tab is opened again.
    if (widget.active && !oldWidget.active) {
      context.read<ProfileCubit>().load();
    }
  }

  @override
  void dispose() {
    widget.reselect?.removeListener(_onReselect);
    _scroll.dispose();
    super.dispose();
  }

  void _onReselect() {
    if (widget.active && _scroll.hasClients) {
      _scroll.animateTo(0, duration: AppMotion.slow, curve: AppMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (p, c) => p.notice != c.notice && c.notice != null,
      listener: (context, state) => showNotice(context, state.notice!),
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('You'),
            actions: [
              IconButton(
                key: const ValueKey('open-settings'),
                tooltip: 'Settings',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: context.tokens.ink,
            backgroundColor: context.tokens.card,
            onRefresh: context.read<ProfileCubit>().load,
            child: _ProfileBody(state: state, controller: _scroll),
          ),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.state, required this.controller});

  final ProfileState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final categories = context.read<CategoryCatalog>();
    final settings = context.watch<SettingsCubit>().state;
    final cubit = context.read<ProfileCubit>();
    final list = state.current;
    final padding = responsiveHorizontalPadding(context, side: AppSpacing.sm);

    return ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding.copyWith(top: AppSpacing.xs, bottom: AppSpacing.xxl),
      children: [
        _IdentityCard(state: state),
        const SizedBox(height: AppSpacing.md),
        _SectionTabs(
          selected: state.section,
          counts: {
            ProfileSection.mine: state.myConfessions.length,
            ProfileSection.saved: state.saved.length,
            ProfileSection.liked: state.liked.length,
          },
          onSelected: cubit.selectSection,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.status == ProfileStatus.loading && list.isEmpty)
          for (var i = 0; i < 2; i++) ...[
            const ConfessionCardSkeleton(),
            const SizedBox(height: AppSpacing.sm),
          ]
        else if (state.status == ProfileStatus.failure)
          StatusMessage(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load your lists",
            message: state.errorMessage,
            actionLabel: 'Try again',
            onAction: cubit.load,
          )
        else if (list.isEmpty)
          _EmptySection(section: state.section)
        else
          for (final c in list) ...[
            ConfessionCard(
              key: ValueKey('${state.section.name}-${c.id}'),
              confession: c,
              categories: categories,
              compact: settings.feedLayout == FeedLayout.compact,
              maxLines: 4,
              blurMature: settings.blurMature,
              onTap: () => openConfession(
                context,
                c,
                source: 'profile_${state.section.name}',
              ),
              trailing: switch (state.section) {
                ProfileSection.mine =>
                  state.deletingIds.contains(c.id)
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : CardAction(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete this confession',
                          onPressed: () => _confirmDelete(context, c),
                        ),
                ProfileSection.saved => CardAction(
                  icon: Icons.bookmark,
                  tooltip: 'Remove from saved',
                  active: true,
                  onPressed: () => cubit.unsave(c.id),
                ),
                ProfileSection.liked => null,
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        if (state.status != ProfileStatus.failure && list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Center(
              child: Text(
                state.section == ProfileSection.mine
                    ? 'Only you can see which posts are yours.'
                    : 'Only you can see this list.',
                style: context.text.bodySmall!.copyWith(color: t.inkMuted),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Confession c) async {
    final cubit = context.read<ProfileCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this confession?'),
        content: const Text(
          'It will be removed for everyone, along with its likes, reactions '
          'and views. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.error,
              foregroundColor: context.tokens.onInk,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await cubit.deleteConfession(c.id);
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.state});
  final ProfileState state;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final UserProfile profile = state.profile;
    final joined = profile.createdAt;
    final initial = profile.username.isEmpty
        ? '?'
        : profile.username[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: t.ink, borderRadius: AppRadii.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent,
                ),
                child: Text(
                  initial,
                  style: context.text.headlineSmall!
                      .copyWith(color: t.onInk)
                      .withWeight(800),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall!.copyWith(
                        color: t.onInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (joined != null)
                          'Joined ${_months[joined.month - 1]} ${joined.year}',
                        'Age ${profile.ageRange.label}',
                      ].join('  ·  '),
                      style: context.text.bodySmall!.copyWith(
                        color: t.onInk.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Stat(label: 'Karma', value: state.karma),
              _Stat(label: 'Posts', value: state.myConfessions.length),
              _Stat(label: 'Reads', value: state.reads),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.compactCount(value),
              style: context.text.titleLarge!.copyWith(color: t.onInk),
            ),
            Text(
              label,
              style: context.text.labelMedium!.copyWith(
                color: t.onInk.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final ProfileSection selected;
  final Map<ProfileSection, int> counts;
  final ValueChanged<ProfileSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (final s in ProfileSection.values)
            Expanded(
              child: Semantics(
                selected: s == selected,
                button: true,
                child: GestureDetector(
                  key: ValueKey('section-${s.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(s),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s == selected ? t.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: s == selected
                          ? Border.all(color: t.border)
                          : null,
                    ),
                    child: Text(
                      '${s.label}  ${counts[s] ?? 0}',
                      maxLines: 1,
                      style: context.text.labelMedium!.copyWith(
                        color: s == selected ? t.ink : t.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.section});
  final ProfileSection section;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (section) {
      ProfileSection.mine => (
        Icons.edit_note_outlined,
        "You haven't spilled anything yet",
        'Tap Spill below to write your first confession.',
      ),
      ProfileSection.saved => (
        Icons.bookmark_border,
        'Nothing saved yet',
        'Tap the bookmark on any confession to keep it here.',
      ),
      ProfileSection.liked => (
        Icons.favorite_border,
        'No likes yet',
        'Confessions you like will show up here.',
      ),
    };
    return StatusMessage(icon: icon, title: title, message: message);
  }
}
