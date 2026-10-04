import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:let_s_spill/app/app_services.dart';
import 'package:let_s_spill/core/config/app_config.dart';
import 'package:let_s_spill/core/data/key_value_store.dart';
import 'package:let_s_spill/core/data/local/local_content_store.dart';
import 'package:let_s_spill/core/errors/app_exception.dart';
import 'package:let_s_spill/core/services/share_service.dart';
import 'package:let_s_spill/features/auth/domain/app_user.dart';
import 'package:let_s_spill/features/auth/domain/auth_repository.dart';
import 'package:let_s_spill/features/categories/data/asset_category_repository.dart';
import 'package:let_s_spill/features/confessions/data/local_confession_repository.dart';
import 'package:let_s_spill/features/profile/domain/profile_repository.dart';
import 'package:let_s_spill/features/profile/domain/user_profile.dart';
import 'package:let_s_spill/features/reports/domain/report.dart';
import 'package:let_s_spill/features/reports/domain/report_repository.dart';

/// Reads bundled assets synchronously from disk (tests run from the package
/// root), so loading works inside fake-async zones without real I/O.
final Map<String, String> _assetCache = {};

Future<String> fixtureLoader(String path) {
  final content = _assetCache.putIfAbsent(
    path,
    () => File(path).readAsStringSync(),
  );
  return Future.value(content);
}

const testConfig = AppConfig(contentLatency: Duration.zero);

/// Number of confessions in assets/mock/confessions.json.
const seedConfessionCount = 28;

/// Of which marked `mature: true`.
const seedMatureCount = 3;

const testUser = AppUser(
  uid: 'uid-alice',
  displayName: 'Alice Example',
  email: 'alice@example.com',
);

/// In-memory stand-in for Google + Firebase Auth.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedIn}) : _user = signedIn;

  AppUser? _user;
  // ignore: close_sinks
  final _controller = StreamController<AppUser?>.broadcast();
  bool cancelNextSignIn = false;
  int reauthCount = 0;
  bool deleted = false;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (cancelNextSignIn) {
      cancelNextSignIn = false;
      throw const SignInCancelledException();
    }
    _user = testUser;
    _controller.add(_user);
    return testUser;
  }

  @override
  Future<void> reauthenticate() async {
    reauthCount++;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    await signOut();
  }
}

/// In-memory Firestore profile + username claims.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.auth, {this.takenUsernames = const {}});

  final AuthRepository auth;
  final Set<String> takenUsernames;
  final Map<String, UserProfile> profiles = {};
  final Map<String, String> claims = {};

  String get _uid {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw const AuthException('Please sign in.');
    return uid;
  }

  @override
  Future<UserProfile?> fetchProfile() async => profiles[_uid];

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final lower = username.toLowerCase();
    if (takenUsernames.map((e) => e.toLowerCase()).contains(lower)) {
      return false;
    }
    final owner = claims[lower];
    return owner == null || owner == _uid;
  }

  @override
  Future<UserProfile> completeOnboarding(OnboardingChoices choices) async {
    if (!await isUsernameAvailable(choices.username)) {
      throw const UsernameTakenException();
    }
    claims[choices.username.toLowerCase()] = _uid;
    final profile = UserProfile(
      uid: _uid,
      username: choices.username,
      ageRange: choices.ageRange,
      preferredCategoryIds: List.unmodifiable(choices.preferredCategoryIds),
    );
    profiles[_uid] = profile;
    return profile;
  }

  @override
  Future<UserProfile> updatePreferredCategories(List<String> ids) async {
    final updated = profiles[_uid]!.copyWith(
      preferredCategoryIds: List.unmodifiable(ids),
    );
    profiles[_uid] = updated;
    return updated;
  }

  @override
  Future<void> deleteProfile() async {
    final p = profiles.remove(_uid);
    if (p != null) claims.remove(p.username.toLowerCase());
  }
}

class FakeReportRepository implements ReportRepository {
  final List<String> reported = [];

  @override
  Future<bool> hasReported(String confessionId) async =>
      reported.contains(confessionId);

  @override
  Future<void> submit({
    required String confessionId,
    required ReportReason reason,
    String details = '',
  }) async {
    if (reported.contains(confessionId)) {
      throw const ValidationException('Already reported.');
    }
    reported.add(confessionId);
  }
}

class FakeShareService implements ShareService {
  final List<String> shared = [];

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    shared.add(text);
  }
}

UserProfile adultProfile({List<String> categories = const ['life']}) =>
    UserProfile(
      uid: testUser.uid,
      username: 'QuietComet27',
      ageRange: AgeRange.adult,
      preferredCategoryIds: categories,
    );

UserProfile teenProfile() => UserProfile(
  uid: testUser.uid,
  username: 'ShyFox12',
  ageRange: AgeRange.teen,
  preferredCategoryIds: const ['relationships'],
);

Future<LocalContentStore> createStore({
  String? Function()? uid,
  KeyValueStore? store,
  DateTime Function()? clock,
}) async {
  final s = LocalContentStore(
    loader: fixtureLoader,
    store: store ?? InMemoryKeyValueStore(),
    currentUid: uid ?? () => testUser.uid,
    clock: clock ?? () => DateTime.utc(2026, 10, 4, 12),
  );
  await s.init();
  return s;
}

LocalConfessionRepository confessionRepo(LocalContentStore store) =>
    LocalConfessionRepository(
      store,
      maxLength: testConfig.maxConfessionLength,
      minLength: testConfig.minConfessionLength,
    );

/// Wired test services. [profile] pre-completes onboarding for the user.
class TestHarness {
  TestHarness({this.signedIn = false, this.profile});

  final bool signedIn;
  final UserProfile? profile;

  late final FakeAuthRepository auth = FakeAuthRepository(
    signedIn: signedIn ? testUser : null,
  );
  late final FakeProfileRepository profiles = FakeProfileRepository(auth);
  final share = FakeShareService();
  final reports = FakeReportRepository();

  Future<AppServices> create(AppConfig config) async {
    final p = profile;
    if (p != null) {
      profiles.profiles[p.uid] = p;
      profiles.claims[p.username.toLowerCase()] = p.uid;
    }
    final store = await createStore(uid: () => auth.currentUser?.uid);
    final categories = await AssetCategoryRepository(
      loader: fixtureLoader,
    ).loadCategories();
    return AppServices(
      config: config,
      auth: auth,
      profiles: profiles,
      confessions: confessionRepo(store),
      reports: reports,
      categories: categories,
      share: share,
    );
  }
}
