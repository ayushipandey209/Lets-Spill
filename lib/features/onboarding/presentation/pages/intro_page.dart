import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/wordmark.dart';
import '../../../auth/domain/auth_repository.dart';

/// First screen for signed-out readers: a short swipeable intro and one
/// button, Continue with Google.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroSlide {
  const _IntroSlide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _IntroPageState extends State<IntroPage> {
  final _pages = PageController();
  int _index = 0;
  bool _signingIn = false;

  static const _slides = [
    _IntroSlide(
      Icons.auto_stories_outlined,
      'Read what people never say out loud.',
      'Relationships, school, work, friendships, family. Real stories, '
          'told anonymously.',
    ),
    _IntroSlide(
      Icons.edit_note_outlined,
      'Spill your own, without a trace.',
      'Post as Anonymous or as a random handle we generate for you. Your '
          'name and email are never shown.',
    ),
    _IntroSlide(
      Icons.favorite_border,
      'React, save, come back.',
      'Feel seen with a tap: Same, Hugs or Wow. Save the ones that stay '
          'with you.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    final analytics = context.read<Analytics>();
    try {
      await context.read<AuthRepository>().signInWithGoogle();
      analytics.log(AnalyticsEvents.login);
      // The session gate takes over from here.
    } on SignInCancelledException {
      // User closed the picker; nothing to report.
    } catch (e) {
      if (mounted) showMessage(context, asAppException(e).message, isError: true);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Wordmark(size: 34),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Your secrets. Their stories.',
                style: context.text.bodyMedium!.copyWith(color: t.inkMuted),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(
                    slide: _slides[i],
                    number: i + 1,
                    total: _slides.length,
                  ),
                ),
              ),
              _Dots(count: _slides.length, index: _index),
              const SizedBox(height: AppSpacing.lg),
              _GoogleButton(busy: _signingIn, onPressed: _signIn),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Next, you'll pick an anonymous name, what you like to read, "
                'and your age range. No typing needed.',
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.guidelines),
                  child: Text(
                    'Community guidelines',
                    style: context.text.labelMedium!.copyWith(
                      color: t.inkMuted,
                      decoration: TextDecoration.underline,
                      decorationColor: t.inkMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.number,
    required this.total,
  });

  final _IntroSlide slide;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: t.ink,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(slide.icon, color: t.onInk, size: 30),
              ),
              const SizedBox(height: AppSpacing.lg),
              Eyebrow(
                '${number.toString().padLeft(2, '0')} / '
                '${total.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(slide.title, style: context.text.displaySmall),
              const SizedBox(height: AppSpacing.md),
              Text(
                slide.body,
                style: context.text.bodyLarge!.copyWith(color: t.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              margin: const EdgeInsets.only(right: 6),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? t.ink : t.border,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: busy ? 'Signing in with Google' : 'Continue with Google',
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('google-sign-in'),
          onPressed: busy ? () {} : onPressed,
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.onInk,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.onInk,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        'G',
                        style: context.text.labelLarge!
                            .copyWith(color: t.ink)
                            .withWeight(800),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Flexible(
                      child: Text(
                        'Continue with Google',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
