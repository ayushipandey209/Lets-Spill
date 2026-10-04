import 'package:flutter/services.dart' show rootBundle;

/// Loads a bundled text asset. Injected so tests can supply fixtures.
typedef AssetLoader = Future<String> Function(String path);

Future<String> rootBundleLoader(String path) => rootBundle.loadString(path);
