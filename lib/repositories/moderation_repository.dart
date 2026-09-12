import '../models/report_model.dart';
import '../models/user_profile_model.dart';

/// Kept separate from the other repositories so the privileged write surface
/// is obvious at a glance - which matters when writing Security Rules.
abstract class ModerationRepository {
  Stream<List<ReportModel>> watchReports({ReportStatus? status});
  Future<void> submitReport(ReportModel report);

  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String adminId,
    String? note,
  });

  Stream<List<UserProfileModel>> watchUsers({String? query});
  Future<List<UserProfileModel>> fetchUsers();

  /// Blocking also hides the user's cart. Implemented inside both backends so
  /// local and Firebase behave identically.
  Future<void> setUserBlocked({
    required String userId,
    required bool isBlocked,
    required String adminId,
    String? reason,
  });
}
