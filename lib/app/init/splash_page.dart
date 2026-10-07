import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/widgets/common.dart';
import '../theme/app_tokens.dart';
import 'app_init_cubit.dart';

/// Typographic splash with loading, and an error/retry state that explains
/// how to finish Firebase setup when that's what's missing.
///
/// Rendered *outside* the Navigator during start-up, so it must not rely on
/// routes, overlays or tooltips.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.state});

  final AppInitState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final failed = state.status == AppInitStatus.failure;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/splash_logo.png',
                      width: 210,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedSwitcher(
                      duration: AppMotion.medium,
                      child: failed
                          ? _InitError(state: state)
                          : Semantics(
                              label: 'Loading',
                              child: SizedBox(
                                key: const ValueKey('loading'),
                                width: 100,
                                child: LinearProgressIndicator(
                                  minHeight: 2.5,
                                  backgroundColor:
                                      t.border.withValues(alpha: 0.35),
                                  color: t.ink,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InitError extends StatelessWidget {
  const _InitError({required this.state});

  final AppInitState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final steps = state.setupSteps;
    return Column(
      key: const ValueKey('error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteBox(
          icon: Icons.error_outline,
          tone: NoteTone.error,
          child: Text(state.errorMessage ?? 'Something went wrong.'),
        ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Finish Firebase setup', style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}.', style: context.text.labelMedium),
                  ),
                  Expanded(
                    child: Text(steps[i], style: context.text.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Full guide: docs/FIREBASE_SETUP.md.',
            style: context.text.bodySmall!.copyWith(color: t.inkMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Try again',
          icon: Icons.refresh,
          expand: false,
          onPressed: () => context.read<AppInitCubit>().initialize(),
        ),
      ],
    );
  }
}
