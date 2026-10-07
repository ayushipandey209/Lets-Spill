import 'report.dart';

/// Moderation hook: readers flag content; review happens out-of-band
/// (Firebase Console or a trusted admin tool, never from this client).
abstract interface class ReportRepository {
  /// Submits a report. One report per user per confession; a repeat report
  /// throws a `ValidationException` explaining it was already received.
  Future<void> submit({
    required String confessionId,
    required ReportReason reason,
    String details = '',
  });

  /// Whether the signed-in user already reported [confessionId].
  Future<bool> hasReported(String confessionId);
}
