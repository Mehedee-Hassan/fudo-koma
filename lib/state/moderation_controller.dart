import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/id_generator.dart';
import '../models/report_model.dart';
import '../models/user_profile_model.dart';
import '../models/user_role.dart';
import '../repositories/moderation_repository.dart';

class ModerationController extends ChangeNotifier {
  ModerationController(this._repository);

  final ModerationRepository _repository;
  StreamSubscription<List<ReportModel>>? _reportSub;
  StreamSubscription<List<UserProfileModel>>? _userSub;

  String? _adminId;
  List<ReportModel> _reports = const <ReportModel>[];
  List<UserProfileModel> _users = const <UserProfileModel>[];
  String _userQuery = '';
  bool _busy = false;
  String? _error;

  List<ReportModel> get reports => _reports;
  List<ReportModel> get openReports =>
      _reports.where((r) => !r.status.isClosed).toList();
  List<UserProfileModel> get users => _users;
  String get userQuery => _userQuery;
  bool get busy => _busy;
  String? get error => _error;

  int get blockedUserCount => _users.where((u) => u.isBlocked).length;
  int get adminCount =>
      _users.where((u) => u.role == UserRole.admin && !u.isBlocked).length;

  /// Reporting is available to any signed-in user; only the admin console binds
  /// the moderation streams.
  void bindAdmin(String? adminId, {required bool isAdmin}) {
    if (_adminId == adminId) return;
    _adminId = adminId;

    _reportSub?.cancel();
    _userSub?.cancel();
    _reportSub = null;
    _userSub = null;

    if (adminId == null || !isAdmin) {
      _reports = const <ReportModel>[];
      _users = const <UserProfileModel>[];
      notifyListeners();
      return;
    }

    _reportSub = _repository.watchReports().listen((reports) {
      _reports = reports;
      notifyListeners();
    });
    _userSub = _repository.watchUsers().listen((users) {
      _users = users;
      notifyListeners();
    });
  }

  void setUserQuery(String value) {
    if (_userQuery == value) return;
    _userQuery = value;
    notifyListeners();
  }

  List<UserProfileModel> get visibleUsers {
    final needle = _userQuery.trim().toLowerCase();
    if (needle.isEmpty) return _users;
    return _users
        .where((u) =>
            u.name.toLowerCase().contains(needle) ||
            u.email.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required String targetName,
    required String reporterId,
    required String reporterName,
    required ReportReason reason,
    String note = '',
  }) =>
      _run(() => _repository.submitReport(ReportModel(
            id: newId('report'),
            targetType: targetType,
            targetId: targetId,
            targetName: targetName,
            reporterId: reporterId,
            reporterName: reporterName,
            reason: reason,
            note: note,
            createdAt: DateTime.now(),
          )));

  Future<void> resolveReport({
    required String reportId,
    required ReportStatus status,
    String? note,
  }) {
    final adminId = _adminId;
    if (adminId == null) return Future<void>.value();
    return _run(() => _repository.updateReportStatus(
          reportId: reportId,
          status: status,
          adminId: adminId,
          note: note,
        ));
  }

  /// Returns null on success, or a reason the action was refused.
  Future<String?> setBlocked({
    required UserProfileModel user,
    required bool isBlocked,
    String? reason,
  }) async {
    final adminId = _adminId;
    if (adminId == null) return 'You are not signed in as an admin.';

    if (isBlocked && user.id == adminId) {
      return 'You cannot block your own account.';
    }
    if (isBlocked && user.role == UserRole.admin && adminCount <= 1) {
      return 'This is the last active admin. Promote another admin first.';
    }

    await _run(() => _repository.setUserBlocked(
          userId: user.id,
          isBlocked: isBlocked,
          adminId: adminId,
          reason: reason,
        ));
    return _error;
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _reportSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
