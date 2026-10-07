import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../domain/user_profile.dart';

enum ProfileStatus { loading, ready, failure }

enum ProfileSection {
  mine('Posts'),
  saved('Saved'),
  liked('Liked');

  const ProfileSection(this.label);
  final String label;
}

class ProfileState extends Equatable {
  const ProfileState({
    required this.profile,
    this.status = ProfileStatus.loading,
    this.section = ProfileSection.mine,
    this.myConfessions = const [],
    this.saved = const [],
    this.liked = const [],
    this.deletingIds = const {},
    this.errorMessage,
    this.notice,
  });

  final UserProfile profile;
  final ProfileStatus status;
  final ProfileSection section;
  final List<Confession> myConfessions;
  final List<Confession> saved;
  final List<Confession> liked;
  final Set<String> deletingIds;
  final String? errorMessage;
  final UiNotice? notice;

  List<Confession> get current => switch (section) {
    ProfileSection.mine => myConfessions,
    ProfileSection.saved => saved,
    ProfileSection.liked => liked,
  };

  ProfileState copyWith({
    UserProfile? profile,
    ProfileStatus? status,
    ProfileSection? section,
    List<Confession>? myConfessions,
    List<Confession>? saved,
    List<Confession>? liked,
    Set<String>? deletingIds,
    String? errorMessage,
    UiNotice? notice,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      status: status ?? this.status,
      section: section ?? this.section,
      myConfessions: myConfessions ?? this.myConfessions,
      saved: saved ?? this.saved,
      liked: liked ?? this.liked,
      deletingIds: deletingIds ?? this.deletingIds,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    profile,
    status,
    section,
    myConfessions,
    saved,
    liked,
    deletingIds,
    errorMessage,
    notice,
  ];
}

/// Your posts, saved and liked confessions, and your stats.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required UserProfile profile,
    required ConfessionRepository confessionRepository,
    Analytics analytics = const NoopAnalytics(),
  }) : _confessions = confessionRepository,
       _analytics = analytics,
       super(ProfileState(profile: profile)) {
    _changesSub = _confessions.changes.listen((_) => _scheduleReload());
  }

  final ConfessionRepository _confessions;
  final Analytics _analytics;
  late final StreamSubscription<ConfessionChange> _changesSub;
  Timer? _reloadTimer;

  Future<List<List<Confession>>> _fetchAll() => Future.wait([
    _confessions.fetchMine(),
    _confessions.fetchSaved(),
    _confessions.fetchLiked(),
  ]);

  Future<void> load() async {
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final results = await _fetchAll();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.ready,
          myConfessions: results[0],
          saved: results[1],
          liked: results[2],
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: asAppException(e).message,
        ),
      );
    }
  }

  /// Several changes often arrive together (a like updates the post and
  /// the liked list), so reloads are coalesced.
  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 400), _reloadLists);
  }

  Future<void> _reloadLists() async {
    if (isClosed || state.status != ProfileStatus.ready) return;
    try {
      final results = await _fetchAll();
      if (isClosed) return;
      emit(
        state.copyWith(
          myConfessions: results[0],
          saved: results[1],
          liked: results[2],
        ),
      );
    } catch (_) {
      // Keep the current lists; the next explicit load will retry.
    }
  }

  /// Keeps the header in sync after the profile changes elsewhere.
  void profileChanged(UserProfile profile) {
    if (profile != state.profile) emit(state.copyWith(profile: profile));
  }

  void selectSection(ProfileSection section) =>
      emit(state.copyWith(section: section));

  Future<void> deleteConfession(String id) async {
    if (state.deletingIds.contains(id)) return;
    emit(state.copyWith(deletingIds: {...state.deletingIds, id}));
    try {
      await _confessions.delete(id);
      _analytics.log(AnalyticsEvents.deletePost, {'confession_id': id});
      if (isClosed) return;
      emit(
        state.copyWith(
          myConfessions: state.myConfessions.where((c) => c.id != id).toList(),
          deletingIds: {...state.deletingIds}..remove(id),
          notice: UiNotice('Confession deleted.'),
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          deletingIds: {...state.deletingIds}..remove(id),
          notice: UiNotice(asAppException(e).message, isError: true),
        ),
      );
    }
  }

  Future<void> unsave(String id) async {
    try {
      await _confessions.setSaved(id, saved: false);
      _analytics.log(AnalyticsEvents.unsave, {
        'confession_id': id,
        'surface': 'profile',
      });
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          notice: UiNotice(asAppException(e).message, isError: true),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _reloadTimer?.cancel();
    await _changesSub.cancel();
    return super.close();
  }
}
