import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../../core/widgets/common.dart';
import '../../../auth/domain/auth_repository.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../profile/domain/profile_repository.dart';
import '../bloc/account_deletion_cubit.dart';

/// Explains exactly what is deleted, asks for confirmation, then confirms
/// with Google and deletes.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountDeletionCubit(
        auth: context.read<AuthRepository>(),
        profiles: context.read<ProfileRepository>(),
        confessions: context.read<ConfessionRepository>(),
      ),
      child: const _DeleteAccountView(),
    );
  }
}

class _DeleteAccountView extends StatelessWidget {
  const _DeleteAccountView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cubit = context.read<AccountDeletionCubit>();
    return BlocBuilder<AccountDeletionCubit, AccountDeletionState>(
      builder: (context, state) {
        final busy = state.status == SubmitStatus.submitting;
        return Scaffold(
          appBar: AppBar(title: const Text('Delete account')),
          body: ListView(
            padding: responsiveHorizontalPadding(
              context,
            ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.xxl),
            children: [
              Text(
                'This is permanent and cannot be undone.',
                style: context.text.bodyLarge!.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('What gets deleted', style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              const _Bullet('Your Let\'s Spill account (linked to Google).'),
              const _Bullet(
                'Your private profile: anonymous name, age range and reading '
                'preferences. Your anonymous name is released.',
              ),
              const _Bullet(
                'Confessions you posted, plus your likes, reactions, saves '
                'and views stored on this device.',
              ),
              const SizedBox(height: AppSpacing.md),
              Text('What may remain', style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              const _Bullet(
                'Reports you submitted, kept for moderation and safety '
                'records. They contain no name or email.',
              ),
              const _Bullet(
                'Your Google account itself — we only remove Let\'s Spill\'s '
                'access to it.',
              ),
              const SizedBox(height: AppSpacing.lg),
              CheckboxListTile(
                value: state.confirmed,
                onChanged: busy ? null : (v) => cubit.setConfirmed(v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'I understand my account and confessions will be '
                  'permanently deleted.',
                  style: context.text.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Google will ask you to confirm it's you.",
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.errorMessage != null) ...[
                NoteBox(
                  icon: Icons.error_outline,
                  tone: NoteTone.error,
                  child: Text(state.errorMessage!),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.error,
                    foregroundColor: t.onInk,
                  ),
                  onPressed: !state.confirmed || busy
                      ? null
                      : cubit.deleteAccount,
                  child: busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.onInk,
                          ),
                        )
                      : const Text('Permanently delete my account'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: AppSpacing.sm),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.tokens.ink,
                ),
              ),
            ),
          ),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
