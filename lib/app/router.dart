import 'package:flutter/material.dart';

import '../features/confession_detail/presentation/pages/confession_detail_page.dart';
import '../features/confessions/domain/confession.dart';
import '../features/create_confession/presentation/pages/create_confession_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/presentation/pages/delete_account_page.dart';
import '../features/settings/presentation/pages/guidelines_page.dart';
import '../features/settings/presentation/pages/info_page.dart';

/// Named routes. Onboarding and sign-in aren't routes: the session gate in
/// `app.dart` swaps them in and out.
abstract final class AppRoutes {
  static const confession = '/confession';
  static const create = '/create';
  static const profile = '/profile';
  static const search = '/search';
  static const guidelines = '/guidelines';
  static const deleteAccount = '/delete-account';
  static const info = '/info';
}

/// Arguments for [AppRoutes.confession].
class ConfessionRouteArgs {
  const ConfessionRouteArgs({required this.id, this.initial});
  final String id;

  /// Card data shown instantly while fresh data loads.
  final Confession? initial;
}

abstract final class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    Widget? page;
    var fullscreenDialog = false;
    switch (settings.name) {
      case AppRoutes.confession:
        final args = settings.arguments;
        if (args is ConfessionRouteArgs) {
          page = ConfessionDetailPage(
            confessionId: args.id,
            initial: args.initial,
          );
        }
      case AppRoutes.create:
        page = const CreateConfessionPage();
        fullscreenDialog = true;
      case AppRoutes.profile:
        page = const ProfilePage();
      case AppRoutes.search:
        page = const SearchPage();
      case AppRoutes.guidelines:
        page = const GuidelinesPage();
      case AppRoutes.deleteAccount:
        page = const DeleteAccountPage();
      case AppRoutes.info:
        final args = settings.arguments;
        if (args is InfoPageArgs) page = InfoPage(args: args);
    }
    if (page == null) return null;
    final built = page;
    return MaterialPageRoute<dynamic>(
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      builder: (_) => built,
    );
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Page not found.')),
      ),
    );
  }
}
