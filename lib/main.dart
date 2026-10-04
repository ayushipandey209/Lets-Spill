import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/config/app_config.dart';

/// Entry point. Requires a Firebase project (Google sign-in + Firestore for
/// profiles); see docs/FIREBASE_SETUP.md. Confession content comes from the
/// bundled JSON in assets/mock/.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  const bootstrapper = Bootstrapper();
  runApp(LetsSpillApp(config: config, createServices: bootstrapper.create));
}
