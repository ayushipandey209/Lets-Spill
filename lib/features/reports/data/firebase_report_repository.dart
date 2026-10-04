import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/data/firebase/firebase_error_mapper.dart';
import '../../../core/data/firebase/firestore_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';

/// Writes to the `reports` collection. Clients can create a report and read
/// back only their own; reviewing/updating is reserved for trusted tooling.
class FirebaseReportRepository implements ReportRepository {
  FirebaseReportRepository({
    required fb.FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _db = firestore;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException('Please sign in to continue.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _ref(String confessionId, String uid) =>
      _db
          .collection(FirestorePaths.reports)
          .doc(FirestorePaths.reportId(confessionId, uid));

  @override
  Future<bool> hasReported(String confessionId) {
    return guardFirebase(() async {
      final snap = await _ref(confessionId, _requireUid()).get();
      return snap.exists;
    });
  }

  @override
  Future<void> submit({
    required String confessionId,
    required ReportReason reason,
    String details = '',
  }) async {
    if (await hasReported(confessionId)) {
      throw const ValidationException(
        "You've already reported this confession. Thanks — it's in the queue.",
      );
    }
    await guardFirebase(() async {
      final uid = _requireUid();
      await _ref(confessionId, uid).set({
        'confessionId': confessionId,
        'reporterUid': uid,
        'reason': reason.name,
        'details': details.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'reviewStatus': 'open',
      });
    });
  }
}
