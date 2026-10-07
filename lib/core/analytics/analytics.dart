import 'package:flutter/widgets.dart';

/// App-wide analytics. Widgets and BLoCs depend on this interface only;
/// production uses `FirebaseAnalyticsService`, tests use [NoopAnalytics].
///
/// Privacy: never pass confession text, search terms, names or emails.
/// Event parameters are ids, categories, counts and choices only.
abstract interface class Analytics {
  Future<void> log(String event, [Map<String, Object> params = const {}]);

  Future<void> screen(String name);

  Future<void> setUser(String? uid);

  Future<void> setUserProperty(String name, String? value);

  /// Turns collection on or off (Settings > Privacy > Usage analytics).
  Future<void> setEnabled(bool enabled);
}

/// Does nothing. Used in tests and when Firebase Analytics is unavailable.
class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> log(String event, [Map<String, Object> params = const {}]) async {}

  @override
  Future<void> screen(String name) async {}

  @override
  Future<void> setUser(String? uid) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// Records events in memory. Handy for tests.
class RecordingAnalytics implements Analytics {
  final events = <(String, Map<String, Object>)>[];
  final screens = <String>[];
  final properties = <String, String?>{};
  String? userId;
  bool enabled = true;

  @override
  Future<void> log(String event, [Map<String, Object> params = const {}]) async {
    events.add((event, params));
  }

  @override
  Future<void> screen(String name) async => screens.add(name);

  @override
  Future<void> setUser(String? uid) async => userId = uid;

  @override
  Future<void> setUserProperty(String name, String? value) async =>
      properties[name] = value;

  @override
  Future<void> setEnabled(bool enabled) async => this.enabled = enabled;
}

/// Every custom event name in one place (snake_case, max 40 chars).
abstract final class AnalyticsEvents {
  // Account
  static const login = 'login';
  static const signUp = 'sign_up';
  static const signOut = 'sign_out';
  static const onboardingStep = 'onboarding_step';
  static const accountDeleted = 'account_deleted';

  // Reading
  static const feedTab = 'feed_tab_select';
  static const feedCategory = 'feed_category_select';
  static const feedRefresh = 'feed_refresh';
  static const feedLoadMore = 'feed_load_more';
  static const confessionOpen = 'confession_open';
  static const confessionView = 'confession_view_qualified';
  static const confessionOfDayOpen = 'cotd_open';
  static const categoryOpen = 'category_open';
  static const search = 'search';

  // Engagement
  static const like = 'confession_like';
  static const unlike = 'confession_unlike';
  static const react = 'confession_react';
  static const save = 'confession_save';
  static const unsave = 'confession_unsave';
  static const share = 'share';
  static const report = 'confession_report';

  // Writing
  static const createStart = 'confession_create_start';
  static const createPost = 'confession_post';
  static const createDiscard = 'confession_discard';
  static const deletePost = 'confession_delete';

  // Settings
  static const settingChanged = 'setting_changed';
  static const preferencesSaved = 'reading_prefs_saved';
}

/// User properties (max 24 chars for names, 36 for values).
abstract final class AnalyticsProperties {
  static const ageRange = 'age_range';
  static const theme = 'theme';
  static const textSize = 'text_size';
  static const feedLayout = 'feed_layout';
  static const categoriesCount = 'pref_categories';
}

/// Logs a screen view for every named route.
class AnalyticsRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  AnalyticsRouteObserver(this.analytics);

  final Analytics analytics;

  void _send(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (route is PageRoute<dynamic> && name != null && name.isNotEmpty) {
      analytics.screen(_screenName(name));
    }
  }

  static String _screenName(String routeName) {
    final cleaned = routeName.replaceAll('/', ' ').trim().replaceAll(' ', '_');
    return cleaned.isEmpty ? 'home' : cleaned;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _send(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _send(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _send(previousRoute);
  }
}
