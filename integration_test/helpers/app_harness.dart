import 'package:al_quran/app.dart';
import 'package:al_quran/core/di/injector.dart';
import 'package:get_it/get_it.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the REAL app for an end-to-end scenario: the actual DI graph and the
/// bundled `quran.db` (114 surahs / 6236 verses), started from a clean
/// preferences store so each scenario is isolated (no carried-over Last Read,
/// font size, theme, or translation selection).
///
/// Call at the top of every [patrolTest]. It mirrors `lib/main.dart` but resets
/// GetIt + SharedPreferences first so tests don't depend on each other or on a
/// previous run's state.
Future<void> bootstrapApp(PatrolIntegrationTester $) async {
  await GetIt.instance.reset();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await configureDependencies();
  await $.pumpWidgetAndSettle(const AlQuranApp());
}
