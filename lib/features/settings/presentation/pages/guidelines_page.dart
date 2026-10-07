import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/common.dart';

/// Community guidelines. Have the copy reviewed before launch.
class GuidelinesPage extends StatelessWidget {
  const GuidelinesPage({super.key});

  static const _sections = <(String, String)>[
    (
      'Anonymous doesn’t mean anything goes',
      'Your name never appears on what you post, but you are still responsible '
          'for it. Posts that break these guidelines are removed, and accounts '
          'that repeatedly do so can be suspended.',
    ),
    (
      'Tell your story, not someone else’s identity',
      'Don’t name or identify real people, schools, workplaces or companies '
          'in a way that lets others work out who they are. Change details. '
          'Never post addresses, phone numbers, social handles, photos or other '
          'personal information, yours or anyone else’s.',
    ),
    (
      'No harassment, threats or hate',
      'No bullying, intimidation, threats of violence, hate speech or content '
          'that encourages self-harm. No sexual content involving minors, '
          'ever.',
    ),
    (
      'Confessions are not verified facts',
      'Everything here is a personal, unverified account. Don’t post '
          'accusations against people others could identify, and don’t treat '
          'what you read as established fact.',
    ),
    (
      'Report, don’t retaliate',
      'If something crosses a line, use Report on the confession. Reports are '
          'private and reviewed by moderators.',
    ),
    (
      'If you or someone else is in danger',
      'Let’s Spill is not an emergency or crisis service. If anyone is at '
          'immediate risk, contact local emergency services or a crisis line '
          'in your country.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community guidelines')),
      body: ListView(
        padding: responsiveHorizontalPadding(
          context,
        ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.xxl),
        children: [
          Text(
            'A confession journal works only if it feels safe. These rules '
            'keep it that way.',
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _sections.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    (i + 1).toString().padLeft(2, '0'),
                    style: context.text.labelLarge!.copyWith(
                      color: context.tokens.inkMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_sections[i].$1, style: context.text.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(_sections[i].$2, style: context.text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const HairlineDivider(),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'Thanks for keeping Let’s Spill kind.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
