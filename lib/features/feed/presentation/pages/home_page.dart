import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/wordmark.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/presentation/confession_actions.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../settings/presentation/settings_cubit.dart';
import '../bloc/feed_bloc.dart';

/// Feed preferences from the profile (age, interests) and settings.
FeedPreferences feedPreferencesFor(UserProfile? profile, AppSettings settings) {
  final canSeeMature = profile?.canSeeMature ?? false;
  return FeedPreferences(
    preferredCategoryIds: profile?.preferredCategoryIds ?? const [],
    includeMature: canSeeMature && settings.showMature,
    mutedCategoryIds: settings.mutedCategoryIds,
    showFeatured: settings.showConfessionOfDay,
  );
}

/// Home tab: Confession of the Day, sort tabs, category filters and feed.
class FeedView extends StatefulWidget {
  const FeedView({super.key, this.reselect, this.active = true});

  /// Bumped when Home is tapped again: scroll to top, then refresh.
  final ValueNotifier<int>? reselect;
  final bool active;

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final _scroll = ScrollController();
  static const _prefetchExtent = 700.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.reselect?.addListener(_onReselect);
  }

  @override
  void dispose() {
    widget.reselect?.removeListener(_onReselect);
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onReselect() {
    if (!widget.active || !_scroll.hasClients) return;
    if (_scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: AppMotion.slow,
        curve: AppMotion.curve,
      );
    } else {
      context.read<FeedBloc>().add(const FeedRefreshRequested());
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _prefetchExtent) {
      final bloc = context.read<FeedBloc>();
      final s = bloc.state;
      if (s.hasMore && !s.isLoadingMore && s.loadMoreError == null) {
        bloc.add(const FeedLoadMoreRequested());
      }
    }
  }

  Future<void> _refresh() async {
    final bloc = context.read<FeedBloc>()..add(const FeedRefreshRequested());
    await bloc.stream.firstWhere((s) => !s.isRefreshing);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<CategoryCatalog>();
    final padding = responsiveHorizontalPadding(context, side: AppSpacing.sm);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<FeedBloc, FeedState>(
          builder: (context, state) {
            final bloc = context.read<FeedBloc>();
            return RefreshIndicator(
              color: context.tokens.ink,
              backgroundColor: context.tokens.card,
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const _HomeAppBar(),
                  if (state.featured != null)
                    SliverPadding(
                      padding: padding.copyWith(top: AppSpacing.xs),
                      sliver: SliverToBoxAdapter(
                        child: _FeaturedCard(
                          confession: state.featured!,
                          categoryName: categories.nameOf(
                            state.featured!.categoryId,
                          ),
                          onTap: () {
                            context.read<Analytics>().log(
                              AnalyticsEvents.confessionOfDayOpen,
                              {'confession_id': state.featured!.id},
                            );
                            openConfession(
                              context,
                              state.featured!,
                              source: 'confession_of_the_day',
                            );
                          },
                        ),
                      ),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: FeedHeaderDelegate(
                      tabs: FeedTab.values,
                      tab: state.tab,
                      selectedCategoryId: state.selectedCategoryId,
                      categories: categories,
                      padding: padding,
                      onTab: (t) => bloc.add(FeedTabSelected(t)),
                      onCategory: (id) => bloc.add(FeedCategorySelected(id)),
                    ),
                  ),
                  if (state.tab == FeedTab.forYou &&
                      state.selectedCategoryId == null)
                    SliverPadding(
                      padding: padding.copyWith(top: AppSpacing.xs),
                      sliver: SliverToBoxAdapter(
                        child: _ForYouHint(
                          names: state.preferences.preferredCategoryIds
                              .map(categories.nameOf)
                              .toList(),
                        ),
                      ),
                    ),
                  ...feedContentSlivers(
                    context,
                    state: state,
                    padding: padding,
                    source: 'home_${state.tab.name}',
                    emptyTitle: 'Nothing here yet',
                    emptyMessage: 'Be the first to spill. It stays anonymous.',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The list part of any feed (home or a category page): skeletons, errors,
/// empty state, cards and the paging footer.
List<Widget> feedContentSlivers(
  BuildContext context, {
  required FeedState state,
  required EdgeInsets padding,
  required String source,
  required String emptyTitle,
  required String emptyMessage,
}) {
  final bloc = context.read<FeedBloc>();
  final categories = context.read<CategoryCatalog>();
  final settings = context.watch<SettingsCubit>().state;
  final compact = settings.feedLayout == FeedLayout.compact;
  final gap = compact ? AppSpacing.xs : AppSpacing.sm;
  switch (state.status) {
    case FeedStatus.initial:
    case FeedStatus.loading:
      return [
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.sm),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, _) => SizedBox(height: gap),
            itemBuilder: (_, i) => ConfessionCardSkeleton(lines: 3 + i % 2),
          ),
        ),
      ];
    case FeedStatus.failure:
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StatusMessage(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load confessions",
            message: state.errorMessage,
            actionLabel: 'Try again',
            onAction: () => bloc.add(const FeedRefreshRequested()),
          ),
        ),
      ];
    case FeedStatus.success:
      if (state.items.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: StatusMessage(
              icon: Icons.auto_stories_outlined,
              title: emptyTitle,
              message: emptyMessage,
            ),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.sm),
          sliver: SliverList.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, _) => SizedBox(height: gap),
            itemBuilder: (context, i) {
              final c = state.items[i];
              return ConfessionCard(
                key: ValueKey(c.id),
                confession: c,
                categories: categories,
                compact: compact,
                blurMature: settings.blurMature,
                onTap: () => openConfession(context, c, source: source),
                liked: state.likedIds.contains(c.id),
                onLike: () {
                  tapFeedback(context);
                  bloc.add(FeedLikeToggled(c.id));
                },
                saved: state.savedIds.contains(c.id),
                onToggleSave: () => bloc.add(FeedSaveToggled(c.id)),
                onShare: () => shareConfession(context, c, source: source),
              );
            },
          ),
        ),
        SliverPadding(
          padding: padding.copyWith(
            top: AppSpacing.lg,
            bottom: AppSpacing.xxl,
          ),
          sliver: SliverToBoxAdapter(child: FeedFooter(state: state)),
        ),
      ];
  }
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 22) return 'Good evening';
  return 'Up late';
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profile = context.select((SessionCubit c) => c.state.profile);
    return SliverAppBar(
      floating: true,
      snap: true,
      titleSpacing: AppSpacing.md,
      toolbarHeight: 60,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Wordmark(size: 23),
          Text(
            '${greetingFor(DateTime.now())}, ${profile?.handle ?? 'reader'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall!.copyWith(color: t.inkMuted),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Search confessions',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          icon: const Icon(Icons.tune),
        ),
        const SizedBox(width: AppSpacing.xxs),
      ],
    );
  }
}

/// Inverted hero card for the Confession of the Day.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.confession,
    required this.categoryName,
    required this.onTap,
  });

  final Confession confession;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final muted = t.onInk.withValues(alpha: 0.72);
    return Semantics(
      button: true,
      label: 'Confession of the day, $categoryName',
      child: Material(
        color: t.ink,
        borderRadius: AppRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 15, color: muted),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Eyebrow(
                        'Confession of the day  ·  $categoryName',
                        color: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '“${confession.text}”',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium!
                      .copyWith(color: t.onInk, height: 1.5)
                      .withWeight(540),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    MetaStat(
                      icon: Icons.favorite_border,
                      count: confession.likeCount,
                      color: muted,
                      style: context.text.labelMedium!.copyWith(color: muted),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    MetaStat(
                      icon: Icons.forum_outlined,
                      count: confession.totalReactions,
                      color: muted,
                      style: context.text.labelMedium!.copyWith(color: muted),
                    ),
                    const Spacer(),
                    Text(
                      'Read',
                      style: context.text.labelLarge!.copyWith(color: t.onInk),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 17, color: t.onInk),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForYouHint extends StatelessWidget {
  const _ForYouHint({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final text = names.isEmpty
        ? 'Showing everything. Pick your interests in Settings.'
        : 'Picked for you: ${names.join(', ')}';
    return Row(
      children: [
        Icon(Icons.auto_awesome_outlined, size: 15, color: context.tokens.inkMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.settings),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: context.text.labelMedium,
          ),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

class FeedFooter extends StatelessWidget {
  const FeedFooter({super.key, required this.state});
  final FeedState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.loadMoreError != null) {
      return Column(
        children: [
          Text(
            state.loadMoreError!,
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: () =>
                context.read<FeedBloc>().add(const FeedLoadMoreRequested()),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Load more'),
          ),
        ],
      );
    }
    if (!state.hasMore) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, color: context.tokens.inkMuted),
            const SizedBox(height: AppSpacing.xxs),
            Text("You're all caught up.", style: context.text.bodySmall),
          ],
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}

/// Pinned header: underlined sort tabs plus optional category chips.
class FeedHeaderDelegate extends SliverPersistentHeaderDelegate {
  FeedHeaderDelegate({
    required this.tabs,
    required this.tab,
    required this.padding,
    required this.onTab,
    this.selectedCategoryId,
    this.categories,
    this.onCategory,
  });

  final List<FeedTab> tabs;
  final FeedTab tab;
  final String? selectedCategoryId;
  final CategoryCatalog? categories;
  final EdgeInsets padding;
  final ValueChanged<FeedTab> onTab;
  final ValueChanged<String?>? onCategory;

  bool get _showCategories => categories != null && onCategory != null;

  double get _height => _showCategories ? 98 : 48;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.background,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent || shrinkOffset > 0
                ? t.border
                : t.border.withValues(alpha: 0),
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Padding(
              padding: padding,
              child: SortTabs(tabs: tabs, selected: tab, onSelected: onTab),
            ),
          ),
          if (_showCategories) ...[
            const SizedBox(height: 4),
            CategoryFilterBar(
              categories: categories!,
              selectedId: selectedCategoryId,
              onSelected: onCategory!,
              padding: padding,
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(FeedHeaderDelegate oldDelegate) =>
      oldDelegate.tab != tab ||
      oldDelegate.selectedCategoryId != selectedCategoryId ||
      oldDelegate.padding != padding ||
      oldDelegate.tabs != tabs;
}

/// Reddit style sort tabs with an underline under the selected one.
class SortTabs extends StatelessWidget {
  const SortTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<FeedTab> tabs;
  final FeedTab selected;
  final ValueChanged<FeedTab> onSelected;

  static IconData _icon(FeedTab tab) => switch (tab) {
    FeedTab.forYou => Icons.auto_awesome_outlined,
    FeedTab.hot => Icons.local_fire_department_outlined,
    FeedTab.latest => Icons.schedule,
    FeedTab.top => Icons.trending_up,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final tab in tabs)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xxs),
            child: Semantics(
              selected: tab == selected,
              button: true,
              child: InkWell(
                key: ValueKey('tab-${tab.name}'),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: () => onSelected(tab),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icon(tab),
                            size: 16,
                            color: tab == selected ? t.ink : t.inkMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            tab.label,
                            style: context.text.labelLarge!.copyWith(
                              color: tab == selected ? t.ink : t.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        height: 2.5,
                        width: tab == selected ? 28 : 0,
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
