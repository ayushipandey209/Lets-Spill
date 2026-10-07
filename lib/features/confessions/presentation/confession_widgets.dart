import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
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

/// Icon for each category, like a community avatar.
IconData categoryIcon(String id) => switch (id) {
  'relationships' => Icons.favorite_border,
  'school' => Icons.school_outlined,
  'workplace' => Icons.work_outline,
  'friendship' => Icons.people_outline,
  'family' => Icons.home_outlined,
  'life' => Icons.wb_twilight_outlined,
  _ => Icons.tag,
};

/// Round category badge used on cards and category pages.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.categoryId, this.size = 28});

  final String categoryId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(categoryIcon(categoryId), size: size * 0.54, color: t.onInk),
    );
  }
}

/// Date, views, likes and reactions. Used on the reading screen.
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
          MetaStat(
            icon: Icons.visibility_outlined,
            count: views,
            style: style,
            color: iconColor,
          ),
          if (showLikes)
            MetaStat(
              icon: Icons.favorite_border,
              count: likes,
              style: style,
              color: iconColor,
            ),
          if (showReactions && confession.topReaction != null)
            MetaStat(
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

/// Small icon + compact number.
class MetaStat extends StatelessWidget {
  const MetaStat({
    super.key,
    required this.icon,
    required this.count,
    this.style,
    this.color,
  });

  final IconData icon;
  final int count;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          Formatters.compactCount(count),
          style: style ?? metaStyle(context),
        ),
      ],
    );
  }
}

/// Reddit style pill: heart and count, filled with the accent once liked.
class LikePill extends StatelessWidget {
  const LikePill({
    super.key,
    required this.liked,
    required this.count,
    required this.onPressed,
    this.dense = false,
  });

  final bool liked;
  final int count;
  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = liked ? t.accent : t.ink;
    return Semantics(
      button: true,
      toggled: liked,
      label: '${liked ? 'Unlike' : 'Like'}. $count ${count == 1 ? 'like' : 'likes'}',
      excludeSemantics: true,
      child: Material(
        color: liked ? t.accent.withValues(alpha: 0.12) : t.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 10 : 12,
              vertical: dense ? 5 : 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(liked),
                    size: dense ? 16 : 18,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  Formatters.compactCount(count),
                  style: context.text.labelMedium!.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button used in card action rows.
class CardAction extends StatelessWidget {
  const CardAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? t.ink : t.inkMuted;
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  if (label != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      label!,
                      style: context.text.labelMedium!.copyWith(color: color),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blurs mature text until the reader taps to reveal it.
class MatureBlur extends StatefulWidget {
  const MatureBlur({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<MatureBlur> createState() => _MatureBlurState();
}

class _MatureBlurState extends State<MatureBlur> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _revealed) return widget.child;
    final t = context.tokens;
    return Semantics(
      button: true,
      label: 'Mature content hidden. Double tap to show.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _revealed = true),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: ExcludeSemantics(child: widget.child),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: t.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined, size: 16, color: t.ink),
                  const SizedBox(width: 6),
                  Text('18+  Tap to view', style: context.text.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feed card. Card layout shows a long preview; compact layout fits more
/// posts on screen. Never shows who wrote it beyond "Anonymous" or the
/// author's generated handle.
class ConfessionCard extends StatelessWidget {
  const ConfessionCard({
    super.key,
    required this.confession,
    required this.categories,
    required this.onTap,
    this.compact = false,
    this.maxLines,
    this.trailing,
    this.liked,
    this.onLike,
    this.saved,
    this.onToggleSave,
    this.onShare,
    this.blurMature = false,
  });

  final Confession confession;
  final CategoryCatalog categories;
  final VoidCallback onTap;
  final bool compact;
  final int? maxLines;

  /// Replaces the bookmark button (e.g. a delete button on your own posts).
  final Widget? trailing;

  /// When non-null, an inline like pill is shown.
  final bool? liked;
  final VoidCallback? onLike;

  /// When non-null, a bookmark button is shown.
  final bool? saved;
  final VoidCallback? onToggleSave;
  final VoidCallback? onShare;
  final bool blurMature;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = confession;
    final categoryName = categories.nameOf(c.categoryId);
    final lines = maxLines ?? (compact ? 3 : 8);
    final pad = compact ? AppSpacing.sm : AppSpacing.md;

    final body = Text(
      c.text,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      style: compact ? context.text.bodyMedium : context.text.bodyLarge,
    );

    return Semantics(
      container: true,
      label: '$categoryName confession by ${c.authorDisplayName}',
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(
          borderRadius: compact ? AppRadii.button : AppRadii.card,
          side: BorderSide(color: t.border.withValues(alpha: t.isDark ? 1 : 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad - 4, compact ? 4 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _CardHeader(
                    confession: c,
                    categoryName: categoryName,
                    compact: compact,
                  ),
                ),
                SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: MatureBlur(enabled: blurMature && c.mature, child: body),
                ),
                SizedBox(height: compact ? AppSpacing.xxs : AppSpacing.xs),
                Row(
                  children: [
                    if (liked != null)
                      LikePill(
                        liked: liked!,
                        count: c.likeCount,
                        onPressed: onLike,
                        dense: compact,
                      )
                    else
                      MetaStat(icon: Icons.favorite_border, count: c.likeCount),
                    const SizedBox(width: AppSpacing.xs),
                    if (c.totalReactions > 0)
                      _ReactionSummary(confession: c),
                    const SizedBox(width: AppSpacing.xs),
                    MetaStat(
                      icon: Icons.visibility_outlined,
                      count: c.viewCount,
                    ),
                    const Spacer(),
                    if (onShare != null)
                      CardAction(
                        icon: Icons.ios_share,
                        tooltip: 'Share',
                        onPressed: onShare,
                      ),
                    if (trailing != null)
                      trailing!
                    else if (saved != null)
                      CardAction(
                        icon: saved! ? Icons.bookmark : Icons.bookmark_border,
                        tooltip: saved! ? 'Remove from saved' : 'Save',
                        active: saved!,
                        onPressed: onToggleSave,
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

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.confession,
    required this.categoryName,
    required this.compact,
  });

  final Confession confession;
  final String categoryName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final meta = metaStyle(context);
    final when = Formatters.relativeDate(confession.createdAt);
    return Row(
      children: [
        CategoryAvatar(categoryId: confession.categoryId, size: compact ? 22 : 28),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: compact
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: categoryName,
                        style: context.text.labelMedium!.withWeight(720),
                      ),
                      TextSpan(
                        text: '  ·  ${confession.authorDisplayName}  ·  $when',
                        style: meta,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge!.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${confession.authorDisplayName}  ·  $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta.copyWith(color: t.inkMuted),
                    ),
                  ],
                ),
        ),
        if (confession.mature) const MatureTag(),
      ],
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  const _ReactionSummary({required this.confession});
  final Confession confession;

  @override
  Widget build(BuildContext context) {
    final top = confession.topReaction;
    return MetaStat(
      icon: top == null ? Icons.add_reaction_outlined : reactionIcon(top),
      count: confession.totalReactions,
    );
  }
}

/// Small outlined "18+" badge.
class MatureTag extends StatelessWidget {
  const MatureTag({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: t.error),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '18+',
        style: context.text.labelSmall!.copyWith(
          color: t.error,
          letterSpacing: 0.4,
        ),
      ),
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
    Widget bar(double widthFactor, {double height = 11}) => FractionallySizedBox(
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: AppRadii.card,
        border: Border.all(color: t.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.skeleton,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: bar(0.35, height: 10)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < widget.lines; i++) ...[
            bar(i == widget.lines - 1 ? 0.6 : 1),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          const SizedBox(height: AppSpacing.xs),
          bar(0.3, height: 22),
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
      height: 44,
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
              icon: id == null ? null : categoryIcon(id),
              selected: id == selectedId,
              onTap: () => onSelected(id),
            ),
          );
        },
      ),
    );
  }
}

/// Pill-shaped toggle chip.
class SelectableCategoryChip extends StatelessWidget {
  const SelectableCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheck = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool showCheck;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.onInk : t.ink;
    final leading = showCheck && selected ? Icons.check : icon;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        decoration: ShapeDecoration(
          color: selected ? t.ink : t.card,
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
              constraints: const BoxConstraints(minHeight: 34, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      Icon(leading, size: 15, color: fg),
                      const SizedBox(width: 5),
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
