import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/services/onesignal_service.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../../core/widgets/common.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
import '../bloc/onboarding_cubit.dart';

/// Onboarding after sign-in: anonymous username, then interests, then age.
/// Every answer is a tap; there is no text input anywhere.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          OnboardingCubit(profiles: context.read<ProfileRepository>()),
      child: BlocListener<OnboardingCubit, OnboardingState>(
        listenWhen: (p, c) => p.step != c.step,
        listener: (context, state) => context.read<Analytics>().log(
          AnalyticsEvents.onboardingStep,
          {'step': state.step.name},
        ),
        child: const OnboardingView(),
      ),
    );
  }
}

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  static const _titles = {
    OnboardingStep.username: 'Pick your anonymous name',
    OnboardingStep.interests: 'What do you like to read?',
    OnboardingStep.age: 'How old are you?',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (p, c) =>
          p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        final analytics = context.read<Analytics>();
        final notifications = context.read<NotificationService>();
        final profile = state.profile;
        if (state.status == SubmitStatus.success && profile != null) {
          analytics.log(AnalyticsEvents.signUp, {
            'age_range': profile.ageRange.name,
            'categories': profile.preferredCategoryIds.length,
          });
          notifications.requestPushPermission();
          context.read<SessionCubit>().onboardingCompleted(profile);
          showMessage(context, 'Welcome, ${profile.handle}.');
        }
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        final isFirst = state.step == OnboardingStep.username;
        final isLast = state.step == OnboardingStep.age;
        final busy =
            state.checkingUsername || state.status == SubmitStatus.submitting;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !isFirst) cubit.back();
          },
          child: Scaffold(
            body: SafeArea(
              child: ContentWidth(
                maxWidth: 600,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (!isFirst)
                          IconButton(
                            tooltip: 'Back',
                            onPressed: busy ? null : cubit.back,
                            icon: const Icon(Icons.arrow_back),
                          )
                        else
                          const SizedBox(width: 48, height: 48),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _Progress(
                            index: state.stepIndex,
                            count: state.stepCount,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${state.stepIndex + 1}/${state.stepCount}',
                          style: context.text.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _titles[state.step]!,
                      style: context.text.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.medium,
                        switchInCurve: AppMotion.curve,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(state.step),
                          child: switch (state.step) {
                            OnboardingStep.username => _UsernameStep(state),
                            OnboardingStep.interests => _InterestsStep(state),
                            OnboardingStep.age => _AgeStep(state),
                          },
                        ),
                      ),
                    ),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Semantics(
                          liveRegion: true,
                          child: NoteBox(
                            icon: Icons.error_outline,
                            tone: NoteTone.error,
                            child: Text(state.errorMessage!),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      key: const ValueKey('onboarding-continue'),
                      label: isLast ? 'Start reading' : 'Continue',
                      icon: isLast ? Icons.arrow_forward : null,
                      busy: busy,
                      onPressed: state.canContinue ? cubit.next : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () => context.read<SessionCubit>().signOut(),
                        child: Text(
                          'Use a different Google account',
                          style: context.text.labelMedium!.copyWith(
                            color: t.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.count});
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.medium,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= index ? t.ink : t.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            if (i < count - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// A large tappable option tile with a check mark when selected.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.onInk : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: selected ? t.ink : t.card,
          borderRadius: AppRadii.button,
          border: Border.all(color: selected ? t.ink : t.border, width: 1.2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.button,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md - 2,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(color: fg, size: 22),
                      child: leading!,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: context.text.titleMedium!.copyWith(color: fg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: context.text.bodySmall!.copyWith(
                              color: selected
                                  ? t.onInk.withValues(alpha: 0.8)
                                  : t.inkMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? t.onInk : t.border,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsernameStep extends StatelessWidget {
  const _UsernameStep(this.state);
  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    return ListView(
      children: [
        const NoteBox(
          icon: Icons.visibility_off_outlined,
          child: Text(
            'Stay anonymous. These names are randomly generated, so nobody can '
            'trace them back to you. Your Google name and email are never '
            'shown, and you can always post as plain "Anonymous".',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final name in state.usernameOptions) ...[
          ChoiceTile(
            key: ValueKey('username-$name'),
            title: '@$name',
            leading: const Icon(Icons.masks_outlined),
            selected: state.username == name,
            onTap: state.checkingUsername
                ? null
                : () => cubit.selectUsername(name),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Center(
          child: TextButton.icon(
            key: const ValueKey('shuffle-usernames'),
            onPressed: state.checkingUsername ? null : cubit.shuffleUsernames,
            icon: const Icon(Icons.shuffle, size: 18),
            label: const Text('Show me different names'),
          ),
        ),
      ],
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep(this.state);
  final OnboardingState state;

  static const _icons = {
    'relationships': Icons.favorite_border,
    'school': Icons.school_outlined,
    'workplace': Icons.work_outline,
    'friendship': Icons.people_outline,
    'family': Icons.home_outlined,
    'life': Icons.wb_twilight_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final categories = context.read<CategoryCatalog>().categories;
    return ListView(
      children: [
        Text(
          'Pick as many as you like. Your "For you" feed starts here, and you can '
          'change it later.',
          style: context.text.bodyMedium!.copyWith(
            color: context.tokens.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final c in categories) ...[
          ChoiceTile(
            key: ValueKey('interest-${c.id}'),
            title: c.name,
            subtitle: c.description,
            leading: Icon(_icons[c.id] ?? Icons.label_outline),
            selected: state.categoryIds.contains(c.id),
            onTap: () => cubit.toggleCategory(c.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _AgeStep extends StatelessWidget {
  const _AgeStep(this.state);
  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    return ListView(
      children: [
        Text(
          'We only keep your age range, never your birthday.',
          style: context.text.bodyMedium!.copyWith(
            color: context.tokens.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final range in AgeRange.values) ...[
          ChoiceTile(
            key: ValueKey('age-${range.name}'),
            title: range.label,
            subtitle: range.isMinor
                ? 'Mature confessions will be hidden for you.'
                : null,
            selected: state.ageRange == range,
            onTap: state.status == SubmitStatus.submitting
                ? null
                : () => cubit.selectAge(range),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
