import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config/app_config.dart';
import '../core/services/share_service.dart';
import '../core/widgets/common.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/categories/domain/category.dart';
import '../features/confessions/domain/confession_repository.dart';
import '../features/feed/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/intro_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/profile/domain/profile_repository.dart';
import '../features/reports/domain/report_repository.dart';
import 'app_services.dart';
import 'init/app_init_cubit.dart';
import 'init/splash_page.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root widget.
class LetsSpillApp extends StatelessWidget {
  const LetsSpillApp({
    super.key,
    required this.config,
    required this.createServices,
    this.minimumSplash = const Duration(milliseconds: 700),
  });

  final AppConfig config;
  final ServicesFactory createServices;
  final Duration minimumSplash;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppInitCubit(
        config: config,
        createServices: createServices,
        minimumSplash: minimumSplash,
      )..initialize(),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _theme = AppTheme.light();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: _theme,
      themeMode: ThemeMode.light,
      navigatorKey: _navigatorKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      home: const _SessionGate(),
      // Until services are ready the splash replaces the navigator. Once
      // ready, providers sit *above* the navigator so every route sees them.
      builder: (context, child) {
        return BlocBuilder<AppInitCubit, AppInitState>(
          builder: (context, state) {
            final services = state.services;
            if (state.status != AppInitStatus.ready || services == null) {
              return SplashPage(state: state);
            }
            return _ServicesScope(
              services: services,
              navigatorKey: _navigatorKey,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

class _ServicesScope extends StatelessWidget {
  const _ServicesScope({
    required this.services,
    required this.navigatorKey,
    required this.child,
  });

  final AppServices services;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppServices>.value(value: services),
        RepositoryProvider<AppConfig>.value(value: services.config),
        RepositoryProvider<AuthRepository>.value(value: services.auth),
        RepositoryProvider<ProfileRepository>.value(value: services.profiles),
        RepositoryProvider<ConfessionRepository>.value(
          value: services.confessions,
        ),
        RepositoryProvider<ReportRepository>.value(value: services.reports),
        RepositoryProvider<CategoryCatalog>.value(value: services.categories),
        RepositoryProvider<ShareService>.value(value: services.share),
      ],
      child: BlocProvider(
        create: (_) =>
            SessionCubit(auth: services.auth, profiles: services.profiles),
        child: BlocListener<SessionCubit, SessionState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status &&
              curr.status != SessionStatus.loadingProfile,
          // When the session changes stage, drop pushed routes so the gate
          // is on top (e.g. after sign-out or account deletion).
          listener: (context, state) {
            navigatorKey.currentState?.popUntil((route) => route.isFirst);
          },
          child: child,
        ),
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.user?.uid != c.user?.uid ||
          p.profile?.uid != c.profile?.uid,
      builder: (context, state) {
        final Widget page = switch (state.status) {
          SessionStatus.unknown || SessionStatus.loadingProfile =>
            const SplashPage(state: AppInitState.loading()),
          SessionStatus.signedOut => const IntroPage(),
          SessionStatus.needsOnboarding => const OnboardingPage(),
          SessionStatus.ready => HomePage(key: ValueKey(state.profile!.uid)),
          SessionStatus.failure => Scaffold(
            body: Center(
              child: StatusMessage(
                icon: Icons.cloud_off_outlined,
                title: "Couldn't load your profile",
                message: state.errorMessage,
                actionLabel: 'Try again',
                onAction: () => context.read<SessionCubit>().retry(),
              ),
            ),
          ),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(key: ValueKey(state.status), child: page),
        );
      },
    );
  }
}
