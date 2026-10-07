import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/common.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../settings/presentation/settings_cubit.dart';
import '../bloc/feed_bloc.dart';
import 'home_page.dart';

/// A single category, like a community page: header, Hot / New / Top and
/// the posts in it. Muted categories are still shown here.
class CategoryFeedPage extends StatelessWidget {
  const CategoryFeedPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final profile = context.read<SessionCubit>().state.profile;
    final settings = context.read<SettingsCubit>().state;
    return BlocProvider(
      create: (context) {
        final analytics = context.read<Analytics>()
          ..log(AnalyticsEvents.categoryOpen, {'category': categoryId});
        return FeedBloc(
          repository: context.read<ConfessionRepository>(),
          pageSize: config.feedPageSize,
          preferences: feedPreferencesFor(profile, settings),
          initialTab: FeedTab.hot,
          lockedCategoryId: categoryId,
          analytics: analytics,
        )..add(const FeedStarted());
      },
      child: BlocListener<SettingsCubit, AppSettings>(
        listener: (context, s) => context.read<FeedBloc>().add(
          FeedPreferencesChanged(
            feedPreferencesFor(context.read<SessionCubit>().state.profile, s),
          ),
        ),
        child: _CategoryFeedView(categoryId: categoryId),
      ),
    );
  }
}

class _CategoryFeedView extends StatefulWidget {
  const _CategoryFeedView({required this.categoryId});
  final String categoryId;

  @override
  State<_CategoryFeedView> createState() => _CategoryFeedViewState();
}

class _CategoryFeedViewState extends State<_CategoryFeedView> {
  final _scroll = ScrollController();

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
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 700) {
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
    final t = context.tokens;
    final catalog = context.read<CategoryCatalog>();
    final category = catalog.byId(widget.categoryId);
    final name = catalog.nameOf(widget.categoryId);
    final padding = responsiveHorizontalPadding(context, side: AppSpacing.sm);
    final muted = context.select(
      (SettingsCubit c) => c.state.mutedCategoryIds.contains(widget.categoryId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          final bloc = context.read<FeedBloc>();
          return RefreshIndicator(
            color: t.ink,
            backgroundColor: t.card,
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: padding.copyWith(top: AppSpacing.xs),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CategoryAvatar(categoryId: widget.categoryId, size: 52),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: context.text.headlineMedium),
                              if (category != null &&
                                  category.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  category.description,
                                  style: context.text.bodySmall,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              _MuteButton(
                                categoryId: widget.categoryId,
                                muted: muted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: FeedHeaderDelegate(
                    tabs: const [FeedTab.hot, FeedTab.latest, FeedTab.top],
                    tab: state.tab,
                    padding: padding,
                    onTab: (tab) => bloc.add(FeedTabSelected(tab)),
                  ),
                ),
                ...feedContentSlivers(
                  context,
                  state: state,
                  padding: padding,
                  source: 'category_${widget.categoryId}',
                  emptyTitle: 'No $name confessions yet',
                  emptyMessage: 'Start this one off. It stays anonymous.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.categoryId, required this.muted});

  final String categoryId;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SelectableCategoryChip(
      label: muted ? 'Muted in your feeds' : 'Mute in my feeds',
      icon: muted ? Icons.notifications_off_outlined : Icons.do_not_disturb_on_outlined,
      selected: muted,
      onTap: () {
        final cubit = context.read<SettingsCubit>();
        final ids = [...cubit.state.mutedCategoryIds];
        muted ? ids.remove(categoryId) : ids.add(categoryId);
        cubit.update(cubit.state.copyWith(mutedCategoryIds: ids));
        context.read<Analytics>().log(AnalyticsEvents.settingChanged, {
          'setting': 'muted_category',
          'value': muted ? 'unmuted' : 'muted',
          'category': categoryId,
        });
        showMessage(
          context,
          muted
              ? 'You will see this category in your feeds again.'
              : 'Muted. It stays hidden from Home, but you can still visit it here.',
        );
      },
    );
  }
}
