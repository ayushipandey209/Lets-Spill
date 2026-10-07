import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/router.dart';
import '../../core/analytics/analytics.dart';
import '../../core/config/app_config.dart';
import '../auth/presentation/session_cubit.dart';
import '../confessions/domain/confession_repository.dart';
import '../explore/explore_page.dart';
import '../feed/presentation/bloc/feed_bloc.dart';
import '../feed/presentation/pages/home_page.dart';
import '../profile/presentation/pages/profile_page.dart';
import '../settings/domain/app_settings.dart';
import '../settings/presentation/settings_cubit.dart';

/// Signed-in shell: Home, Explore, Spill and You, Reddit style.
///
/// Tabs keep their state (scroll position, loaded pages) while you switch.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// Bumped when the current tab is tapped again (scroll to top).
  final _reselect = ValueNotifier<int>(0);

  static const _screenNames = ['home', 'explore', 'profile'];

  @override
  void dispose() {
    _reselect.dispose();
    super.dispose();
  }

  void _onDestination(int index) {
    final settings = context.read<SettingsCubit>().state;
    if (settings.haptics) HapticFeedback.selectionClick();
    // The third destination is the Spill button: it opens the composer.
    if (index == 2) {
      Navigator.of(context).pushNamed(AppRoutes.create);
      return;
    }
    final tab = index > 2 ? index - 1 : index;
    if (tab == _tab) {
      _reselect.value++;
      return;
    }
    setState(() => _tab = tab);
    context.read<Analytics>().screen(_screenNames[tab]);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final session = context.read<SessionCubit>().state;
    final settings = context.read<SettingsCubit>().state;
    return BlocProvider(
      create: (context) => FeedBloc(
        repository: context.read<ConfessionRepository>(),
        pageSize: config.feedPageSize,
        preferences: feedPreferencesFor(session.profile, settings),
        initialTab: tabFor(settings.defaultFeed),
        analytics: context.read<Analytics>(),
      )..add(const FeedStarted()),
      child: MultiBlocListener(
        listeners: [
          BlocListener<SessionCubit, SessionState>(
            listenWhen: (p, c) => p.profile != c.profile && c.profile != null,
            listener: (context, state) => context.read<FeedBloc>().add(
              FeedPreferencesChanged(
                feedPreferencesFor(
                  state.profile,
                  context.read<SettingsCubit>().state,
                ),
              ),
            ),
          ),
          BlocListener<SettingsCubit, AppSettings>(
            listener: (context, settings) => context.read<FeedBloc>().add(
              FeedPreferencesChanged(
                feedPreferencesFor(
                  context.read<SessionCubit>().state.profile,
                  settings,
                ),
              ),
            ),
          ),
        ],
        child: Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              FeedView(reselect: _reselect, active: _tab == 0),
              ExplorePage(reselect: _reselect, active: _tab == 1),
              ProfileTab(reselect: _reselect, active: _tab == 2),
            ],
          ),
          bottomNavigationBar: _BottomBar(
            selected: _tab >= 2 ? _tab + 1 : _tab,
            onSelected: _onDestination,
          ),
        ),
      ),
    );
  }
}

FeedTab tabFor(DefaultFeed feed) => switch (feed) {
  DefaultFeed.forYou => FeedTab.forYou,
  DefaultFeed.hot => FeedTab.hot,
  DefaultFeed.latest => FeedTab.latest,
  DefaultFeed.top => FeedTab.top,
};

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: onSelected,
        destinations: const [
          NavigationDestination(
            key: ValueKey('nav-home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            key: ValueKey('nav-explore'),
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            key: ValueKey('nav-spill'),
            icon: _SpillIcon(),
            label: 'Spill',
            tooltip: 'Write a confession',
          ),
          NavigationDestination(
            key: ValueKey('nav-profile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}

class _SpillIcon extends StatelessWidget {
  const _SpillIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 30,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.add, color: scheme.onPrimary, size: 22),
    );
  }
}
