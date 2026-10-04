import 'dart:async';
import 'dart:ui' show Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';

enum DetailStatus { loading, ready, failure }

/// Lifecycle of the qualified-view timer for this screen.
enum ViewTrackingStatus {
  /// Not running (screen hidden, app backgrounded, or not loaded yet).
  idle,

  /// Reader is on screen; the dwell timer is running.
  pending,

  /// Threshold reached; the single write is in flight.
  recording,

  /// This visit produced a new counted view.
  counted,

  /// This reader was already counted for this confession — nothing to do.
  alreadyCounted,

  /// The write failed. We do not retry automatically (no write loops).
  failed,
}

class ConfessionDetailState extends Equatable {
  const ConfessionDetailState({
    required this.status,
    this.confession,
    this.isLiked = false,
    this.likeInFlight = false,
    this.reaction,
    this.isSaved = false,
    this.viewStatus = ViewTrackingStatus.idle,
    this.errorMessage,
    this.notice,
  });

  final DetailStatus status;
  final Confession? confession;
  final bool isLiked;
  final bool likeInFlight;

  /// This reader's reaction, if any.
  final Reaction? reaction;
  final bool isSaved;
  final ViewTrackingStatus viewStatus;
  final String? errorMessage;
  final UiNotice? notice;

  /// Whether this reader's view is settled and no timer should run again.
  bool get viewSettled =>
      viewStatus == ViewTrackingStatus.counted ||
      viewStatus == ViewTrackingStatus.alreadyCounted ||
      viewStatus == ViewTrackingStatus.recording ||
      viewStatus == ViewTrackingStatus.failed;

  ConfessionDetailState copyWith({
    DetailStatus? status,
    Confession? confession,
    bool? isLiked,
    bool? likeInFlight,
    Reaction? Function()? reaction,
    bool? isSaved,
    ViewTrackingStatus? viewStatus,
    String? errorMessage,
    UiNotice? notice,
  }) {
    return ConfessionDetailState(
      status: status ?? this.status,
      confession: confession ?? this.confession,
      isLiked: isLiked ?? this.isLiked,
      likeInFlight: likeInFlight ?? this.likeInFlight,
      reaction: reaction != null ? reaction() : this.reaction,
      isSaved: isSaved ?? this.isSaved,
      viewStatus: viewStatus ?? this.viewStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    status,
    confession,
    isLiked,
    likeInFlight,
    reaction,
    isSaved,
    viewStatus,
    errorMessage,
    notice,
  ];
}

/// Reading screen logic: load, like/unlike, share, and the 15-second
/// qualified-view policy.
///
/// **View policy**: a view is counted when a signed-in reader keeps the
/// confession on screen, with the app in the foreground, for
/// [viewThreshold] *continuously*. Leaving the screen or backgrounding the
/// app cancels the pending timer (it restarts from zero on return). At most
/// one view is ever counted per reader per confession — enforced here and
/// by the repository (`hasViewed` / `recordView`). Exactly one write is made
/// per qualifying visit; there are no periodic timer writes.
class ConfessionDetailCubit extends Cubit<ConfessionDetailState> {
  ConfessionDetailCubit({
    required ConfessionRepository repository,
    required ShareService shareService,
    required this.confessionId,
    Confession? initial,
    this.viewThreshold = const Duration(seconds: 15),
  }) : _repository = repository,
       _share = shareService,
       super(
         ConfessionDetailState(
           status: initial == null ? DetailStatus.loading : DetailStatus.ready,
           confession: initial,
         ),
       );

  final ConfessionRepository _repository;
  final ShareService _share;
  final String confessionId;
  final Duration viewThreshold;

  Timer? _viewTimer;
  bool _visible = false;
  bool _loaded = false;

  /// Exposed for tests.
  bool get isViewTimerActive => _viewTimer?.isActive ?? false;

  Future<void> load() async {
    if (state.confession == null) {
      emit(state.copyWith(status: DetailStatus.loading));
    }
    try {
      final results = await Future.wait<Object?>([
        _repository.fetchById(confessionId),
        _repository.isLiked(confessionId),
        _repository.hasViewed(confessionId),
        _repository.myReaction(confessionId),
        _repository.isSaved(confessionId),
      ]);
      if (isClosed) return;
      final confession = results[0]! as Confession;
      final liked = results[1]! as bool;
      final viewed = results[2]! as bool;
      final reaction = results[3] as Reaction?;
      final saved = results[4]! as bool;
      _loaded = true;
      emit(
        state.copyWith(
          status: DetailStatus.ready,
          confession: confession,
          isLiked: liked,
          reaction: () => reaction,
          isSaved: saved,
          viewStatus: viewed ? ViewTrackingStatus.alreadyCounted : null,
        ),
      );
      _syncViewTimer();
    } catch (e) {
      if (isClosed) return;
      final message = asAppException(e).message;
      if (state.confession == null || e is NotFoundException) {
        emit(
          ConfessionDetailState(
            status: DetailStatus.failure,
            errorMessage: message,
          ),
        );
      } else {
        // We can still show the cached card; just report the refresh error.
        emit(state.copyWith(notice: UiNotice(message, isError: true)));
      }
    }
  }

  // ------------------------------------------------------ view tracking ---

  /// Call when the reading screen becomes visible / the app resumes.
  void onVisible() {
    _visible = true;
    _syncViewTimer();
  }

  /// Call when the screen is covered, popped, or the app is backgrounded.
  void onHidden() {
    _visible = false;
    _syncViewTimer();
  }

  void _syncViewTimer() {
    if (isClosed) return;
    final shouldRun = _visible && _loaded && !state.viewSettled;
    if (shouldRun) {
      if (_viewTimer?.isActive ?? false) return;
      _viewTimer = Timer(viewThreshold, _onThresholdReached);
      if (state.viewStatus != ViewTrackingStatus.pending) {
        emit(state.copyWith(viewStatus: ViewTrackingStatus.pending));
      }
    } else {
      _cancelViewTimer();
      if (state.viewStatus == ViewTrackingStatus.pending) {
        emit(state.copyWith(viewStatus: ViewTrackingStatus.idle));
      }
    }
  }

  void _cancelViewTimer() {
    _viewTimer?.cancel();
    _viewTimer = null;
  }

  Future<void> _onThresholdReached() async {
    _viewTimer = null;
    if (isClosed || !_visible || state.viewSettled) return;
    emit(state.copyWith(viewStatus: ViewTrackingStatus.recording));
    try {
      final counted = await _repository.recordView(confessionId);
      if (isClosed) return;
      final current = state.confession;
      emit(
        state.copyWith(
          viewStatus: counted
              ? ViewTrackingStatus.counted
              : ViewTrackingStatus.alreadyCounted,
          confession: counted && current != null
              ? current.copyWith(viewCount: current.viewCount + 1)
              : null,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      // Silent for the reader; no automatic retry to avoid write loops.
      emit(state.copyWith(viewStatus: ViewTrackingStatus.failed));
    }
  }

  // --------------------------------------------------------------- likes ---

  Future<void> toggleLike() async {
    final current = state.confession;
    if (current == null || state.likeInFlight) return;
    final wantLiked = !state.isLiked;
    final delta = current.likeCount + (wantLiked ? 1 : -1);
    final optimisticCount = delta < 0 ? 0 : delta;
    emit(
      state.copyWith(
        isLiked: wantLiked,
        likeInFlight: true,
        confession: current.copyWith(likeCount: optimisticCount),
      ),
    );
    try {
      final updated = await _repository.setLiked(
        confessionId,
        liked: wantLiked,
      );
      if (isClosed) return;
      emit(state.copyWith(confession: updated, likeInFlight: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLiked: !wantLiked,
          likeInFlight: false,
          confession: current,
          notice: UiNotice(asAppException(e).message, isError: true),
        ),
      );
    }
  }

  // ----------------------------------------------------- reactions & saves ---

  bool _reactionInFlight = false;

  /// Tapping your current reaction removes it; another one replaces it.
  Future<void> react(Reaction reaction) async {
    final current = state.confession;
    if (current == null || _reactionInFlight) return;
    _reactionInFlight = true;
    final previous = state.reaction;
    final next = previous == reaction ? null : reaction;
    try {
      final updated = await _repository.setReaction(confessionId, next);
      if (isClosed) return;
      emit(state.copyWith(confession: updated, reaction: () => next));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          notice: UiNotice(asAppException(e).message, isError: true),
        ),
      );
    } finally {
      _reactionInFlight = false;
    }
  }

  Future<void> toggleSaved() async {
    final wasSaved = state.isSaved;
    emit(state.copyWith(isSaved: !wasSaved));
    try {
      await _repository.setSaved(confessionId, saved: !wasSaved);
      if (!isClosed) {
        emit(
          state.copyWith(
            notice: UiNotice(wasSaved ? 'Removed from saved.' : 'Saved.'),
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSaved: wasSaved,
          notice: UiNotice(asAppException(e).message, isError: true),
        ),
      );
    }
  }

  // --------------------------------------------------------------- share ---

  Future<void> share({Rect? origin}) async {
    final current = state.confession;
    if (current == null) return;
    try {
      await _share.shareText(
        buildShareText(current.text),
        subject: 'A confession from ${AppConfig.appName}',
        origin: origin,
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            notice: UiNotice("Couldn't open the share sheet.", isError: true),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _visible = false;
    _cancelViewTimer();
    return super.close();
  }
}
