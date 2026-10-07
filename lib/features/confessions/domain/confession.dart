import 'package:equatable/equatable.dart';

/// Moderation status of a confession. Only [published] is shown in feeds.
enum ConfessionStatus {
  published,
  hidden,
  removed;

  static ConfessionStatus parse(Object? raw) {
    return ConfessionStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => ConfessionStatus.published,
    );
  }
}

/// Quick, one-tap reactions. All supportive: there is no way to dislike
/// someone's confession. A reader can pick at most one per confession.
enum Reaction {
  same('Same'),
  hugs('Hugs'),
  wow('Wow');

  const Reaction(this.label);
  final String label;

  static Reaction? parse(Object? raw) {
    for (final r in Reaction.values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

/// A public confession. Shows either "Anonymous" or the author's generated
/// anonymous handle, never a real name, email or account id.
class Confession extends Equatable {
  const Confession({
    required this.id,
    required this.categoryId,
    required this.text,
    required this.createdAt,
    this.likeCount = 0,
    this.viewCount = 0,
    this.saveCount = 0,
    this.reactionCounts = const {},
    this.mature = false,
    this.authorDisplayName = anonymousName,
    this.status = ConfessionStatus.published,
  });

  factory Confession.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactionCounts'];
    final reactions = <Reaction, int>{};
    if (rawReactions is Map<String, dynamic>) {
      rawReactions.forEach((key, value) {
        final r = Reaction.parse(key);
        if (r != null && value is num) reactions[r] = value.toInt();
      });
    }
    return Confession(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      reactionCounts: Map.unmodifiable(reactions),
      mature: (json['mature'] as bool?) ?? false,
      authorDisplayName:
          (json['authorDisplayName'] as String?) ?? anonymousName,
      status: ConfessionStatus.parse(json['status']),
    );
  }

  static const anonymousName = 'Anonymous';

  final String id;
  final String categoryId;
  final String text;
  final DateTime createdAt;
  final int likeCount;
  final int viewCount;

  /// How many readers bookmarked it.
  final int saveCount;
  final Map<Reaction, int> reactionCounts;

  /// Adult themes (e.g. affairs). Hidden from readers aged 13 to 17.
  final bool mature;

  /// "Anonymous" or an anonymous handle like "@QuietComet27".
  final String authorDisplayName;
  final ConfessionStatus status;

  int get totalReactions =>
      reactionCounts.values.fold(0, (sum, count) => sum + count);

  int reactionCount(Reaction r) => reactionCounts[r] ?? 0;

  /// The most-used reaction, if any.
  Reaction? get topReaction {
    Reaction? best;
    var bestCount = 0;
    for (final entry in reactionCounts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  Confession copyWith({
    int? likeCount,
    int? viewCount,
    int? saveCount,
    Map<Reaction, int>? reactionCounts,
    ConfessionStatus? status,
  }) {
    return Confession(
      id: id,
      categoryId: categoryId,
      text: text,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
      saveCount: saveCount ?? this.saveCount,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      mature: mature,
      authorDisplayName: authorDisplayName,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'likeCount': likeCount,
    'viewCount': viewCount,
    'saveCount': saveCount,
    'reactionCounts': {
      for (final e in reactionCounts.entries) e.key.name: e.value,
    },
    'mature': mature,
    'authorDisplayName': authorDisplayName,
    'status': status.name,
  };

  @override
  List<Object?> get props => [
    id,
    categoryId,
    text,
    createdAt,
    likeCount,
    viewCount,
    saveCount,
    reactionCounts,
    mature,
    authorDisplayName,
    status,
  ];
}

/// How the feed is ordered.
enum FeedSort {
  /// Newest first.
  latest,

  /// Engagement weighted by recency (see `Ranking.hotScore`).
  hot,

  /// Most liked of all time.
  top,
}

/// What to load in a feed or search.
class FeedQuery extends Equatable {
  const FeedQuery({
    this.sort = FeedSort.latest,
    this.categoryIds,
    this.includeMature = true,
    this.search,
  });

  final FeedSort sort;

  /// `null` = all categories.
  final Set<String>? categoryIds;
  final bool includeMature;

  /// Case-insensitive keyword search across text and category.
  final String? search;

  bool get hasSearch => (search?.trim().length ?? 0) >= 2;

  @override
  List<Object?> get props => [sort, categoryIds, includeMature, search];
}

/// One page of feed results.
class ConfessionPage extends Equatable {
  const ConfessionPage({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<Confession> items;
  final bool hasMore;

  /// Opaque cursor. Pass back to fetch the next page.
  final Object? cursor;

  @override
  List<Object?> get props => [items, hasMore, cursor];
}

/// Local change notifications so screens stay in sync (e.g. a like on the
/// detail page updates the feed card).
sealed class ConfessionChange extends Equatable {
  const ConfessionChange();
}

class ConfessionCreated extends ConfessionChange {
  const ConfessionCreated(this.confession);
  final Confession confession;
  @override
  List<Object?> get props => [confession];
}

class ConfessionUpdated extends ConfessionChange {
  const ConfessionUpdated(this.confession);
  final Confession confession;
  @override
  List<Object?> get props => [confession];
}

class ConfessionDeleted extends ConfessionChange {
  const ConfessionDeleted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// A confession was saved or unsaved.
class ConfessionSavedChanged extends ConfessionChange {
  const ConfessionSavedChanged(this.confession, {required this.saved});
  final Confession confession;
  final bool saved;
  @override
  List<Object?> get props => [confession, saved];
}

/// The signed-in reader liked or unliked a confession.
class ConfessionLikedChanged extends ConfessionChange {
  const ConfessionLikedChanged(this.confession, {required this.liked});
  final Confession confession;
  final bool liked;
  @override
  List<Object?> get props => [confession, liked];
}
