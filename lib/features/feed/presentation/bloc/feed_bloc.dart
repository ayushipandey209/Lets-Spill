import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';

/// Feed sorts shown as tabs.
enum FeedTab {
  forYou('For you', FeedSort.hot),
  hot('Hot', FeedSort.hot),
  latest('New', FeedSort.latest),
  top('Top', FeedSort.top);

  const FeedTab(this.label, this.sort);
  final String label;
  final FeedSort sort;
}

/// What the reader chose in onboarding, their profile and settings.
class FeedPreferences extends Equatable {
  const FeedPreferences({
    this.preferredCategoryIds = const [],
    this.includeMature = true,
    this.mutedCategoryIds = const [],
    this.showFeatured = true,
  });

  final List<String> preferredCategoryIds;
  final bool includeMature;

  /// Hidden from every feed except that category's own page.
  final List<String> mutedCategoryIds;

  /// Show the Confession of the Day card.
  final bool showFeatured;

  @override
  List<Object?> get props => [
    preferredCategoryIds,
    includeMature,
    mutedCategoryIds,
    showFeatured,
  ];
}

// ----------------------------------------------------------------- events ---

sealed class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => [];
}

class FeedStarted extends FeedEvent {
  const FeedStarted();
}

class FeedTabSelected extends FeedEvent {
  const FeedTabSelected(this.tab);
  final FeedTab tab;
  @override
  List<Object?> get props => [tab];
}

/// `null` selects every category.
class FeedCategorySelected extends FeedEvent {
  const FeedCategorySelected(this.categoryId);
  final String? categoryId;
  @override
  List<Object?> get props => [categoryId];
}

class FeedRefreshRequested extends FeedEvent {
  const FeedRefreshRequested();
}

class FeedLoadMoreRequested extends FeedEvent {
  const FeedLoadMoreRequested();
}

class FeedPreferencesChanged extends FeedEvent {
  const FeedPreferencesChanged(this.preferences);
  final FeedPreferences preferences;
  @override
  List<Object?> get props => [preferences];
}

class FeedSaveToggled extends FeedEvent {
  const FeedSaveToggled(this.confessionId);
  final String confessionId;
  @override
  List<Object?> get props => [confessionId];
}

class FeedLikeToggled extends FeedEvent {
  const FeedLikeToggled(this.confessionId);
  final String confessionId;
  @override
  List<Object?> get props => [confessionId];
}

class _FeedChangeReceived extends FeedEvent {
  const _FeedChangeReceived(this.change);
  final ConfessionChange change;
  @override
  List<Object?> get props => [change];
}

// ------------------------------------------------------------------ state ---

enum FeedStatus { initial, loading, success, failure }

class FeedState extends Equatable {
  const FeedState({
    this.status = FeedStatus.initial,
    this.tab = FeedTab.forYou,
    this.selectedCategoryId,
    this.lockedCategoryId,
    this.preferences = const FeedPreferences(),
    this.items = const [],
    this.hasMore = true,
    this.cursor,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.featured,
    this.savedIds = const {},
    this.likedIds = const {},
    this.pendingLikes = const {},
    this.errorMessage,
    this.loadMoreError,
  });

  final FeedStatus status;
  final FeedTab tab;
  final String? selectedCategoryId;

  /// Set on a category page: the feed never leaves this category.
  final String? lockedCategoryId;
  final FeedPreferences preferences;
  final List<Confession> items;
  final bool hasMore;
  final Object? cursor;
  final bool isLoadingMore;
  final bool isRefreshing;

  /// Confession of the Day.
  final Confession? featured;
  final Set<String> savedIds;
  final Set<String> likedIds;

  /// Likes being written right now (taps are ignored meanwhile).
  final Set<String> pendingLikes;
  final String? errorMessage;
  final String? loadMoreError;

  /// The category this feed is narrowed to, if any.
  String? get activeCategoryId => lockedCategoryId ?? selectedCategoryId;

  FeedQuery get query {
    final active = activeCategoryId;
    Set<String>? categories;
    if (active != null) {
      categories = {active};
    } else if (tab == FeedTab.forYou &&
        preferences.preferredCategoryIds.isNotEmpty) {
      final picked = preferences.preferredCategoryIds.toSet()
        ..removeAll(preferences.mutedCategoryIds);
      if (picked.isNotEmpty) categories = picked;
    }
    return FeedQuery(
      sort: tab.sort,
      categoryIds: categories,
      includeMature: preferences.includeMature,
    );
  }

  /// Hides muted categories unless the reader picked that category.
  bool isVisible(Confession c) {
    if (!preferences.includeMature && c.mature) return false;
    final active = activeCategoryId;
    if (active != null) return c.categoryId == active;
    return !preferences.mutedCategoryIds.contains(c.categoryId);
  }

  FeedState copyWith({
    FeedStatus? status,
    FeedTab? tab,
    String? Function()? selectedCategoryId,
    FeedPreferences? preferences,
    List<Confession>? items,
    bool? hasMore,
    Object? Function()? cursor,
    bool? isLoadingMore,
    bool? isRefreshing,
    Confession? Function()? featured,
    Set<String>? savedIds,
    Set<String>? likedIds,
    Set<String>? pendingLikes,
    String? Function()? errorMessage,
    String? Function()? loadMoreError,
  }) {
    return FeedState(
      status: status ?? this.status,
      tab: tab ?? this.tab,
      selectedCategoryId: selectedCategoryId != null
          ? selectedCategoryId()
          : this.selectedCategoryId,
      lockedCategoryId: lockedCategoryId,
      preferences: preferences ?? this.preferences,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor != null ? cursor() : this.cursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      featured: featured != null ? featured() : this.featured,
      savedIds: savedIds ?? this.savedIds,
      likedIds: likedIds ?? this.likedIds,
      pendingLikes: pendingLikes ?? this.pendingLikes,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      loadMoreError: loadMoreError != null
          ? loadMoreError()
          : this.loadMoreError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    tab,
    selectedCategoryId,
    lockedCategoryId,
    preferences,
    items,
    hasMore,
    cursor,
    isLoadingMore,
    isRefreshing,
    featured,
    savedIds,
    likedIds,
    pendingLikes,
    errorMessage,
    loadMoreError,
  ];
}

// ------------------------------------------------------------------- bloc ---

/// A feed of confessions: Confession of the Day, sort tabs, category
/// filters, pagination, inline likes and saves. Also powers category pages
/// (with [lockedCategoryId]).
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({
    required ConfessionRepository repository,
    required this.pageSize,
    FeedPreferences preferences = const FeedPreferences(),
    FeedTab initialTab = FeedTab.forYou,
    String? lockedCategoryId,
    Analytics analytics = const NoopAnalytics(),
  }) : _repository = repository,
       _analytics = analytics,
       super(
         FeedState(
           preferences: preferences,
           tab: lockedCategoryId != null && initialTab == FeedTab.forYou
               ? FeedTab.hot
               : initialTab,
           lockedCategoryId: lockedCategoryId,
         ),
       ) {
    on<FeedStarted>(_onStarted, transformer: restartable());
    on<FeedTabSelected>(_onTab, transformer: restartable());
    on<FeedCategorySelected>(_onCategory, transformer: restartable());
    on<FeedPreferencesChanged>(_onPreferences, transformer: restartable());
    on<FeedRefreshRequested>(_onRefresh, transformer: restartable());
    on<FeedLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<FeedSaveToggled>(_onSaveToggled);
    on<FeedLikeToggled>(_onLikeToggled);
    on<_FeedChangeReceived>(_onChange);
    _changesSub = _repository.changes.listen(
      (c) => add(_FeedChangeReceived(c)),
    );
  }

  final ConfessionRepository _repository;
  final Analytics _analytics;
  final int pageSize;
  late final StreamSubscription<ConfessionChange> _changesSub;
  int _generation = 0;

  bool get _isCategoryPage => state.lockedCategoryId != null;

  Future<void> _onStarted(FeedStarted event, Emitter<FeedState> emit) async {
    if (state.status == FeedStatus.success) return;
    await _reload(emit, withFeatured: true);
  }

  Future<void> _onTab(FeedTabSelected event, Emitter<FeedState> emit) async {
    if (event.tab == state.tab && state.status == FeedStatus.success) return;
    if (_isCategoryPage && event.tab == FeedTab.forYou) return;
    _analytics.log(AnalyticsEvents.feedTab, {
      'tab': event.tab.name,
      'surface': _isCategoryPage ? 'category' : 'home',
    });
    emit(state.copyWith(tab: event.tab));
    await _reload(emit);
  }

  Future<void> _onCategory(
    FeedCategorySelected event,
    Emitter<FeedState> emit,
  ) async {
    if (_isCategoryPage) return;
    if (event.categoryId == state.selectedCategoryId &&
        state.status == FeedStatus.success) {
      return;
    }
    _analytics.log(AnalyticsEvents.feedCategory, {
      'category': event.categoryId ?? 'all',
    });
    emit(state.copyWith(selectedCategoryId: () => event.categoryId));
    await _reload(emit);
  }

  Future<void> _onPreferences(
    FeedPreferencesChanged event,
    Emitter<FeedState> emit,
  ) async {
    if (event.preferences == state.preferences) return;
    emit(state.copyWith(preferences: event.preferences));
    await _reload(emit, withFeatured: true);
  }

  Future<void> _onRefresh(
    FeedRefreshRequested event,
    Emitter<FeedState> emit,
  ) async {
    _analytics.log(AnalyticsEvents.feedRefresh, {'tab': state.tab.name});
    emit(state.copyWith(isRefreshing: true));
    await _reload(emit, withFeatured: true, keepItems: true);
  }

  /// Loads the first page for the current tab, filter and preferences.
  Future<void> _reload(
    Emitter<FeedState> emit, {
    bool withFeatured = false,
    bool keepItems = false,
  }) async {
    final generation = ++_generation;
    if (!keepItems) {
      emit(
        state.copyWith(
          status: FeedStatus.loading,
          items: const [],
          hasMore: true,
          cursor: () => null,
          isLoadingMore: false,
          errorMessage: () => null,
          loadMoreError: () => null,
        ),
      );
    }
    final loadFeatured =
        withFeatured && !_isCategoryPage && state.preferences.showFeatured;
    try {
      final query = state.query;
      final results = await Future.wait<Object?>([
        _repository.fetchPage(query, limit: pageSize),
        _repository.savedIds(),
        if (loadFeatured)
          _repository.confessionOfTheDay(
            preferredCategoryIds: state.preferences.preferredCategoryIds
                .toSet(),
            includeMature: state.preferences.includeMature,
          ),
      ]);
      if (generation != _generation) return;
      final page = results[0]! as ConfessionPage;
      final items = page.items.where(state.isVisible).toList();
      final featured = loadFeatured ? results[2] as Confession? : null;
      final liked = await _likedFor([...items, if (featured != null) featured]);
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: FeedStatus.success,
          items: items,
          hasMore: page.hasMore,
          cursor: () => page.cursor,
          savedIds: results[1]! as Set<String>,
          likedIds: liked,
          featured: withFeatured ? () => featured : null,
          isRefreshing: false,
          isLoadingMore: false,
          errorMessage: () => null,
          loadMoreError: () => null,
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          isRefreshing: false,
          status: keepItems && state.items.isNotEmpty
              ? state.status
              : FeedStatus.failure,
          errorMessage: () => asAppException(e).message,
        ),
      );
    }
  }

  /// Liked state for cards. Failure here never blocks the feed.
  Future<Set<String>> _likedFor(List<Confession> items) async {
    if (items.isEmpty) return const {};
    try {
      return await _repository.likedIds(items.map((c) => c.id));
    } catch (_) {
      return const {};
    }
  }

  Future<void> _onLoadMore(
    FeedLoadMoreRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (state.status != FeedStatus.success ||
        !state.hasMore ||
        state.isLoadingMore ||
        state.isRefreshing) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true, loadMoreError: () => null));
    try {
      final page = await _repository.fetchPage(
        state.query,
        cursor: state.cursor,
        limit: pageSize,
      );
      if (generation != _generation) return;
      final known = state.items.map((c) => c.id).toSet();
      final fresh = page.items
          .where((c) => !known.contains(c.id) && state.isVisible(c))
          .toList();
      final liked = await _likedFor(fresh);
      if (generation != _generation) return;
      _analytics.log(AnalyticsEvents.feedLoadMore, {
        'tab': state.tab.name,
        'loaded': state.items.length + fresh.length,
      });
      emit(
        state.copyWith(
          items: [...state.items, ...fresh],
          likedIds: {...state.likedIds, ...liked},
          hasMore: page.hasMore,
          cursor: () => page.cursor,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          isLoadingMore: false,
          loadMoreError: () => asAppException(e).message,
        ),
      );
    }
  }

  Future<void> _onSaveToggled(
    FeedSaveToggled event,
    Emitter<FeedState> emit,
  ) async {
    final id = event.confessionId;
    final wasSaved = state.savedIds.contains(id);
    final optimistic = {...state.savedIds};
    wasSaved ? optimistic.remove(id) : optimistic.add(id);
    emit(state.copyWith(savedIds: optimistic));
    try {
      await _repository.setSaved(id, saved: !wasSaved);
      _analytics.log(
        wasSaved ? AnalyticsEvents.unsave : AnalyticsEvents.save,
        {'confession_id': id, 'surface': 'feed'},
      );
    } catch (_) {
      final reverted = {...state.savedIds};
      wasSaved ? reverted.add(id) : reverted.remove(id);
      emit(state.copyWith(savedIds: reverted));
    }
  }

  Future<void> _onLikeToggled(
    FeedLikeToggled event,
    Emitter<FeedState> emit,
  ) async {
    final id = event.confessionId;
    if (state.pendingLikes.contains(id)) return;
    final wasLiked = state.likedIds.contains(id);
    final liked = {...state.likedIds};
    wasLiked ? liked.remove(id) : liked.add(id);
    emit(
      state.copyWith(
        likedIds: liked,
        pendingLikes: {...state.pendingLikes, id},
        items: _adjustLikes(state.items, id, wasLiked ? -1 : 1),
        featured: _featuredAdjusted(id, wasLiked ? -1 : 1),
      ),
    );
    try {
      final updated = await _repository.setLiked(id, liked: !wasLiked);
      _analytics.log(
        wasLiked ? AnalyticsEvents.unlike : AnalyticsEvents.like,
        {
          'confession_id': id,
          'category': updated.categoryId,
          'surface': 'feed',
        },
      );
      emit(
        state.copyWith(
          pendingLikes: {...state.pendingLikes}..remove(id),
          items: _replace(state.items, updated),
          featured: state.featured?.id == id ? () => updated : null,
        ),
      );
    } catch (_) {
      final reverted = {...state.likedIds};
      wasLiked ? reverted.add(id) : reverted.remove(id);
      emit(
        state.copyWith(
          likedIds: reverted,
          pendingLikes: {...state.pendingLikes}..remove(id),
          items: _adjustLikes(state.items, id, wasLiked ? 1 : -1),
          featured: _featuredAdjusted(id, wasLiked ? 1 : -1),
        ),
      );
    }
  }

  static List<Confession> _adjustLikes(
    List<Confession> items,
    String id,
    int delta,
  ) => [
    for (final c in items)
      c.id == id
          ? c.copyWith(likeCount: math.max(0, c.likeCount + delta))
          : c,
  ];

  Confession? Function()? _featuredAdjusted(String id, int delta) {
    final f = state.featured;
    if (f == null || f.id != id) return null;
    return () => f.copyWith(likeCount: math.max(0, f.likeCount + delta));
  }

  static List<Confession> _replace(List<Confession> items, Confession c) => [
    for (final item in items) item.id == c.id ? c : item,
  ];

  void _onChange(_FeedChangeReceived event, Emitter<FeedState> emit) {
    switch (event.change) {
      case ConfessionCreated(:final confession):
        final q = state.query;
        final cats = q.categoryIds;
        if (!state.isVisible(confession) ||
            (cats != null && !cats.contains(confession.categoryId)) ||
            state.items.any((c) => c.id == confession.id)) {
          return;
        }
        emit(
          state.copyWith(
            status: FeedStatus.success,
            items: [confession, ...state.items],
          ),
        );
      case ConfessionUpdated(:final confession):
        // Our own optimistic like is reconciled in _onLikeToggled.
        if (state.pendingLikes.contains(confession.id)) return;
        final index = state.items.indexWhere((c) => c.id == confession.id);
        final isFeatured = state.featured?.id == confession.id;
        if (index < 0 && !isFeatured) return;
        emit(
          state.copyWith(
            items: index < 0
                ? null
                : (List<Confession>.of(state.items)..[index] = confession),
            featured: isFeatured ? () => confession : null,
          ),
        );
      case ConfessionDeleted(:final id):
        emit(
          state.copyWith(
            items: state.items.where((c) => c.id != id).toList(),
            featured: state.featured?.id == id ? () => null : null,
            savedIds: {...state.savedIds}..remove(id),
            likedIds: {...state.likedIds}..remove(id),
          ),
        );
      case ConfessionSavedChanged(:final confession, :final saved):
        final next = {...state.savedIds};
        saved ? next.add(confession.id) : next.remove(confession.id);
        if (next.length == state.savedIds.length &&
            next.containsAll(state.savedIds)) {
          return;
        }
        emit(state.copyWith(savedIds: next));
      case ConfessionLikedChanged(:final confession, :final liked):
        if (state.pendingLikes.contains(confession.id)) return;
        final next = {...state.likedIds};
        liked ? next.add(confession.id) : next.remove(confession.id);
        emit(state.copyWith(likedIds: next));
    }
  }

  @override
  Future<void> close() async {
    await _changesSub.cancel();
    return super.close();
  }
}
