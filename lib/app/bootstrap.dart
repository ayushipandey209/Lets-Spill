import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';

import '../core/analytics/analytics.dart';
import '../core/analytics/firebase_analytics_service.dart';
import '../core/config/app_config.dart';
import '../core/data/asset_loader.dart';
import '../core/errors/app_exception.dart';
import '../core/services/share_service.dart';
import '../features/auth/data/firebase_auth_repository.dart';
import '../features/categories/data/asset_category_repository.dart';
import '../features/confessions/data/firestore_confession_repository.dart';
import '../features/profile/data/firebase_profile_repository.dart';
import '../features/reports/data/firebase_report_repository.dart';
import '../firebase_options.dart';
import 'app_services.dart';

/// Wires the app to Firebase:
///
/// * Authentication (Google) for accounts.
/// * Cloud Firestore for profiles, settings, confessions, likes, reactions,
///   saves, views and reports.
/// * Google Analytics for product analytics.
///
/// Categories are app configuration and ship with the app
/// (`assets/mock/categories.json`); the security rules hold the same list.
///
/// If `flutterfire configure` hasn't been run, start-up fails with a
/// [ConfigurationException] that carries the exact setup steps.
class Bootstrapper {
  const Bootstrapper({
    this.assetLoader = rootBundleLoader,
    this.shareService = const SharePlusShareService(),
  });

  final AssetLoader assetLoader;
  final ShareService shareService;

  Future<AppServices> create(AppConfig config) async {
    await _initializeFirebase();
    final auth = fb.FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final categories = await AssetCategoryRepository(
      loader: assetLoader,
    ).loadCategories();

    Analytics analytics;
    try {
      analytics = await FirebaseAnalyticsService.create();
    } catch (_) {
      analytics = const NoopAnalytics();
    }

    return AppServices(
      config: config,
      auth: FirebaseAuthRepository(auth: auth),
      profiles: FirebaseProfileRepository(auth: auth, firestore: firestore),
      confessions: FirestoreConfessionRepository(
        auth: auth,
        firestore: firestore,
        maxLength: config.maxConfessionLength,
        minLength: config.minConfessionLength,
      ),
      reports: FirebaseReportRepository(auth: auth, firestore: firestore),
      categories: categories,
      share: shareService,
      analytics: analytics,
    );
  }

  static const _setupSteps = [
    'Install the CLIs: `npm i -g firebase-tools` and '
        '`dart pub global activate flutterfire_cli`.',
    'Run `firebase login`, then `flutterfire configure` in the project root.',
    'In the Firebase Console, open Authentication, then Sign-in method, '
        'and enable Google.',
    'Android: add your SHA-1 and SHA-256 fingerprints in Project settings, '
        'then re-run `flutterfire configure`.',
    'Create a Cloud Firestore database and run '
        '`firebase deploy --only firestore`.',
    'Optional: load the sample confessions with `npm run seed` in '
        'firebase/seed.',
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
