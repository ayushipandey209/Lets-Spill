import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/router.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../categories/domain/category.dart';
import '../confessions/presentation/confession_widgets.dart';
import '../settings/presentation/settings_cubit.dart';

/// Explore tab: search plus every category, like browsing communities.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.reselect, this.active = true});

  final ValueNotifier<int>? reselect;
  final bool active;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _scroll = ScrollController();

  static const _popular = [
    'first love',
    'boss',
    'exam',
    'ex',
    'mom',
    'best friend',
    'quit',
    'secret',
  ];

  @override
  void initState() {
    super.initState();
    widget.reselect?.addListener(_onReselect);
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

  void _search([String? query]) {
    Navigator.of(context).pushNamed(AppRoutes.search, arguments: query);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final categories = context.read<CategoryCatalog>().categories;
    final muted = context.select(
      (SettingsCubit c) => c.state.mutedCategoryIds,
    );
    final padding = responsiveHorizontalPadding(context, side: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: ListView(
        controller: _scroll,
        padding: padding.copyWith(top: AppSpacing.xs, bottom: AppSpacing.xxl),
        children: [
          Semantics(
            button: true,
            label: 'Search confessions',
            excludeSemantics: true,
            child: Material(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: InkWell(
                key: const ValueKey('explore-search'),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                onTap: _search,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20, color: t.inkMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Search confessions',
                        style: context.text.bodyMedium!.copyWith(
                          color: t.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Popular searches', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final q in _popular)
                SelectableCategoryChip(
                  label: q,
                  icon: Icons.trending_up,
                  selected: false,
                  onTap: () => _search(q),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle(
            'Categories',
            subtitle: 'Browse every confession in one topic.',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in categories) ...[
            _CategoryTile(category: c, muted: muted.contains(c.id)),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.muted});

  final Category category;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(color: t.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('explore-${category.id}'),
        onTap: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.category, arguments: category.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              CategoryAvatar(categoryId: category.id, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.name,
                            style: context.text.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (muted) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 15,
                            color: t.inkMuted,
                          ),
                        ],
                      ],
                    ),
                    if (category.description.isNotEmpty)
                      Text(
                        category.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
