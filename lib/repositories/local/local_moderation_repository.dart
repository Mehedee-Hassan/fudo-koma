import '../../core/id_generator.dart';
import '../../models/report_model.dart';
import '../../models/user_profile_model.dart';
import '../cart_repository.dart';
import '../moderation_repository.dart';
import 'local_keys.dart';
import 'local_store.dart';

class LocalModerationRepository implements ModerationRepository {
  LocalModerationRepository(this._store, this._carts);

  final LocalStore _store;
  final CartRepository _carts;

  @override
  Stream<List<ReportModel>> watchReports({ReportStatus? status}) =>
      _store.watchCollection(LocalKeys.reports).map((docs) {
        final reports = docs.entries
            .map((e) => ReportModel.fromMap(e.value, e.key))
            .where((r) => status == null || r.status == status)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return reports;
      });

  @override
  Future<void> submitReport(ReportModel report) async {
    final id = report.id.isEmpty ? newId('report') : report.id;
    await _store.setDoc(LocalKeys.reports, id, report.toMap());
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String adminId,
    String? note,
  }) =>
      _store.updateDoc(LocalKeys.reports, reportId, (current) {
        current['status'] = status.wire;
        current['resolvedBy'] = adminId;
        current['resolutionNote'] = note;
        current['resolvedAt'] =
            status.isClosed ? DateTime.now().toIso8601String() : null;
        return current;
      });

  @override
  Stream<List<UserProfileModel>> watchUsers({String? query}) =>
      _store.watchCollection(LocalKeys.users).map((docs) => _filter(docs, query));

  @override
  Future<List<UserProfileModel>> fetchUsers() async =>
      _filter(_store.readCollection(LocalKeys.users), null);

  List<UserProfileModel> _filter(
    Map<String, Map<String, dynamic>> docs,
    String? query,
  ) {
    final needle = query?.trim().toLowerCase() ?? '';
    final users = docs.entries
        // Strip the credential fields; they must never reach a screen.
        .map((e) => UserProfileModel.fromMap(e.value, e.key))
        .where((u) =>
            needle.isEmpty ||
            u.name.toLowerCase().contains(needle) ||
            u.email.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return users;
  }

  @override
  Future<void> setUserBlocked({
    required String userId,
    required bool isBlocked,
    required String adminId,
    String? reason,
  }) async {
    await _store.updateDoc(LocalKeys.users, userId, (current) {
      current['isBlocked'] = isBlocked;
      current['blockedAt'] =
          isBlocked ? DateTime.now().toIso8601String() : null;
      current['blockedBy'] = isBlocked ? adminId : null;
      current['blockedReason'] = isBlocked ? reason : null;
      return current;
    });

    // Cascade: a blocked owner's cart must not stay on the map. Implemented
    // inside the repository so both backends behave identically.
    final carts = await _carts.fetchCarts();
    for (final cart in carts) {
      if (cart.ownerId == userId && cart.isActive == isBlocked) {
        await _carts.setVisibility(cartId: cart.id, isActive: !isBlocked);
      }
    }
  }
}
