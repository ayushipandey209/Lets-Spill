import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/wordmark.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../../../profile/domain/user_profile.dart';
import '../bloc/feed_bloc.dart';

FeedPreferences preferencesOf(UserProfile? profile) => FeedPreferences(
  preferredCategoryIds: profile?.preferredCategoryIds ?? const [],
  includeMature: profile?.canSeeMature ?? false,
);

/// Home: greeting, Confession of the Day, tabs, filters and the feed.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final profile = context.read<SessionCubit>().state.profile;
    return BlocProvider(
      create: (context) => FeedBloc(
        repository: context.read<ConfessionRepository>(),
        pageSize: config.feedPageSize,
        preferences: preferencesOf(profile),
      )..add(const FeedStarted()),
      child: BlocListener<SessionCubit, SessionState>(
        listenWhen: (p, c) => p.profile != c.profile && c.profile != null,
        listener: (context, state) => context.read<FeedBloc>().add(
          FeedPreferencesChanged(preferencesOf(state.profile)),
        ),
        child: const FeedView(),
      ),
    );
  }
}

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final _scroll = ScrollController();
  static const _prefetchExtent = 600.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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

  void _open(Confession c) {
    Navigator.of(context).pushNamed(
      AppRoutes.confession,
      arguments: ConfessionRouteArgs(id: c.id, initial: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<CategoryCatalog>();
    final padding = responsiveHorizontalPadding(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'spill-fab',
        tooltip: 'Write a confession',
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.create),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Spill'),
      ),
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<FeedBloc, FeedState>(
          builder: (context, state) {
            final bloc = context.read<FeedBloc>();
            return RefreshIndicator(
              color: context.tokens.ink,
              backgroundColor: context.tokens.background,
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: padding.copyWith(top: AppSpacing.md),
                    sliver: const SliverToBoxAdapter(child: _Header()),
                  ),
                  if (state.featured != null)
                    SliverPadding(
                      padding: padding.copyWith(top: AppSpacing.md),
                      sliver: SliverToBoxAdapter(
                        child: _FeaturedCard(
                          confession: state.featured!,
                          categoryName: categories.nameOf(
                            state.featured!.categoryId,
                          ),
                          onTap: () => _open(state.featured!),
                        ),
                      ),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabsHeaderDelegate(
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
                      padding: padding.copyWith(top: AppSpacing.sm),
                      sliver: SliverToBoxAdapter(
                        child: _ForYouHint(
                          names: state.preferences.preferredCategoryIds
                              .map(categories.nameOf)
                              .toList(),
                        ),
                      ),
                    ),
                  ..._content(context, state, categories, padding),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    FeedState state,
    CategoryCatalog categories,
    EdgeInsets padding,
  ) {
    final bloc = context.read<FeedBloc>();
    switch (state.status) {
      case FeedStatus.initial:
      case FeedStatus.loading:
        return [
          SliverPadding(
            padding: padding.copyWith(top: AppSpacing.sm),
            sliver: SliverList.separated(
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
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
            const SliverFillRemaining(
              hasScrollBody: false,
              child: StatusMessage(
                icon: Icons.auto_stories_outlined,
                title: 'Nothing here yet',
                message: 'Be the first to spill. It stays anonymous.',
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: padding.copyWith(top: AppSpacing.sm),
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final c = state.items[i];
                return ConfessionCard(
                  key: ValueKey(c.id),
                  confession: c,
                  categories: categories,
                  onTap: () => _open(c),
                  saved: state.savedIds.contains(c.id),
                  onToggleSave: () => bloc.add(FeedSaveToggled(c.id)),
                );
              },
            ),
          ),
          SliverPadding(
            padding: padding.copyWith(top: AppSpacing.lg, bottom: 120),
            sliver: SliverToBoxAdapter(child: _Footer(state: state)),
          ),
        ];
    }
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profile = context.select((SessionCubit c) => c.state.profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Wordmark(size: 28)),
            IconButton(
              tooltip: 'Search confessions',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.search),
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Your profile',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.profile),
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${greetingFor(DateTime.now())},',
          style: context.text.bodyLarge!.copyWith(color: t.inkMuted),
        ),
        Text(
          profile?.handle ?? 'reader',
          style: context.text.headlineMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Inverted (black) hero card for the Confession of the Day.
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 16, color: muted),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Eyebrow(
                        'Confession of the day · $categoryName',
                        color: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '“${confession.text}”',
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge!
                      .copyWith(color: t.onInk, height: 1.45)
                      .withWeight(550),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(Icons.favorite_border, size: 16, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      '${confession.likeCount}',
                      style: context.text.labelMedium!.copyWith(color: muted),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(Icons.forum_outlined, size: 16, color: muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${confession.totalReactions} reactions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium!.copyWith(color: muted),
                      ),
                    ),
                    Text(
                      'Read',
                      style: context.text.labelLarge!.copyWith(color: t.onInk),
                    ),
                    Icon(Icons.arrow_forward, size: 18, color: t.onInk),
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
        ? 'Showing everything — pick favourites in your profile.'
        : 'Picked for you: ${names.join(', ')}';
    return Row(
      children: [
        Icon(Icons.tune, size: 16, color: context.tokens.inkMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: context.text.bodySmall)),
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});
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
        child: Text("You're all caught up.", style: context.text.bodySmall),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}

/// Pinned header: segmented tabs + category chips.
class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabsHeaderDelegate({
    required this.tab,
    required this.selectedCategoryId,
    required this.categories,
    required this.padding,
    required this.onTab,
    required this.onCategory,
  });

  final FeedTab tab;
  final String? selectedCategoryId;
  final CategoryCatalog categories;
  final EdgeInsets padding;
  final ValueChanged<FeedTab> onTab;
  final ValueChanged<String?> onCategory;

  static const _height = 116.0;

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
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: padding,
            child: _SegmentedTabs(selected: tab, onSelected: onTab),
          ),
          const SizedBox(height: AppSpacing.xs),
          CategoryFilterBar(
            categories: categories,
            selectedId: selectedCategoryId,
            onSelected: onCategory,
            padding: padding,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeaderDelegate oldDelegate) =>
      oldDelegate.tab != tab ||
      oldDelegate.selectedCategoryId != selectedCategoryId ||
      oldDelegate.padding != padding;
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onSelected});

  final FeedTab selected;
  final ValueChanged<FeedTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          for (final tab in FeedTab.values)
            Expanded(
              child: Semantics(
                selected: tab == selected,
                button: true,
                child: GestureDetector(
                  key: ValueKey('tab-${tab.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(tab),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tab == selected ? t.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge!.copyWith(
                        color: tab == selected ? t.onInk : t.ink,
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
