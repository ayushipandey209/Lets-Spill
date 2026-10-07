import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/router.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/share_service.dart';
import '../../../core/widgets/common.dart';
import '../../settings/presentation/settings_cubit.dart';
import '../domain/confession.dart';

/// Opens the reading screen and records where it was opened from.
void openConfession(
  BuildContext context,
  Confession confession, {
  required String source,
}) {
  context.read<Analytics>().log(AnalyticsEvents.confessionOpen, {
    'confession_id': confession.id,
    'category': confession.categoryId,
    'source': source,
  });
  Navigator.of(context).pushNamed(
    AppRoutes.confession,
    arguments: ConfessionRouteArgs(id: confession.id, initial: confession),
  );
}

/// Opens the platform share sheet with the confession text only.
Future<void> shareConfession(
  BuildContext context,
  Confession confession, {
  required String source,
  Rect? origin,
}) async {
  final analytics = context.read<Analytics>();
  try {
    await context.read<ShareService>().shareText(
      buildShareText(confession.text),
      subject: 'A confession from ${AppConfig.appName}',
      origin: origin ?? _originOf(context),
    );
    analytics.log(AnalyticsEvents.share, {
      'content_type': 'confession',
      'item_id': confession.id,
      'source': source,
    });
  } catch (_) {
    if (context.mounted) {
      showMessage(context, "Couldn't open the share sheet.", isError: true);
    }
  }
}

Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// A light tap feedback, if the reader has haptics turned on.
void tapFeedback(BuildContext context) {
  if (context.read<SettingsCubit>().state.haptics) {
    HapticFeedback.lightImpact();
  }
}
