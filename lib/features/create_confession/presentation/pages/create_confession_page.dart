import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../../core/widgets/common.dart';
import '../../../auth/presentation/session_cubit.dart';
import '../../../categories/domain/category.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../confessions/presentation/confession_widgets.dart';
import '../bloc/create_confession_cubit.dart';

class CreateConfessionPage extends StatelessWidget {
  const CreateConfessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    return BlocProvider(
      create: (context) => CreateConfessionCubit(
        repository: context.read<ConfessionRepository>(),
        maxLength: config.maxConfessionLength,
        minLength: config.minConfessionLength,
        handle: context.read<SessionCubit>().state.profile?.handle,
      ),
      child: const CreateConfessionView(),
    );
  }
}

class CreateConfessionView extends StatefulWidget {
  const CreateConfessionView({super.key});

  @override
  State<CreateConfessionView> createState() => _CreateConfessionViewState();
}

class _CreateConfessionViewState extends State<CreateConfessionView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this confession?'),
        content: const Text("What you've written will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep writing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final categories = context.read<CategoryCatalog>();
    final t = context.tokens;

    return BlocConsumer<CreateConfessionCubit, CreateConfessionState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == SubmitStatus.success) {
          showMessage(context, 'Spilled. Your confession is live — anonymously.');
          Navigator.of(context).pop(state.created);
        }
      },
      builder: (context, state) {
        final cubit = context.read<CreateConfessionCubit>();
        final remaining = config.maxConfessionLength - state.length;
        final over = remaining < 0;
        return PopScope<Object?>(
          canPop: !state.hasDraft || state.status == SubmitStatus.success,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || state.isSubmitting) return;
            final navigator = Navigator.of(context);
            if (await _confirmDiscard() && mounted) navigator.pop();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: const Text('New confession'),
            ),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Text('Category', style: context.text.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final c in categories.categories)
                            SelectableCategoryChip(
                              key: ValueKey('create-${c.id}'),
                              label: c.name,
                              selected: state.categoryId == c.id,
                              onTap: state.isSubmitting
                                  ? null
                                  : () => cubit.categorySelected(c.id),
                            ),
                        ],
                      ),
                      if (state.categoryError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            state.categoryError!,
                            style: context.text.bodySmall!.copyWith(
                              color: t.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const ValueKey('confession-text'),
                        controller: _controller,
                        enabled: !state.isSubmitting,
                        onChanged: cubit.textChanged,
                        minLines: 8,
                        maxLines: 16,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: context.text.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'What have you never told anyone?',
                          alignLabelWithHint: true,
                          errorText: state.textError,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          over
                              ? '${Formatters.thousands(-remaining)} characters over the limit'
                              : '${Formatters.thousands(remaining)} characters left',
                          textAlign: TextAlign.right,
                          style: context.text.bodySmall!.copyWith(
                            color: over ? t.error : t.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Post as', style: context.text.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          SelectableCategoryChip(
                            key: const ValueKey('post-as-anonymous'),
                            label: 'Anonymous',
                            showCheck: true,
                            selected: !state.postAsHandle,
                            onTap: () => cubit.setPostAsHandle(false),
                          ),
                          if (cubit.handle != null)
                            SelectableCategoryChip(
                              key: const ValueKey('post-as-handle'),
                              label: cubit.handle!,
                              showCheck: true,
                              selected: state.postAsHandle,
                              onTap: () => cubit.setPostAsHandle(true),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      NoteBox(
                        icon: Icons.privacy_tip_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.postAsHandle && cubit.handle != null
                                  ? 'Posted as ${cubit.handle}'
                                  : 'Posted as Anonymous',
                              style: context.text.labelLarge,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            const Text(
                              "Your name and email are never shown. Don't post "
                              'addresses, phone numbers or other identifying '
                              'details, threats, harassment, or accusations '
                              'against people others could identify.',
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.guidelines),
                          child: const Text('Community guidelines'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FormErrorBanner(
                        message: state.status == SubmitStatus.failure
                            ? state.errorMessage
                            : null,
                      ),
                      PrimaryButton(
                        label: 'Spill it',
                        icon: Icons.send_outlined,
                        busy: state.isSubmitting,
                        onPressed: over ? null : cubit.submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Inline submission error with an icon (not colour alone).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: NoteBox(
          icon: Icons.error_outline,
          tone: NoteTone.error,
          child: Text(message!),
        ),
      ),
    );
  }
}
