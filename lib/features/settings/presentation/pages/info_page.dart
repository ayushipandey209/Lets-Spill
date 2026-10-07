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
        'What Let\'s Spill stores, in short:\n\n'
        '• Sign in: Google through Firebase Authentication. The app never '
        'sees or stores a password.\n'
        '• Your private profile (Cloud Firestore): your generated anonymous '
        'name, age range, reading interests and app settings. No real name, '
        'email, photo or birthday is stored in the database.\n'
        '• What you post: the confession text, its category, whether it is '
        'marked 18+, and the name it shows (Anonymous or your anonymous '
        'name). A private link between the post and your account lets you '
        'delete it; nobody else can see who wrote it.\n'
        '• What you do: your likes, reactions, saves and qualified reads, so '
        'counts stay accurate and your lists follow you between devices.\n'
        '• Reports you submit: the confession id, reason and optional '
        'details.\n'
        '• Usage analytics (Google Analytics for Firebase): which screens '
        'and features are used. Never what you write or search for, and '
        'never used for ads. You can turn it off in Settings.\n\n'
        'Your Google name and email are shown only in your own Settings. '
        'Deleting your account removes your profile, posts, likes, '
        'reactions, saves and reads.',
    link: config.privacyPolicyUrl,
    placeholderNote: config.privacyPolicyUrl == null
        ? 'Before launch: publish the full privacy policy and pass its URL '
              'with --dart-define=PRIVACY_POLICY_URL=https://your.site/privacy'
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
        ? 'Before launch: set a real support email or URL with '
              '--dart-define=SUPPORT_CONTACT=support@your.site'
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
