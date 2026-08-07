import '../entities/app_update_check_result.dart';

abstract interface class AppUpdateRepository {
  /// [ignoreDismissal]: a manual "Check for Updates" must always tell the
  /// truth — a prior "Later" tap must not make a real available update read
  /// as up to date. The passive/background check (Home, on launch/resume)
  /// leaves this false so a dismissed optional version stays quiet.
  Future<AppUpdateCheckResult> check({bool ignoreDismissal = false});
  Future<void> dismiss(String latestVersion);
}
