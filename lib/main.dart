import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/config/app_config.dart';
import 'core/data/key_value_store.dart';

/// Entry point. Requires a Firebase project (Google sign-in, Cloud Firestore
/// and Google Analytics); see docs/FIREBASE_SETUP.md.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  // Opened before the first frame so the saved theme applies immediately.
  final deviceStore = await openDeviceStore();
  const bootstrapper = Bootstrapper();
  runApp(
    LetsSpillApp(
      config: config,
      createServices: bootstrapper.create,
      deviceStore: deviceStore,
    ),
  );
}
