import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../../auth/presentation/session_cubit.dart';
import '../../categories/domain/category.dart';
import '../../confessions/domain/confession.dart';
import '../../confessions/domain/confession_repository.dart';
import '../../confessions/presentation/confession_actions.dart';
import '../../confessions/presentation/confession_widgets.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_cubit.dart';

enum SearchStatus { idle, loading, done, failure }

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const [],
    this.errorMessage,
  });

  final String query;
  final SearchStatus status;
  final List<Confession> results;
  final String? errorMessage;

  @override
  List<Object?> get props => [query, status, results, errorMessage];
}

/// Keyword search over confessions, debounced so typing stays smooth.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    required ConfessionRepository repository,
    required this.includeMature,
    this.debounce = const Duration(milliseconds: 350),
    this.limit = 30,
    Analytics analytics = const NoopAnalytics(),
  }) : _repository = repository,
       _analytics = analytics,
       super(const SearchState());

  final ConfessionRepository _repository;
  final Analytics _analytics;
  final bool includeMature;
  final Duration debounce;
  final int limit;
  Timer? _timer;
  int _generation = 0;

  void queryChanged(String query) {
    _timer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      _generation++;
      emit(SearchState(query: query));
      return;
    }
    emit(SearchState(query: query, status: SearchStatus.loading, results: state.results));
    _timer = Timer(debounce, () => _run(query));
  }

  Future<void> _run(String query) async {
    final generation = ++_generation;
    try {
      final page = await _repository.fetchPage(
        FeedQuery(search: query, includeMature: includeMature),
        limit: limit,
      );
      if (isClosed || generation != _generation) return;
      // Only the shape of the search is logged, never the words.
      _analytics.log(AnalyticsEvents.search, {
        'words': query.trim().split(RegExp(r'\s+')).length,
        'results': page.items.length,
      });
      emit(
        SearchState(query: query, status: SearchStatus.done, results: page.items),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(
        SearchState(
          query: query,
          status: SearchStatus.failure,
          errorMessage: asAppException(e).message,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    final profile = context.read<SessionCubit>().state.profile;
    final settings = context.read<SettingsCubit>().state;
    return BlocProvider(
      create: (context) => SearchCubit(
        repository: context.read<ConfessionRepository>(),
        includeMature: (profile?.canSeeMature ?? false) && settings.showMature,
        analytics: context.read<Analytics>(),
      ),
      child: _SearchView(initialQuery: initialQuery),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({this.initialQuery});

  final String? initialQuery;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();

  static const _suggestions = [
    'secret', 'boss', 'exam', 'ex', 'mom', 'friend', 'cheated', 'quit',
  ];

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _use(q);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _use(String word) {
    _controller
      ..text = word
      ..selection = TextSelection.collapsed(offset: word.length);
    context.read<SearchCubit>().queryChanged(word);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<CategoryCatalog>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: TextField(
            key: const ValueKey('search-field'),
            controller: _controller,
            autofocus: widget.initialQuery == null,
            textInputAction: TextInputAction.search,
            onChanged: context.read<SearchCubit>().queryChanged,
            decoration: InputDecoration(
              hintText: 'Search confessions',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () => _use(''),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          if (state.query.trim().length < 2) {
            return ListView(
              padding: responsiveHorizontalPadding(
                context,
              ).copyWith(top: AppSpacing.md),
              children: [
                Text('Try searching for', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Search matches whole words in confessions.',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final s in _suggestions)
                      SelectableCategoryChip(
                        label: s,
                        icon: Icons.search,
                        selected: false,
                        onTap: () => _use(s),
                      ),
                  ],
                ),
              ],
            );
          }
          if (state.status == SearchStatus.loading && state.results.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (state.status == SearchStatus.failure) {
            return StatusMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Search failed',
              message: state.errorMessage,
            );
          }
          if (state.results.isEmpty) {
            return StatusMessage(
              icon: Icons.search_off,
              title: 'No confessions match "${state.query.trim()}"',
              message: 'Try a different word.',
            );
          }
          final settings = context.watch<SettingsCubit>().state;
          return ListView.separated(
            padding: responsiveHorizontalPadding(
              context,
              side: AppSpacing.sm,
            ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.xxl),
            itemCount: state.results.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  '${state.results.length} result'
                  '${state.results.length == 1 ? '' : 's'}',
                  style: context.text.bodySmall!.copyWith(
                    color: context.tokens.inkMuted,
                  ),
                );
              }
              final c = state.results[i - 1];
              return ConfessionCard(
                key: ValueKey('search-${c.id}'),
                confession: c,
                categories: categories,
                compact: settings.feedLayout == FeedLayout.compact,
                maxLines: 4,
                blurMature: settings.blurMature,
                onTap: () => openConfession(context, c, source: 'search'),
                onShare: () => shareConfession(context, c, source: 'search'),
              );
            },
          );
        },
      ),
    );
  }
}
