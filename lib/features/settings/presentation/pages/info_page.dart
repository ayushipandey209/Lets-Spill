import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/common.dart';

/// Content for the Privacy / Support placeholder pages.
class InfoPageArgs {
  const InfoPageArgs({
    required this.title,
    required this.body,
    this.link,
    this.placeholderNote,
  });

  factory InfoPageArgs.privacy(AppConfig config) => InfoPageArgs(
    title: 'Privacy policy',
    body:
        'Summary of what this MVP stores:\n\n'
        '• Sign-in: Google via Firebase Authentication. The app never sees '
        'or stores a password.\n'
        '• Private profile (Cloud Firestore): your generated anonymous name, '
        'age range and reading preferences. No real name, email, photo or '
        'birthday is stored in the database.\n'
        '• On this device: your likes, reactions, saves, views and the '
        'confessions you post.\n'
        '• Reports you submit (confession id, reason, optional details).\n\n'
        'Your Google name and email are shown only on your private profile '
        'screen. You can delete your account from Settings.',
    link: config.privacyPolicyUrl,
    placeholderNote: config.privacyPolicyUrl == null
        ? 'PLACEHOLDER: publish a full privacy policy and pass its URL with '
              '--dart-define=PRIVACY_POLICY_URL=https://… before production.'
        : null,
  );

  factory InfoPageArgs.support(AppConfig config) => InfoPageArgs(
    title: 'Contact & report support',
    body:
        'To report a confession, open it and tap Report. For account help, '
        'legal requests, or urgent safety concerns about content, contact the '
        'support team.',
    link: config.supportContact,
    placeholderNote: config.supportContact == null
        ? 'PLACEHOLDER: set a real support email/URL with '
              '--dart-define=SUPPORT_CONTACT=… before production.'
        : null,
  );

  final String title;
  final String body;
  final String? link;
  final String? placeholderNote;
}

class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.args});

  final InfoPageArgs args;

  @override
  Widget build(BuildContext context) {
    final link = args.link;
    return Scaffold(
      appBar: AppBar(title: Text(args.title)),
      body: ListView(
        padding: responsiveHorizontalPadding(
          context,
        ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.xxl),
        children: [
          if (args.placeholderNote != null) ...[
            NoteBox(
              icon: Icons.construction_outlined,
              child: Text(args.placeholderNote!),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(args.body, style: context.text.bodyLarge),
          if (link != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SelectableText(link, style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Copy link',
              icon: Icons.copy,
              expand: false,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) showMessage(context, 'Copied.');
              },
            ),
          ],
        ],
      ),
    );
  }
}
