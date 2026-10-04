import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';

/// Wraps the platform share sheet so BLoCs stay testable.
abstract interface class ShareService {
  Future<void> shareText(String text, {String? subject, Rect? origin});
}

class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
  }
}

/// Builds the text that gets shared. Only the confession text and a generic
/// attribution — no URLs (there is no public deep link yet), no author data.
String buildShareText(String confessionText) {
  return '“${confessionText.trim()}”\n\n'
      '— shared anonymously from ${AppConfig.appName}. ${AppConfig.tagline}';
}
