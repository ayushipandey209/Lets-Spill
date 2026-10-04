import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../../core/widgets/common.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../../../settings/presentation/pages/info_page.dart';
import '../../domain/profile_repository.dart';
import '../bloc/profile_cubit.dart';

/// Private profile & settings. The Google name and email appear only here.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionCubit>();
    final profile = session.state.profile;
    if (profile == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    return BlocProvider(
      create: (context) => ProfileCubit(
        profile: profile,
        profileRepository: context.read<ProfileRepository>(),
        confessionRepository: context.read<ConfessionRepository>(),
        onProfileUpdated: session.profileUpdated,
      )..load(),
      child: const ProfileView(),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (p, c) => p.notice != c.notice && c.notice != null,
      listener: (context, state) => showNotice(context, state.notice!),
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('You')),
          body: _ProfileBody(state: state),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.state});
  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profile = state.profile;
    final user = context.select((SessionCubit c) => c.state.user);
    final categories = context.read<CategoryCatalog>();
    final cubit = context.read<ProfileCubit>();
    final list = state.section == ProfileSection.mine
        ? state.myConfessions
        : state.saved;

    return ListView(
      padding: responsiveHorizontalPadding(
        context,
      ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.xxl),
      children: [
        // --- Identity ------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: t.ink,
            borderRadius: AppRadii.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.masks_outlined, color: t.onInk, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Eyebrow(
                    'Your anonymous name',
                    color: t.onInk.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                profile.handle,
                style: context.text.headlineMedium!.copyWith(color: t.onInk),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _InvertedPill('Age ${profile.ageRange.label}'),
                  _InvertedPill('${state.myConfessions.length} posted'),
                  _InvertedPill('${state.saved.length} saved'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (user != null)
          NoteBox(
            icon: Icons.lock_outline,
            child: Text(
              'Signed in with Google as ${user.displayName.isEmpty ? user.email : '${user.displayName} · ${user.email}'}. '
              'Only you can see this — it never appears on confessions.',
            ),
          ),
        const SizedBox(height: AppSpacing.xl),

        // --- Preferences ---------------------------------------------------
        const SectionTitle(
          'What you like to read',
          subtitle: 'Shapes your "For you" feed and Confession of the Day.',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final c in categories.categories)
              SelectableCategoryChip(
                key: ValueKey('pref-${c.id}'),
                label: c.name,
                showCheck: true,
                selected: state.draftCategoryIds.contains(c.id),
                onTap: () => cubit.toggleCategory(c.id),
              ),
          ],
        ),
        AnimatedSize(
          duration: AppMotion.fast,
          child: state.hasUnsavedPreferences ||
                  state.prefsStatus == SubmitStatus.submitting
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimaryButton(
                      label: 'Save preferences',
                      expand: false,
                      busy: state.prefsStatus == SubmitStatus.submitting,
                      onPressed: cubit.savePreferences,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Your confessions / Saved ---------------------------------------
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            SelectableCategoryChip(
              key: const ValueKey('section-mine'),
              label: 'Your confessions',
              selected: state.section == ProfileSection.mine,
              onTap: () => cubit.selectSection(ProfileSection.mine),
            ),
            SelectableCategoryChip(
              key: const ValueKey('section-saved'),
              label: 'Saved',
              selected: state.section == ProfileSection.saved,
              onTap: () => cubit.selectSection(ProfileSection.saved),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.status == ProfileStatus.loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (state.status == ProfileStatus.failure)
          StatusMessage(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load your lists",
            message: state.errorMessage,
            actionLabel: 'Try again',
            onAction: cubit.load,
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              state.section == ProfileSection.mine
                  ? "You haven't spilled anything yet."
                  : 'Tap the bookmark on any confession to save it here.',
              style: context.text.bodyMedium!.copyWith(color: t.inkMuted),
            ),
          )
        else
          for (final c in list) ...[
            ConfessionCard(
              key: ValueKey('${state.section.name}-${c.id}'),
              confession: c,
              categories: categories,
              maxLines: 4,
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.confession,
                arguments: ConfessionRouteArgs(id: c.id, initial: c),
              ),
              trailing: state.section == ProfileSection.mine
                  ? (state.deletingIds.contains(c.id)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: 'Delete this confession',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _confirmDelete(context, c),
                          ))
                  : IconButton(
                      tooltip: 'Remove from saved',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.bookmark, size: 20),
                      onPressed: () => cubit.unsave(c.id),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        const SizedBox(height: AppSpacing.lg),

        // --- Settings ------------------------------------------------------
        const SectionTitle('Settings & support'),
        const SizedBox(height: AppSpacing.sm),
        const _SettingsList(),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Confession c) async {
    final cubit = context.read<ProfileCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this confession?'),
        content: const Text(
          'It will be removed from the feed for everyone. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await cubit.deleteConfession(c.id);
  }
}

class _InvertedPill extends StatelessWidget {
  const _InvertedPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: t.onInk.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: context.text.labelMedium!.copyWith(color: t.onInk),
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList();

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final t = context.tokens;

    Widget tile({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
      Color? color,
    }) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: color == null
              ? null
              : context.text.titleMedium!.copyWith(color: color),
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: t.inkMuted),
        onTap: onTap,
      );
    }

    void openInfo(InfoPageArgs args) =>
        Navigator.of(context).pushNamed(AppRoutes.info, arguments: args);

    return Column(
      children: [
        tile(
          icon: Icons.menu_book_outlined,
          title: 'Community guidelines',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.guidelines),
        ),
        const HairlineDivider(),
        tile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          subtitle: config.privacyPolicyUrl == null
              ? 'Placeholder — add a real URL before launch'
              : null,
          onTap: () => openInfo(InfoPageArgs.privacy(config)),
        ),
        const HairlineDivider(),
        tile(
          icon: Icons.support_agent_outlined,
          title: 'Contact & report support',
          subtitle: config.supportContact == null
              ? 'Placeholder — add real contact details before launch'
              : null,
          onTap: () => openInfo(InfoPageArgs.support(config)),
        ),
        const HairlineDivider(),
        tile(
          icon: Icons.logout,
          title: 'Sign out',
          onTap: () => context.read<SessionCubit>().signOut(),
        ),
        const HairlineDivider(),
        tile(
          icon: Icons.delete_forever_outlined,
          title: 'Delete account',
          color: t.error,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.deleteAccount),
        ),
      ],
    );
  }
}
