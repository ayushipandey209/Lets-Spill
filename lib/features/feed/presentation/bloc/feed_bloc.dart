import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';

/// Home tabs.
enum FeedTab {
  forYou('For you'),
  trending('Trending'),
  latest('Latest');

  const FeedTab(this.label);
  final String label;
}

/// What the reader chose during onboarding / in their profile.
class FeedPreferences extends Equatable {
  const FeedPreferences({
    this.preferredCategoryIds = const [],
    this.includeMature = true,
  });

  final List<String> preferredCategoryIds;
  final bool includeMature;

  @override
  List<Object?> get props => [preferredCategoryIds, includeMature];
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
    this.preferences = const FeedPreferences(),
    this.items = const [],
    this.hasMore = true,
    this.cursor,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.featured,
    this.savedIds = const {},
    this.errorMessage,
    this.loadMoreError,
  });

  final FeedStatus status;
  final FeedTab tab;
  final String? selectedCategoryId;
  final FeedPreferences preferences;
  final List<Confession> items;
  final bool hasMore;
  final Object? cursor;
  final bool isLoadingMore;
  final bool isRefreshing;

  /// Confession of the Day.
  final Confession? featured;
  final Set<String> savedIds;
  final String? errorMessage;
  final String? loadMoreError;

  FeedQuery get query {
    final selected = selectedCategoryId;
    Set<String>? categories;
    if (selected != null) {
      categories = {selected};
    } else if (tab == FeedTab.forYou &&
        preferences.preferredCategoryIds.isNotEmpty) {
      categories = preferences.preferredCategoryIds.toSet();
    }
    return FeedQuery(
      sort: tab == FeedTab.trending ? FeedSort.trending : FeedSort.latest,
      categoryIds: categories,
      includeMature: preferences.includeMature,
    );
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
    String? Function()? errorMessage,
    String? Function()? loadMoreError,
  }) {
    return FeedState(
      status: status ?? this.status,
      tab: tab ?? this.tab,
      selectedCategoryId: selectedCategoryId != null
          ? selectedCategoryId()
          : this.selectedCategoryId,
      preferences: preferences ?? this.preferences,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor != null ? cursor() : this.cursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      featured: featured != null ? featured() : this.featured,
      savedIds: savedIds ?? this.savedIds,
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
    preferences,
    items,
    hasMore,
    cursor,
    isLoadingMore,
    isRefreshing,
    featured,
    savedIds,
    errorMessage,
    loadMoreError,
  ];
}

// ------------------------------------------------------------------- bloc ---

/// Home feed: Confession of the Day, For you / Trending / Latest tabs,
/// category filters, pagination and saves.
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({
    required ConfessionRepository repository,
    required this.pageSize,
    FeedPreferences preferences = const FeedPreferences(),
  }) : _repository = repository,
       super(FeedState(preferences: preferences)) {
    on<FeedStarted>(_onStarted, transformer: restartable());
    on<FeedTabSelected>(_onTab, transformer: restartable());
    on<FeedCategorySelected>(_onCategory, transformer: restartable());
    on<FeedPreferencesChanged>(_onPreferences, transformer: restartable());
    on<FeedRefreshRequested>(_onRefresh, transformer: restartable());
    on<FeedLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<FeedSaveToggled>(_onSaveToggled);
    on<_FeedChangeReceived>(_onChange);
    _changesSub = _repository.changes.listen(
      (c) => add(_FeedChangeReceived(c)),
    );
  }

  final ConfessionRepository _repository;
  final int pageSize;
  late final StreamSubscription<ConfessionChange> _changesSub;
  int _generation = 0;

  Future<void> _onStarted(FeedStarted event, Emitter<FeedState> emit) async {
    if (state.status == FeedStatus.success) return;
    await _reload(emit, withFeatured: true);
  }

  Future<void> _onTab(FeedTabSelected event, Emitter<FeedState> emit) async {
    if (event.tab == state.tab && state.status == FeedStatus.success) return;
    emit(state.copyWith(tab: event.tab));
    await _reload(emit);
  }

  Future<void> _onCategory(
    FeedCategorySelected event,
    Emitter<FeedState> emit,
  ) async {
    if (event.categoryId == state.selectedCategoryId &&
        state.status == FeedStatus.success) {
      return;
    }
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
    emit(state.copyWith(isRefreshing: true));
    await _reload(emit, withFeatured: true, keepItems: true);
  }

  /// Loads the first page for the current tab/filter/preferences.
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
    try {
      final query = state.query;
      final results = await Future.wait<Object?>([
        _repository.fetchPage(query, limit: pageSize),
        _repository.savedIds(),
        if (withFeatured)
          _repository.confessionOfTheDay(
            preferredCategoryIds: state.preferences.preferredCategoryIds.toSet(),
            includeMature: state.preferences.includeMature,
          ),
      ]);
      if (generation != _generation) return;
      final page = results[0]! as ConfessionPage;
      emit(
        state.copyWith(
          status: FeedStatus.success,
          items: page.items,
          hasMore: page.hasMore,
          cursor: () => page.cursor,
          savedIds: results[1]! as Set<String>,
          featured: withFeatured
              ? () => results[2] as Confession?
              : null,
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
      emit(
        state.copyWith(
          items: [
            ...state.items,
            ...page.items.where((c) => !known.contains(c.id)),
          ],
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
    } catch (_) {
      final reverted = {...state.savedIds};
      wasSaved ? reverted.add(id) : reverted.remove(id);
      emit(state.copyWith(savedIds: reverted));
    }
  }

  bool _matches(Confession c) {
    final q = state.query;
    if (!q.includeMature && c.mature) return false;
    final cats = q.categoryIds;
    return cats == null || cats.contains(c.categoryId);
  }

  void _onChange(_FeedChangeReceived event, Emitter<FeedState> emit) {
    switch (event.change) {
      case ConfessionCreated(:final confession):
        if (!_matches(confession) ||
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
    }
  }

  @override
  Future<void> close() async {
    await _changesSub.cancel();
    return super.close();
  }
}
