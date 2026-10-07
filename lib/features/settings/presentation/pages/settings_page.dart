import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../domain/app_settings.dart';
import '../settings_cubit.dart';
import 'info_page.dart';

/// Every setting in one place, grouped like Reddit's settings screen.
/// Changes apply instantly and sync to the account.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final session = context.watch<SessionCubit>().state;
    final profile = session.profile;
    final user = session.user;
    final adult = profile?.canSeeMature ?? false;
    final config = context.read<AppConfig>();
    final t = context.tokens;

    void set(String key, String value, AppSettings next) {
      context.read<SettingsCubit>().update(next);
      context.read<Analytics>().log(AnalyticsEvents.settingChanged, {
        'setting': key,
        'value': value,
      });
    }

    void openInfo(InfoPageArgs args) =>
        Navigator.of(context).pushNamed(AppRoutes.info, arguments: args);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: responsiveHorizontalPadding(
          context,
          side: AppSpacing.md,
        ).copyWith(top: AppSpacing.xs, bottom: AppSpacing.xxl),
        children: [
          // ---------------------------------------------------- Account ---
          _Section(
            title: 'Account',
            children: [
              _InfoRow(
                icon: Icons.masks_outlined,
                title: 'Anonymous name',
                value: profile?.handle ?? '',
              ),
              _InfoRow(
                icon: Icons.cake_outlined,
                title: 'Age range',
                value: profile?.ageRange.label ?? '',
              ),
              if (user != null)
                _InfoRow(
                  icon: Icons.lock_outline,
                  title: 'Signed in with Google',
                  value: user.email.isEmpty ? user.displayName : user.email,
                  note: 'Private. Never shown on confessions.',
                ),
            ],
          ),

          // ------------------------------------------------- Appearance ---
          _Section(
            title: 'Appearance',
            children: [
              _OptionGroup<AppThemePreference>(
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                values: AppThemePreference.values,
                selected: settings.theme,
                label: (v) => v.label,
                onSelected: (v) =>
                    set('theme', v.name, settings.copyWith(theme: v)),
              ),
              _OptionGroup<TextSizePreference>(
                icon: Icons.format_size,
                title: 'Text size',
                values: TextSizePreference.values,
                selected: settings.textSize,
                label: (v) => v.label,
                onSelected: (v) =>
                    set('text_size', v.name, settings.copyWith(textSize: v)),
              ),
              _OptionGroup<FeedLayout>(
                icon: Icons.view_agenda_outlined,
                title: 'Feed layout',
                subtitle: settings.feedLayout.description,
                values: FeedLayout.values,
                selected: settings.feedLayout,
                label: (v) => v.label,
                onSelected: (v) =>
                    set('feed_layout', v.name, settings.copyWith(feedLayout: v)),
              ),
              _SwitchRow(
                icon: Icons.motion_photos_off_outlined,
                title: 'Reduce motion',
                subtitle: 'Fewer animations and transitions.',
                value: settings.reduceMotion,
                onChanged: (v) => set(
                  'reduce_motion',
                  '$v',
                  settings.copyWith(reduceMotion: v),
                ),
              ),
            ],
          ),

          // ---------------------------------------------- Feed & content ---
          _Section(
            title: 'Feed and content',
            children: [
              _OptionGroup<DefaultFeed>(
                icon: Icons.home_outlined,
                title: 'Home opens on',
                values: DefaultFeed.values,
                selected: settings.defaultFeed,
                label: (v) => v.label,
                onSelected: (v) => set(
                  'default_feed',
                  v.name,
                  settings.copyWith(defaultFeed: v),
                ),
              ),
              _SwitchRow(
                icon: Icons.wb_sunny_outlined,
                title: 'Confession of the day',
                subtitle: 'Show the featured confession at the top of Home.',
                value: settings.showConfessionOfDay,
                onChanged: (v) => set(
                  'confession_of_day',
                  '$v',
                  settings.copyWith(showConfessionOfDay: v),
                ),
              ),
              if (adult) ...[
                _SwitchRow(
                  icon: Icons.eighteen_up_rating_outlined,
                  title: 'Show 18+ confessions',
                  subtitle: 'Posts with adult themes.',
                  value: settings.showMature,
                  onChanged: (v) => set(
                    'show_mature',
                    '$v',
                    settings.copyWith(showMature: v),
                  ),
                ),
                if (settings.showMature)
                  _SwitchRow(
                    icon: Icons.blur_on,
                    title: 'Blur 18+ previews',
                    subtitle: 'Tap a blurred post to read it.',
                    value: settings.blurMature,
                    onChanged: (v) => set(
                      'blur_mature',
                      '$v',
                      settings.copyWith(blurMature: v),
                    ),
                  ),
              ] else
                const _NoteRow(
                  icon: Icons.shield_outlined,
                  text:
                      '18+ confessions are always hidden for readers aged '
                      '13 to 17.',
                ),
              const _InterestsEditor(),
              _MutedCategories(
                muted: settings.mutedCategoryIds,
                onChanged: (ids) => set(
                  'muted_categories',
                  '${ids.length}',
                  settings.copyWith(mutedCategoryIds: ids),
                ),
              ),
            ],
          ),

          // ---------------------------------------------------- Posting ---
          _Section(
            title: 'Posting',
            children: [
              _OptionGroup<PostIdentity>(
                icon: Icons.badge_outlined,
                title: 'Post as',
                subtitle: 'You can still change this on each post.',
                values: PostIdentity.values,
                selected: settings.postIdentity,
                label: (v) => v == PostIdentity.handle && profile != null
                    ? profile.handle
                    : v.label,
                onSelected: (v) => set(
                  'post_identity',
                  v.name,
                  settings.copyWith(postIdentity: v),
                ),
              ),
              _SwitchRow(
                icon: Icons.vibration,
                title: 'Haptic feedback',
                subtitle: 'A light tap when you like or switch tabs.',
                value: settings.haptics,
                onChanged: (v) =>
                    set('haptics', '$v', settings.copyWith(haptics: v)),
              ),
            ],
          ),

          // ---------------------------------------------------- Privacy ---
          _Section(
            title: 'Privacy',
            children: [
              _SwitchRow(
                icon: Icons.insights_outlined,
                title: 'Usage analytics',
                subtitle:
                    'Share anonymous usage data to help improve the app. '
                    'Never includes what you write or search for.',
                value: settings.analyticsEnabled,
                onChanged: (v) {
                  // Log before switching off so the choice itself is counted.
                  context.read<Analytics>().log(
                    AnalyticsEvents.settingChanged,
                    {'setting': 'analytics', 'value': '$v'},
                  );
                  context.read<SettingsCubit>().update(
                    settings.copyWith(analyticsEnabled: v),
                  );
                },
              ),
              _LinkRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                onTap: () => openInfo(InfoPageArgs.privacy(config)),
              ),
            ],
          ),

          // ---------------------------------------------------- Support ---
          _Section(
            title: 'Help and about',
            children: [
              _LinkRow(
                icon: Icons.menu_book_outlined,
                title: 'Community guidelines',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.guidelines),
              ),
              _LinkRow(
                icon: Icons.support_agent_outlined,
                title: 'Contact support',
                onTap: () => openInfo(InfoPageArgs.support(config)),
              ),
              _InfoRow(
                icon: Icons.info_outline,
                title: 'Version',
                value: AppConfig.version,
              ),
            ],
          ),

          // ---------------------------------------------------- Session ---
          _Section(
            title: 'Account actions',
            children: [
              _LinkRow(
                icon: Icons.logout,
                title: 'Sign out',
                showChevron: false,
                onTap: () => _confirmSignOut(context),
              ),
              _LinkRow(
                icon: Icons.delete_forever_outlined,
                title: 'Delete account',
                color: t.error,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.deleteAccount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your posts, likes and saves stay on your account. Sign in with '
          'the same Google account to pick up where you left off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      context.read<Analytics>().log(AnalyticsEvents.signOut);
      await context.read<SessionCubit>().signOut();
    }
  }
}

// --------------------------------------------------------------- pieces ---

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Eyebrow(title),
          ),
          Container(
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: AppRadii.card,
              border: Border.all(color: t.border.withValues(alpha: 0.7)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const HairlineDivider(indent: AppSpacing.md),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = color ?? t.ink;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall!.copyWith(color: fg),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.text.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          ),
          if (below != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: below!,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      title: title,
      subtitle: note == null ? value : '$value\n$note',
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.tokens.inkMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      title: title,
      color: color,
      onTap: onTap,
      trailing: showChevron
          ? Icon(Icons.chevron_right, color: context.tokens.inkMuted)
          : null,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: _RowShell(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class _OptionGroup<T> extends StatelessWidget {
  const _OptionGroup({
    required this.icon,
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      below: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final v in values)
            SelectableCategoryChip(
              label: label(v),
              showCheck: true,
              selected: v == selected,
              onTap: () => onSelected(v),
            ),
        ],
      ),
    );
  }
}

/// Reading interests (stored on the profile). Shapes For you and the
/// Confession of the Day.
class _InterestsEditor extends StatefulWidget {
  const _InterestsEditor();

  @override
  State<_InterestsEditor> createState() => _InterestsEditorState();
}

class _InterestsEditorState extends State<_InterestsEditor> {
  List<String>? _draft;
  bool _saving = false;

  List<String> get _saved =>
      context.read<SessionCubit>().state.profile?.preferredCategoryIds ??
      const [];

  bool get _dirty {
    final draft = _draft;
    if (draft == null) return false;
    final saved = _saved;
    return draft.length != saved.length || !saved.toSet().containsAll(draft);
  }

  void _toggle(String id) {
    final next = [...(_draft ?? _saved)];
    if (!next.remove(id)) next.add(id);
    setState(() => _draft = next);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final error = Validators.categories(draft);
    if (error != null) {
      showMessage(context, error, isError: true);
      return;
    }
    setState(() => _saving = true);
    final session = context.read<SessionCubit>();
    final analytics = context.read<Analytics>();
    try {
      final profile = await context
          .read<ProfileRepository>()
          .updatePreferredCategories(draft);
      session.profileUpdated(profile);
      analytics.log(AnalyticsEvents.preferencesSaved, {
        'count': draft.length,
      });
      if (!mounted) return;
      setState(() => _draft = null);
      showMessage(context, 'Interests saved. Your feed is updated.');
    } catch (e) {
      if (mounted) {
        showMessage(context, asAppException(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<CategoryCatalog>().categories;
    context.select((SessionCubit c) => c.state.profile?.preferredCategoryIds);
    final selected = _draft ?? _saved;
    return _RowShell(
      icon: Icons.interests_outlined,
      title: 'Your interests',
      subtitle: 'Shapes For you and the Confession of the day.',
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final c in categories)
                SelectableCategoryChip(
                  key: ValueKey('pref-${c.id}'),
                  label: c.name,
                  icon: categoryIcon(c.id),
                  showCheck: true,
                  selected: selected.contains(c.id),
                  onTap: _saving ? null : () => _toggle(c.id),
                ),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.fast,
            child: _dirty || _saving
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: PrimaryButton(
                      key: const ValueKey('save-interests'),
                      label: 'Save interests',
                      expand: false,
                      busy: _saving,
                      onPressed: _save,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _MutedCategories extends StatelessWidget {
  const _MutedCategories({required this.muted, required this.onChanged});

  final List<String> muted;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final categories = context.read<CategoryCatalog>().categories;
    return _RowShell(
      icon: Icons.do_not_disturb_on_outlined,
      title: 'Muted categories',
      subtitle: muted.isEmpty
          ? 'Hide a category from Home without leaving it.'
          : 'Hidden from Home. You can still open them from Explore.',
      below: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final c in categories)
            SelectableCategoryChip(
              key: ValueKey('mute-${c.id}'),
              label: c.name,
              icon: muted.contains(c.id)
                  ? Icons.notifications_off_outlined
                  : categoryIcon(c.id),
              selected: muted.contains(c.id),
              onTap: () {
                final next = [...muted];
                if (!next.remove(c.id)) next.add(c.id);
                onChanged(next);
              },
            ),
        ],
      ),
    );
  }
}
