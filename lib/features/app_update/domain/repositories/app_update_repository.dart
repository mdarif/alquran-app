import '../entities/app_update_prompt.dart';

abstract interface class AppUpdateRepository {
  Future<AppUpdatePrompt?> check();
  Future<void> dismiss(String latestVersion);
}
