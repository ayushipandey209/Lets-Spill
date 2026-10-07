import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'analytics.dart';

/// Google Analytics for Firebase.
///
/// * Ad personalisation signals are switched off: some readers are 13 to 17
///   and the app shows no ads.
/// * Collection follows the in-app "Usage analytics" setting.
/// * Errors never reach the UI; analytics is best-effort.
class FirebaseAnalyticsService implements Analytics {
  FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  static Future<FirebaseAnalyticsService> create() async {
    final service = FirebaseAnalyticsService(FirebaseAnalytics.instance);
    await service._safe(
      () => FirebaseAnalytics.instance.setConsent(
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        analyticsStorageConsentGranted: true,
      ),
    );
    return service;
  }

  Future<void> _safe(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics error: $e');
    }
  }

  @override
  Future<void> log(String event, [Map<String, Object> params = const {}]) =>
      _safe(() {
        final cleaned = <String, Object>{
          for (final e in params.entries)
            e.key: switch (e.value) {
              final bool b => b ? 1 : 0,
              final num n => n,
              final Object o => _trim(o.toString()),
            },
        };
        return switch (event) {
          AnalyticsEvents.login => _analytics.logLogin(
            loginMethod: 'google',
            parameters: cleaned,
          ),
          AnalyticsEvents.signUp => _analytics.logSignUp(
            signUpMethod: 'google',
            parameters: cleaned,
          ),
          _ => _analytics.logEvent(name: event, parameters: cleaned),
        };
      });

  static String _trim(String v) => v.length > 100 ? v.substring(0, 100) : v;

  @override
  Future<void> screen(String name) =>
      _safe(() => _analytics.logScreenView(screenName: name, screenClass: name));

  @override
  Future<void> setUser(String? uid) => _safe(() => _analytics.setUserId(id: uid));

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _safe(() => _analytics.setUserProperty(name: name, value: value));

  @override
  Future<void> setEnabled(bool enabled) =>
      _safe(() => _analytics.setAnalyticsCollectionEnabled(enabled));
}
