import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../categories/domain/category.dart';
import '../domain/confession.dart';

/// Monochrome icon for each reaction.
IconData reactionIcon(Reaction r) => switch (r) {
  Reaction.same => Icons.people_alt_outlined,
  Reaction.hugs => Icons.volunteer_activism_outlined,
  Reaction.wow => Icons.auto_awesome_outlined,
  Reaction.oof => Icons.sentiment_dissatisfied_outlined,
};

/// Date · views · likes · reactions. Used on cards and the reading screen.
class ConfessionMeta extends StatelessWidget {
  const ConfessionMeta({
    super.key,
    required this.confession,
    this.showLikes = true,
    this.showReactions = true,
    this.fullDate = false,
  });

  final Confession confession;
  final bool showLikes;
  final bool showReactions;
  final bool fullDate;

  @override
  Widget build(BuildContext context) {
    final style = metaStyle(context);
    final iconColor = context.tokens.inkMuted;
    final date = fullDate
        ? Formatters.fullDate(confession.createdAt)
        : Formatters.relativeDate(confession.createdAt);
    final views = confession.viewCount;
    final likes = confession.likeCount;

    return Semantics(
      label:
          'Posted $date. $views ${views == 1 ? 'view' : 'views'}'
          '${showLikes ? ', $likes ${likes == 1 ? 'like' : 'likes'}' : ''}.',
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(date, style: style),
          _IconCount(
            icon: Icons.visibility_outlined,
            count: views,
            style: style,
            color: iconColor,
          ),
          if (showLikes)
            _IconCount(
              icon: Icons.favorite_border,
              count: likes,
              style: style,
              color: iconColor,
            ),
          if (showReactions && confession.topReaction != null)
            _IconCount(
              icon: reactionIcon(confession.topReaction!),
              count: confession.totalReactions,
              style: style,
              color: iconColor,
            ),
        ],
      ),
    );
  }
}

class _IconCount extends StatelessWidget {
  const _IconCount({
    required this.icon,
    required this.count,
    required this.style,
    required this.color,
  });

  final IconData icon;
  final int count;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(Formatters.compactCount(count), style: style),
      ],
    );
  }
}

/// Feed card: category, excerpt and metadata. Text only, author-less.
class ConfessionCard extends StatelessWidget {
  const ConfessionCard({
    super.key,
    required this.confession,
    required this.categories,
    required this.onTap,
    this.maxLines = 7,
    this.trailing,
    this.saved,
    this.onToggleSave,
  });

  final Confession confession;
  final CategoryCatalog categories;
  final VoidCallback onTap;
  final int maxLines;
  final Widget? trailing;

  /// When non-null, a bookmark button is shown in the footer.
  final bool? saved;
  final VoidCallback? onToggleSave;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final categoryName = categories.nameOf(confession.categoryId);
    return Semantics(
      button: true,
      label: '$categoryName confession',
      child: Material(
        color: t.background,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md + 2,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Eyebrow(
                        confession.authorDisplayName == Confession.anonymousName
                            ? categoryName
                            : '$categoryName · ${confession.authorDisplayName}',
                      ),
                    ),
                    if (confession.mature) ...[
                      const _Tag('18+'),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  confession.text,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                const HairlineDivider(),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(child: ConfessionMeta(confession: confession)),
                    if (saved != null)
                      IconButton(
                        tooltip: saved! ? 'Remove from saved' : 'Save',
                        visualDensity: VisualDensity.compact,
                        onPressed: onToggleSave,
                        icon: Icon(
                          saved! ? Icons.bookmark : Icons.bookmark_border,
                          size: 20,
                        ),
                      ),
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

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: t.inkMuted),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(text, style: context.text.labelSmall),
    );
  }
}

/// Placeholder card shown while the first page loads.
class ConfessionCardSkeleton extends StatefulWidget {
  const ConfessionCardSkeleton({super.key, this.lines = 3});
  final int lines;

  @override
  State<ConfessionCardSkeleton> createState() => _ConfessionCardSkeletonState();
}

class _ConfessionCardSkeletonState extends State<ConfessionCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Widget bar(double widthFactor, {double height = 12}) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: t.skeleton,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(0.22, height: 10),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < widget.lines; i++) ...[
            bar(i == widget.lines - 1 ? 0.6 : 1),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          const SizedBox(height: AppSpacing.sm),
          bar(0.4, height: 10),
        ],
      ),
    );

    return ExcludeSemantics(
      child: reduceMotion
          ? card
          : FadeTransition(
              opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
              child: card,
            ),
    );
  }
}

/// Horizontally scrolling category filter: All + every category.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final CategoryCatalog categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final options = <(String?, String)>[
      (null, 'All'),
      for (final c in categories.categories) (c.id, c.name),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final (id, label) = options[i];
          return Center(
            child: SelectableCategoryChip(
              key: ValueKey('filter-${id ?? 'all'}'),
              label: label,
              selected: id == selectedId,
              onTap: () => onSelected(id),
            ),
          );
        },
      ),
    );
  }
}

/// Pill-shaped toggle chip in the monochrome style.
class SelectableCategoryChip extends StatelessWidget {
  const SelectableCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.onInk : t.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        decoration: ShapeDecoration(
          color: selected ? t.ink : t.background,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? t.ink : t.border),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showCheck && selected) ...[
                      Icon(Icons.check, size: 16, color: fg),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    Text(
                      label,
                      style: context.text.labelMedium!.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
