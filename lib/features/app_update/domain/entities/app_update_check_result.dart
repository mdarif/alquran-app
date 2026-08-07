import 'package:equatable/equatable.dart';

import 'app_update_prompt.dart';

/// Outcome of an [AppUpdateRepository.check] call — always one of these three,
/// so a manual "Check for Updates" can render "available" / "up to date" /
/// "couldn't check" instead of collapsing the last two into a silent no-op.
enum AppUpdateCheckStatus { available, upToDate, error }

class AppUpdateCheckResult extends Equatable {
  const AppUpdateCheckResult.available(this.prompt)
      : status = AppUpdateCheckStatus.available,
        error = null;

  const AppUpdateCheckResult.upToDate()
      : status = AppUpdateCheckStatus.upToDate,
        prompt = null,
        error = null;

  const AppUpdateCheckResult.error(this.error)
      : status = AppUpdateCheckStatus.error,
        prompt = null;

  final AppUpdateCheckStatus status;
  final AppUpdatePrompt? prompt;
  final String? error;

  @override
  List<Object?> get props => [status, prompt, error];
}
