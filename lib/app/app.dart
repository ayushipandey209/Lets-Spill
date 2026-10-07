import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/analytics/analytics.dart';
import '../core/config/app_config.dart';
import '../core/data/key_value_store.dart';
import '../core/services/onesignal_service.dart';
import '../core/services/share_service.dart';
import '../core/widgets/common.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/categories/domain/category.dart';
import '../features/confessions/domain/confession_repository.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/presentation/pages/intro_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/profile/domain/profile_repository.dart';
import '../features/reports/domain/report_repository.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_cubit.dart';
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
    this.deviceStore,
    this.minimumSplash = const Duration(milliseconds: 700),
  });

  final AppConfig config;
  final ServicesFactory createServices;

  /// Where settings are kept on this device. Defaults to memory (tests).
  final KeyValueStore? deviceStore;
  final Duration minimumSplash;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AppInitCubit(
            config: config,
            createServices: createServices,
            minimumSplash: minimumSplash,
          )..initialize(),
        ),
        BlocProvider(
          create: (_) =>
              SettingsCubit(store: deviceStore ?? InMemoryKeyValueStore())
                ..load(),
        ),
      ],
      child: const _AppView(),
    );
  }
}

/// Forwards to the real analytics once services are ready, so the route
/// observer can be created together with the navigator.
class _DeferredAnalytics implements Analytics {
  Analytics target = const NoopAnalytics();

  @override
  Future<void> log(String event, [Map<String, Object> params = const {}]) =>
      target.log(event, params);

  @override
  Future<void> screen(String name) => target.screen(name);

  @override
  Future<void> setUser(String? uid) => target.setUser(uid);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      target.setUserProperty(name, value);

  @override
  Future<void> setEnabled(bool enabled) => target.setEnabled(enabled);
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _lightTheme = AppTheme.light();
  final _darkTheme = AppTheme.dark();
  final _analytics = _DeferredAnalytics();
  late final _routeObserver = AnalyticsRouteObserver(_analytics);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: settings.theme.themeMode,
      themeAnimationDuration: settings.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      home: const _SessionGate(),
      // Until services are ready the splash replaces the navigator. Once
      // ready, providers sit above the navigator so every route sees them.
      builder: (context, child) {
        return _ReadingPreferences(
          settings: settings,
          child: BlocBuilder<AppInitCubit, AppInitState>(
            builder: (context, state) {
              final services = state.services;
              if (state.status != AppInitStatus.ready || services == null) {
                return SplashPage(state: state);
              }
              _analytics.target = services.analytics;
              return _ServicesScope(
                services: services,
                navigatorKey: _navigatorKey,
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        );
      },
    );
  }
}

/// Applies the text size and reduce motion settings on top of the device's
/// own accessibility settings.
class _ReadingPreferences extends StatelessWidget {
  const _ReadingPreferences({required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final deviceScale = mq.textScaler.scale(14) / 14;
    final scale = (deviceScale * settings.textSize.scale).clamp(0.8, 2.0);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: mq.disableAnimations || settings.reduceMotion,
      ),
      child: child,
    );
  }
}

class _ServicesScope extends StatefulWidget {
  const _ServicesScope({
    required this.services,
    required this.navigatorKey,
    required this.child,
  });

  final AppServices services;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<_ServicesScope> createState() => _ServicesScopeState();
}

class _ServicesScopeState extends State<_ServicesScope> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _subscribeToOneSignal();
  }

  void _subscribeToOneSignal() {
    widget.services.notifications.addPushSubscriptionObserver((_) {
      _showVerificationDialogIfNeeded();
    });
  }

  void _showVerificationDialogIfNeeded() {
    if (_dialogShown) return;
    _dialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = widget.navigatorKey.currentContext;
      if (navContext == null || !mounted) return;

      showDialog<void>(
        context: navContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Your OneSignal SDK integration is complete!'),
            content: const Text(
              'You can now send Push Notifications & In-App Messages through OneSignal. '
              'Tap below to enable push notifications.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  widget.services.notifications.requestPushPermission();
                },
                child: const Text('Got it'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppServices>.value(value: widget.services),
        RepositoryProvider<AppConfig>.value(value: widget.services.config),
        RepositoryProvider<AuthRepository>.value(value: widget.services.auth),
        RepositoryProvider<ProfileRepository>.value(
          value: widget.services.profiles,
        ),
        RepositoryProvider<ConfessionRepository>.value(
          value: widget.services.confessions,
        ),
        RepositoryProvider<ReportRepository>.value(
          value: widget.services.reports,
        ),
        RepositoryProvider<CategoryCatalog>.value(
          value: widget.services.categories,
        ),
        RepositoryProvider<ShareService>.value(value: widget.services.share),
        RepositoryProvider<Analytics>.value(value: widget.services.analytics),
        RepositoryProvider<NotificationService>.value(
          value: widget.services.notifications,
        ),
      ],
      child: BlocProvider(
        create: (_) => SessionCubit(
          auth: widget.services.auth,
          profiles: widget.services.profiles,
        ),
        child: MultiBlocListener(
          listeners: [
            BlocListener<SessionCubit, SessionState>(
              listenWhen: (prev, curr) =>
                  prev.status != curr.status &&
                  curr.status != SessionStatus.loadingProfile,
              // When the session changes stage, drop pushed routes so the
              // gate is on top (e.g. after sign-out or account deletion).
              listener: (context, state) {
                widget.navigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
              },
            ),
            BlocListener<SessionCubit, SessionState>(
              listenWhen: (prev, curr) =>
                  prev.status != curr.status ||
                  prev.profile?.uid != curr.profile?.uid,
              listener: (context, state) => _syncAccount(context, state),
            ),
            BlocListener<SettingsCubit, AppSettings>(
              listenWhen: (prev, curr) => prev != curr,
              listener: (context, settings) =>
                  _applySettingsToAnalytics(settings),
            ),
          ],
          child: widget.child,
        ),
      ),
    );
  }

  /// Keeps analytics and notifications identity and synced settings in step with the session.
  void _syncAccount(BuildContext context, SessionState state) {
    final analytics = widget.services.analytics;
    final notifications = widget.services.notifications;
    final settingsCubit = context.read<SettingsCubit>();
    switch (state.status) {
      case SessionStatus.signedOut:
        settingsCubit.remoteSaver = null;
        analytics
          ..setUser(null)
          ..setUserProperty(AnalyticsProperties.ageRange, null)
          ..screen('intro');
        notifications.logout();
      case SessionStatus.needsOnboarding:
        final uid = state.user?.uid;
        analytics
          ..setUser(uid)
          ..screen('onboarding');
        if (uid != null) {
          notifications.login(uid);
        }
      case SessionStatus.ready:
        final profile = state.profile!;
        analytics
          ..setUser(profile.uid)
          ..setUserProperty(
            AnalyticsProperties.ageRange,
            profile.ageRange.name,
          )
          ..setUserProperty(
            AnalyticsProperties.categoriesCount,
            '${profile.preferredCategoryIds.length}',
          );
        notifications.login(profile.uid);
        settingsCubit.remoteSaver = widget.services.profiles.updateSettings;
        final remote = profile.settings;
        if (remote != null) {
          settingsCubit.adoptRemote(remote);
        } else {
          // First sign-in on this account: keep what was chosen on device.
          widget.services.profiles.updateSettings(settingsCubit.state).catchError(
            (Object _) {},
          );
        }
        _applySettingsToAnalytics(settingsCubit.state);
      case SessionStatus.unknown:
      case SessionStatus.loadingProfile:
      case SessionStatus.failure:
        break;
    }
  }

  void _applySettingsToAnalytics(AppSettings s) {
    final analytics = widget.services.analytics;
    analytics
      ..setEnabled(s.analyticsEnabled)
      ..setUserProperty(AnalyticsProperties.theme, s.theme.name)
      ..setUserProperty(AnalyticsProperties.textSize, s.textSize.name)
      ..setUserProperty(AnalyticsProperties.feedLayout, s.feedLayout.name);
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
          SessionStatus.ready => HomeShell(key: ValueKey(state.profile!.uid)),
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
