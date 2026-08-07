import 'package:equatable/equatable.dart';

import '../../domain/entities/app_update_prompt.dart';

enum AppUpdatePhase { idle, checking, available, upToDate, error }

class AppUpdateState extends Equatable {
  const AppUpdateState({
    this.phase = AppUpdatePhase.idle,
    this.prompt,
    this.error,
  });

  const AppUpdateState.idle() : this();

  final AppUpdatePhase phase;

  /// Only set when [phase] is [AppUpdatePhase.available].
  final AppUpdatePrompt? prompt;

  /// Only set when [phase] is [AppUpdatePhase.error].
  final String? error;

  AppUpdateState _copyWith({
    AppUpdatePhase? phase,
    AppUpdatePrompt? prompt,
    String? error,
  }) {
    return AppUpdateState(
      phase: phase ?? this.phase,
      prompt: prompt,
      error: error,
    );
  }

  AppUpdateState get checking => _copyWith(phase: AppUpdatePhase.checking);

  AppUpdateState available(AppUpdatePrompt prompt) => _copyWith(
        phase: AppUpdatePhase.available,
        prompt: prompt,
      );

  AppUpdateState get upToDate => _copyWith(phase: AppUpdatePhase.upToDate);

  AppUpdateState withError(String error) => _copyWith(
        phase: AppUpdatePhase.error,
        error: error,
      );

  @override
  List<Object?> get props => [phase, prompt, error];
}
