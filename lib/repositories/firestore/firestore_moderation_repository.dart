import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/report_model.dart';
import '../../models/user_profile_model.dart';
import '../cart_repository.dart';
import '../moderation_repository.dart';
import 'firestore_refs.dart';

class FirestoreModerationRepository implements ModerationRepository {
  FirestoreModerationRepository({
    required CartRepository carts,
    FirebaseFirestore? firestore,
  })  : _carts = carts,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final CartRepository _carts;

  @override
  Stream<List<ReportModel>> watchReports({ReportStatus? status}) {
    Query<Map<String, dynamic>> query =
        FirestoreRefs.reports(_db).orderBy('createdAt', descending: true);
    if (status != null) {
      query = FirestoreRefs.reports(_db).where('status', isEqualTo: status.wire);
    }
    return query.snapshots().map((snap) {
      final reports =
          snap.docs.map((d) => ReportModel.fromMap(d.data(), d.id)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }

  @override
  Future<void> submitReport(ReportModel report) =>
      FirestoreRefs.reports(_db)
          .doc(report.id.isEmpty ? null : report.id)
          .set(report.toMap());

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String adminId,
    String? note,
  }) =>
      FirestoreRefs.reports(_db).doc(reportId).update(<String, dynamic>{
        'status': status.wire,
        'resolvedBy': adminId,
        'resolutionNote': note,
        'resolvedAt': status.isClosed ? DateTime.now().toIso8601String() : null,
      });

  @override
  Stream<List<UserProfileModel>> watchUsers({String? query}) {
    final needle = query?.trim().toLowerCase() ?? '';
    return FirestoreRefs.users(_db).snapshots().map((snap) {
      final users = snap.docs
          .map((d) => UserProfileModel.fromMap(d.data(), d.id))
          .where((u) =>
              needle.isEmpty ||
              u.name.toLowerCase().contains(needle) ||
              u.email.toLowerCase().contains(needle))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return users;
    });
  }

  @override
  Future<List<UserProfileModel>> fetchUsers() async {
    final snap = await FirestoreRefs.users(_db).get();
    return snap.docs
        .map((d) => UserProfileModel.fromMap(d.data(), d.id))
        .toList();
  }

  @override
  Future<void> setUserBlocked({
    required String userId,
    required bool isBlocked,
    required String adminId,
    String? reason,
  }) async {
    await FirestoreRefs.users(_db).doc(userId).update(<String, dynamic>{
      'isBlocked': isBlocked,
      'blockedAt': isBlocked ? DateTime.now().toIso8601String() : null,
      'blockedBy': isBlocked ? adminId : null,
      'blockedReason': isBlocked ? reason : null,
    });

    // Same cascade as local mode: a blocked owner's cart leaves the map.
    final snap = await FirestoreRefs.carts(_db)
        .where('ownerId', isEqualTo: userId)
        .get();
    for (final doc in snap.docs) {
      await _carts.setVisibility(cartId: doc.id, isActive: !isBlocked);
    }
  }
}
