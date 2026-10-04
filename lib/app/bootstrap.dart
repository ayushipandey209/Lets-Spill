import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';

import '../core/config/app_config.dart';
import '../core/data/asset_loader.dart';
import '../core/data/key_value_store.dart';
import '../core/data/local/local_content_store.dart';
import '../core/errors/app_exception.dart';
import '../core/services/share_service.dart';
import '../features/auth/data/firebase_auth_repository.dart';
import '../features/categories/data/asset_category_repository.dart';
import '../features/confessions/data/local_confession_repository.dart';
import '../features/profile/data/firebase_profile_repository.dart';
import '../features/reports/data/firebase_report_repository.dart';
import '../firebase_options.dart';
import 'app_services.dart';

/// Wires the app:
///
/// * Firebase Authentication (Google) + Firestore for accounts and profiles.
/// * Bundled JSON (+ on-device activity) for confession content.
///
/// If `flutterfire configure` hasn't been run, start-up fails with a
/// [ConfigurationException] that carries the exact setup steps.
class Bootstrapper {
  const Bootstrapper({
    this.assetLoader = rootBundleLoader,
    this.storeFactory,
    this.shareService = const SharePlusShareService(),
  });

  final AssetLoader assetLoader;
  final Future<KeyValueStore> Function()? storeFactory;
  final ShareService shareService;

  Future<AppServices> create(AppConfig config) async {
    await _initializeFirebase();
    final auth = fb.FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final categories = await AssetCategoryRepository(
      loader: assetLoader,
    ).loadCategories();

    final content = LocalContentStore(
      loader: assetLoader,
      store: await _openStore(),
      currentUid: () => auth.currentUser?.uid,
      latency: config.contentLatency,
    );
    await content.init();

    return AppServices(
      config: config,
      auth: FirebaseAuthRepository(auth: auth),
      profiles: FirebaseProfileRepository(auth: auth, firestore: firestore),
      confessions: LocalConfessionRepository(
        content,
        maxLength: config.maxConfessionLength,
        minLength: config.minConfessionLength,
      ),
      reports: FirebaseReportRepository(auth: auth, firestore: firestore),
      categories: categories,
      share: shareService,
    );
  }

  Future<KeyValueStore> _openStore() async {
    try {
      final factory = storeFactory;
      if (factory != null) return await factory();
      return await SharedPreferencesStore.create();
    } catch (_) {
      return InMemoryKeyValueStore();
    }
  }

  static const _setupSteps = [
    'Install the CLIs: `npm i -g firebase-tools` and '
        '`dart pub global activate flutterfire_cli`.',
    'Run `firebase login`, then `flutterfire configure` in the project root.',
    'Firebase Console → Authentication → Sign-in method → enable Google.',
    'Android: add your SHA-1 and SHA-256 fingerprints in Project settings, '
        'then re-run `flutterfire configure`.',
    'Create a Cloud Firestore database and run '
        '`firebase deploy --only firestore`.',
  ];

  Future<void> _initializeFirebase() async {
    final FirebaseOptions options;
    try {
      options = DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      throw const ConfigurationException(
        "Let's Spill uses Google sign-in through Firebase, but this build "
        "isn't connected to a Firebase project yet.",
        setupSteps: _setupSteps,
      );
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
    } on FirebaseException catch (e) {
      throw ConfigurationException(
        'Firebase could not start (${e.code}). Check your Firebase '
        'configuration and try again.',
        setupSteps: _setupSteps,
      );
    }
  }
}
