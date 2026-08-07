import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_update_check_result.dart';
import '../../domain/repositories/app_update_repository.dart';
import 'app_update_state.dart';

/// Single source of truth for the app-update prompt, shared by the Home
/// banner and the Settings "Check for Updates" row so they don't each fetch
/// the remote config independently and can never disagree.
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit(this._repo) : super(const AppUpdateState.idle());

  final AppUpdateRepository _repo;

  Future<void> check() async {
    emit(state.checking);
    final result = await _repo.check();
    switch (result.status) {
      case AppUpdateCheckStatus.available:
        emit(state.available(result.prompt!));
      case AppUpdateCheckStatus.upToDate:
        emit(state.upToDate);
      case AppUpdateCheckStatus.error:
        emit(state.withError(result.error ?? 'Could not check for updates'));
    }
  }

  /// "Later" — only valid for an optional prompt; required updates can't be
  /// dismissed.
  Future<void> dismiss() async {
    final prompt = state.prompt;
    if (prompt == null || prompt.required) return;
    await _repo.dismiss(prompt.latestVersion);
    emit(const AppUpdateState.idle());
  }
}
