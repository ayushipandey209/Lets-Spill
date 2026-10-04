import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../../core/utils/validators.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../domain/profile_repository.dart';
import '../../domain/user_profile.dart';

enum ProfileStatus { loading, ready, failure }

enum ProfileSection { mine, saved }

class ProfileState extends Equatable {
  const ProfileState({
    required this.profile,
    this.status = ProfileStatus.loading,
    this.section = ProfileSection.mine,
    this.myConfessions = const [],
    this.saved = const [],
    this.draftCategoryIds = const [],
    this.prefsStatus = SubmitStatus.idle,
    this.deletingIds = const {},
    this.errorMessage,
    this.notice,
  });

  final UserProfile profile;
  final ProfileStatus status;
  final ProfileSection section;
  final List<Confession> myConfessions;
  final List<Confession> saved;
  final List<String> draftCategoryIds;
  final SubmitStatus prefsStatus;
  final Set<String> deletingIds;
  final String? errorMessage;
  final UiNotice? notice;

  bool get hasUnsavedPreferences {
    final current = profile.preferredCategoryIds;
    return current.length != draftCategoryIds.length ||
        !current.toSet().containsAll(draftCategoryIds);
  }

  ProfileState copyWith({
    UserProfile? profile,
    ProfileStatus? status,
    ProfileSection? section,
    List<Confession>? myConfessions,
    List<Confession>? saved,
    List<String>? draftCategoryIds,
    SubmitStatus? prefsStatus,
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
      draftCategoryIds: draftCategoryIds ?? this.draftCategoryIds,
      prefsStatus: prefsStatus ?? this.prefsStatus,
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
    draftCategoryIds,
    prefsStatus,
    deletingIds,
    errorMessage,
    notice,
  ];
}

/// Private profile: preferences, your posts and saved confessions.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required UserProfile profile,
    required ProfileRepository profileRepository,
    required ConfessionRepository confessionRepository,
    this.onProfileUpdated,
  }) : _profiles = profileRepository,
       _confessions = confessionRepository,
       super(
         ProfileState(
           profile: profile,
           draftCategoryIds: profile.preferredCategoryIds,
         ),
       ) {
    _changesSub = _confessions.changes.listen((_) => _reloadLists());
  }

  final ProfileRepository _profiles;
  final ConfessionRepository _confessions;
  final void Function(UserProfile profile)? onProfileUpdated;
  late final StreamSubscription<ConfessionChange> _changesSub;

  Future<void> load() async {
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final results = await Future.wait([
        _confessions.fetchMine(),
        _confessions.fetchSaved(),
      ]);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.ready,
          myConfessions: results[0],
          saved: results[1],
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

  Future<void> _reloadLists() async {
    if (isClosed || state.status != ProfileStatus.ready) return;
    try {
      final results = await Future.wait([
        _confessions.fetchMine(),
        _confessions.fetchSaved(),
      ]);
      if (isClosed) return;
      emit(state.copyWith(myConfessions: results[0], saved: results[1]));
    } catch (_) {
      // Keep the current lists; the next explicit load will retry.
    }
  }

  void selectSection(ProfileSection section) =>
      emit(state.copyWith(section: section));

  void toggleCategory(String id) {
    final next = List<String>.of(state.draftCategoryIds);
    if (!next.remove(id)) next.add(id);
    emit(
      state.copyWith(
        draftCategoryIds: List.unmodifiable(next),
        prefsStatus: SubmitStatus.idle,
      ),
    );
  }

  Future<void> savePreferences() async {
    if (state.prefsStatus == SubmitStatus.submitting) return;
    final error = Validators.categories(state.draftCategoryIds);
    if (error != null) {
      emit(state.copyWith(notice: UiNotice(error, isError: true)));
      return;
    }
    emit(state.copyWith(prefsStatus: SubmitStatus.submitting));
    try {
      final profile = await _profiles.updatePreferredCategories(
        state.draftCategoryIds,
      );
      if (isClosed) return;
      onProfileUpdated?.call(profile);
      emit(
        state.copyWith(
          profile: profile,
          draftCategoryIds: profile.preferredCategoryIds,
          prefsStatus: SubmitStatus.success,
          notice: UiNotice('Preferences saved. Your feed is updated.'),
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          prefsStatus: SubmitStatus.failure,
          notice: UiNotice(asAppException(e).message, isError: true),
        ),
      );
    }
  }

  Future<void> deleteConfession(String id) async {
    if (state.deletingIds.contains(id)) return;
    emit(state.copyWith(deletingIds: {...state.deletingIds, id}));
    try {
      await _confessions.delete(id);
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
    await _changesSub.cancel();
    return super.close();
  }
}
