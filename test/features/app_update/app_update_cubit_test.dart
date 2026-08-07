import 'package:al_quran/features/app_update/domain/entities/app_update_check_result.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_prompt.dart';
import 'package:al_quran/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:al_quran/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:al_quran/features/app_update/presentation/cubit/app_update_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements AppUpdateRepository {
  _FakeRepo(this.result);

  AppUpdateCheckResult result;
  String? dismissedVersion;
  bool? lastIgnoreDismissal;

  @override
  Future<AppUpdateCheckResult> check({bool ignoreDismissal = false}) async {
    lastIgnoreDismissal = ignoreDismissal;
    return result;
  }

  @override
  Future<void> dismiss(String latestVersion) async {
    dismissedVersion = latestVersion;
  }
}

AppUpdatePrompt _prompt({bool required = false}) => AppUpdatePrompt(
      currentVersion: '1.0.0',
      latestVersion: '1.2.2',
      storeUrl: Uri.parse('https://example.test'),
      message: 'A newer version is available.',
      required: required,
    );

void main() {
  group('AppUpdateCubit', () {
    test('check() moves idle -> checking -> available', () async {
      final cubit = AppUpdateCubit(
        _FakeRepo(AppUpdateCheckResult.available(_prompt())),
      );
      expect(cubit.state.phase, AppUpdatePhase.idle);

      final future = cubit.check();
      expect(cubit.state.phase, AppUpdatePhase.checking);
      await future;

      expect(cubit.state.phase, AppUpdatePhase.available);
      expect(cubit.state.prompt, isNotNull);
      await cubit.close();
    });

    test('check() surfaces up-to-date and error results distinctly',
        () async {
      final upToDate = AppUpdateCubit(
        _FakeRepo(const AppUpdateCheckResult.upToDate()),
      );
      await upToDate.check();
      expect(upToDate.state.phase, AppUpdatePhase.upToDate);
      await upToDate.close();

      final offline = AppUpdateCubit(
        _FakeRepo(const AppUpdateCheckResult.error('Network request failed')),
      );
      await offline.check();
      expect(offline.state.phase, AppUpdatePhase.error);
      expect(offline.state.error, 'Network request failed');
      await offline.close();
    });

    test('dismiss() clears an optional prompt and persists the version',
        () async {
      final repo = _FakeRepo(AppUpdateCheckResult.available(_prompt()));
      final cubit = AppUpdateCubit(repo);
      await cubit.check();

      await cubit.dismiss();

      expect(cubit.state.phase, AppUpdatePhase.idle);
      expect(repo.dismissedVersion, '1.2.2');
      await cubit.close();
    });

    test('dismiss() is a no-op for a required update', () async {
      final repo =
          _FakeRepo(AppUpdateCheckResult.available(_prompt(required: true)));
      final cubit = AppUpdateCubit(repo);
      await cubit.check();

      await cubit.dismiss();

      expect(cubit.state.phase, AppUpdatePhase.available);
      expect(cubit.state.prompt!.required, isTrue);
      expect(repo.dismissedVersion, isNull);
      await cubit.close();
    });

    test('the passive check() respects a prior dismissal', () async {
      final repo = _FakeRepo(AppUpdateCheckResult.available(_prompt()));
      final cubit = AppUpdateCubit(repo);

      await cubit.check();

      expect(repo.lastIgnoreDismissal, isFalse);
      await cubit.close();
    });

    test(
        'a manual check always tells the truth — it ignores a prior '
        '"Later" dismissal', () async {
      final repo = _FakeRepo(AppUpdateCheckResult.available(_prompt()));
      final cubit = AppUpdateCubit(repo);

      await cubit.checkManually();

      expect(repo.lastIgnoreDismissal, isTrue);
      expect(cubit.state.phase, AppUpdatePhase.available);
      await cubit.close();
    });

    test('one cubit instance is the single source of truth for two readers',
        () async {
      final repo = _FakeRepo(AppUpdateCheckResult.available(_prompt()));
      final cubit = AppUpdateCubit(repo);
      await cubit.check();

      // Simulate Home and Settings both reading the same shared instance
      // (as they do via GetIt) instead of holding independent state.
      final homeView = cubit.state;
      final settingsView = cubit.state;
      expect(homeView, same(settingsView));

      await cubit.dismiss();
      expect(cubit.state.phase, AppUpdatePhase.idle);
      await cubit.close();
    });
  });
}
