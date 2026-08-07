import '../entities/app_update_check_result.dart';

abstract interface class AppUpdateRepository {
  Future<AppUpdateCheckResult> check();
  Future<void> dismiss(String latestVersion);
}
