import 'dart:convert';

import '../../../features/confessions/domain/confession.dart';
import '../../errors/app_exception.dart';
import '../asset_loader.dart';
import '../key_value_store.dart';

/// Per-user activity kept on the device. Keyed by Firebase uid, so several
/// accounts on one device never see each other's likes or saves.
class UserActivity {
  UserActivity({
    Set<String>? likes,
    Set<String>? views,
    Map<String, Reaction>? reactions,
    Set<String>? saved,
    Set<String>? owned,
  }) : likes = likes ?? <String>{},
       views = views ?? <String>{},
       reactions = reactions ?? <String, Reaction>{},
       saved = saved ?? <String>{},
       owned = owned ?? <String>{};

  factory UserActivity.fromJson(Map<String, dynamic> json) {
    Set<String> set(String key) =>
        (json[key] as List<dynamic>? ?? const []).cast<String>().toSet();
    final reactions = <String, Reaction>{};
    final raw = json['reactions'];
    if (raw is Map<String, dynamic>) {
      raw.forEach((id, value) {
        final r = Reaction.parse(value);
        if (r != null) reactions[id] = r;
      });
    }
    return UserActivity(
      likes: set('likes'),
      views: set('views'),
      reactions: reactions,
      saved: set('saved'),
      owned: set('owned'),
    );
  }

  final Set<String> likes;
  final Set<String> views;
  final Map<String, Reaction> reactions;

  /// Insertion-ordered: newest saves are appended.
  final Set<String> saved;
  final Set<String> owned;

  Map<String, dynamic> toJson() => {
    'likes': likes.toList(),
    'views': views.toList(),
    'reactions': reactions.map((k, v) => MapEntry(k, v.name)),
    'saved': saved.toList(),
    'owned': owned.toList(),
  };
}

/// In-memory content database seeded from `assets/mock/confessions.json` and
/// persisted to device storage after every change.
///
/// Delete the [storageKey] entry (or call [reset]) to return to the seed.
class LocalContentStore {
  LocalContentStore({
    required AssetLoader loader,
    required KeyValueStore store,
    required String? Function() currentUid,
    Duration latency = Duration.zero,
    DateTime Function()? clock,
  }) : _loader = loader,
       _store = store,
       _currentUid = currentUid,
       _latency = latency,
       _clock = clock ?? DateTime.now;

  static const storageKey = 'lets_spill.content.v2';
  static const confessionsAsset = 'assets/mock/confessions.json';

  final AssetLoader _loader;
  final KeyValueStore _store;
  final String? Function() _currentUid;
  final Duration _latency;
  final DateTime Function() _clock;

  final List<Confession> confessions = [];
  final Map<String, UserActivity> activity = {};

  bool _initialized = false;
  int _idCounter = 0;

  DateTime now() => _clock();

  Future<void> simulateLatency() async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
  }

  Future<void> init() async {
    if (_initialized) return;
    String? persisted;
    try {
      persisted = await _store.read(storageKey);
    } catch (_) {
      persisted = null;
    }
    if (persisted != null) {
      try {
        _restore(jsonDecode(persisted) as Map<String, dynamic>);
        _initialized = true;
        return;
      } catch (_) {
        confessions.clear();
        activity.clear();
      }
    }
    await _seed();
    _initialized = true;
    await persist();
  }

  /// Restores the bundled seed and forgets all on-device activity.
  Future<void> reset() async {
    confessions.clear();
    activity.clear();
    await _store.delete(storageKey);
    await _seed();
    _initialized = true;
    await persist();
  }

  Future<void> persist() async {
    try {
      await _store.write(
        storageKey,
        jsonEncode({
          'version': 2,
          'confessions': confessions.map((c) => c.toJson()).toList(),
          'activity': activity.map((k, v) => MapEntry(k, v.toJson())),
        }),
      );
    } catch (_) {
      // Best-effort; the in-memory state keeps working.
    }
  }

  String newId(String prefix) {
    _idCounter++;
    return '$prefix-${now().microsecondsSinceEpoch}-$_idCounter';
  }

  /// Activity for the signed-in user. Throws if nobody is signed in.
  UserActivity requireActivity() {
    final uid = _currentUid();
    if (uid == null) throw const AuthException('Please sign in to continue.');
    return activity.putIfAbsent(uid, UserActivity.new);
  }

  String? get currentUid => _currentUid();

  Confession? find(String id) {
    for (final c in confessions) {
      if (c.id == id) return c;
    }
    return null;
  }

  void replace(Confession updated) {
    final i = confessions.indexWhere((c) => c.id == updated.id);
    if (i >= 0) confessions[i] = updated;
  }

  void sortByNewest() {
    confessions.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  }

  Future<void> _seed() async {
    final json =
        jsonDecode(await _loader(confessionsAsset)) as Map<String, dynamic>;
    confessions.addAll(
      (json['confessions'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Confession.fromJson),
    );
    sortByNewest();
  }

  void _restore(Map<String, dynamic> json) {
    confessions.addAll(
      (json['confessions'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Confession.fromJson),
    );
    sortByNewest();
    final raw = json['activity'];
    if (raw is Map<String, dynamic>) {
      raw.forEach((uid, value) {
        activity[uid] = UserActivity.fromJson(value as Map<String, dynamic>);
      });
    }
  }
}
