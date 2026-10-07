import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/data/firebase/firebase_error_mapper.dart';
import '../../../core/data/firebase/firestore_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// Profiles in Cloud Firestore.
///
/// * `users/{uid}`: private username, age range, reading preferences and
///   app settings.
/// * `usernames/{usernameLower}`: `{ uid }`, a uniqueness claim so two
///   people can't pick the same anonymous handle.
///
/// No name, email, photo or birth date is stored.
class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    required fb.FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _db = firestore;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException('Please sign in to continue.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid);

  DocumentReference<Map<String, dynamic>> _claim(String username) =>
      _db.collection(FirestorePaths.usernames).doc(username.toLowerCase());

  @override
  Future<UserProfile?> fetchProfile() {
    return guardFirebase(() async {
      final uid = _requireUid();
      final snap = await _user(uid).get();
      final data = snap.data();
      if (data == null || data[UserFields.onboardingComplete] != true) {
        return null;
      }
      return _toProfile(uid, data);
    });
  }

  @override
  Future<bool> isUsernameAvailable(String username) {
    return guardFirebase(() async {
      final uid = _requireUid();
      final snap = await _claim(username).get();
      return !snap.exists || snap.data()?['uid'] == uid;
    });
  }

  @override
  Future<UserProfile> completeOnboarding(OnboardingChoices choices) {
    return guardFirebase(() async {
      final uid = _requireUid();
      final userRef = _user(uid);
      final claimRef = _claim(choices.username);
      await _db.runTransaction<void>((tx) async {
        final claim = await tx.get(claimRef);
        final owner = claim.data()?['uid'];
        if (claim.exists && owner != uid) {
          throw const UsernameTakenException();
        }
        tx.set(userRef, {
          UserFields.username: choices.username,
          UserFields.usernameLower: choices.username.toLowerCase(),
          UserFields.ageRange: choices.ageRange.name,
          UserFields.preferredCategoryIds: choices.preferredCategoryIds,
          UserFields.onboardingComplete: true,
          UserFields.createdAt: FieldValue.serverTimestamp(),
          UserFields.updatedAt: FieldValue.serverTimestamp(),
        });
        if (!claim.exists) {
          tx.set(claimRef, {
            'uid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
      return UserProfile(
        uid: uid,
        username: choices.username,
        ageRange: choices.ageRange,
        preferredCategoryIds: List.unmodifiable(choices.preferredCategoryIds),
        createdAt: DateTime.now(),
      );
    });
  }

  @override
  Future<UserProfile> updatePreferredCategories(List<String> categoryIds) {
    return guardFirebase(() async {
      final uid = _requireUid();
      await _user(uid).update({
        UserFields.preferredCategoryIds: categoryIds,
        UserFields.updatedAt: FieldValue.serverTimestamp(),
      });
      final snap = await _user(uid).get();
      return _toProfile(uid, snap.data() ?? const {});
    });
  }

  @override
  Future<void> updateSettings(AppSettings settings) {
    return guardFirebase(() async {
      final uid = _requireUid();
      await _user(uid).update({
        UserFields.settings: settings.toJson(),
        UserFields.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteProfile() {
    return guardFirebase(() async {
      final uid = _requireUid();
      final snap = await _user(uid).get();
      final username = snap.data()?[UserFields.username] as String?;
      final batch = _db.batch()..delete(_user(uid));
      if (username != null && username.isNotEmpty) {
        batch.delete(_claim(username));
      }
      await batch.commit();
    });
  }

  UserProfile _toProfile(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      username: (data[UserFields.username] as String?) ?? '',
      ageRange: AgeRange.parse(data[UserFields.ageRange]) ?? AgeRange.young,
      preferredCategoryIds:
          (data[UserFields.preferredCategoryIds] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      createdAt: (data[UserFields.createdAt] as Timestamp?)?.toDate(),
      settings: switch (data[UserFields.settings]) {
        final Map<dynamic, dynamic> raw => AppSettings.fromJson(
          Map<String, dynamic>.from(raw),
        ),
        _ => null,
      },
    );
  }
}
