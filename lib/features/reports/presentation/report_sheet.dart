import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/ui_notice.dart';
import '../../../core/widgets/common.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';
import 'report_cubit.dart';

/// Opens the report sheet. Resolves to `true` when a report was submitted.
Future<bool?> showReportSheet(
  BuildContext context, {
  required String confessionId,
}) {
  final repository = context.read<ReportRepository>();
  final config = context.read<AppConfig>();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => ReportCubit(
        repository: repository,
        confessionId: confessionId,
        maxDetailsLength: config.maxReportDetailsLength,
      ),
      child: const _ReportSheet(),
    ),
  );
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxLen = context.read<ReportCubit>().maxDetailsLength;
    return BlocConsumer<ReportCubit, ReportState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == SubmitStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ReportCubit>();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report confession', style: context.text.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reports are private. The author is not told who reported. '
                    'If someone is in immediate danger, contact local '
                    'emergency services.',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  RadioGroup<ReportReason>(
                    groupValue: state.reason,
                    onChanged: (r) {
                      if (r != null) cubit.reasonSelected(r);
                    },
                    child: Column(
                      children: [
                        for (final reason in ReportReason.values)
                          RadioListTile<ReportReason>(
                            value: reason,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              reason.label,
                              style: context.text.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    minLines: 2,
                    maxLines: 4,
                    maxLength: maxLen,
                    onChanged: cubit.detailsChanged,
                    decoration: const InputDecoration(
                      labelText: 'Details (optional)',
                      hintText: 'Anything that helps moderators understand.',
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      state.errorMessage!,
                      style: context.text.bodySmall!.copyWith(color: t.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Submit report',
                    busy: state.status == SubmitStatus.submitting,
                    onPressed: state.reason == null ? null : cubit.submit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
