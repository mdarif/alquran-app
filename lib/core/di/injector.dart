import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/navigation/data/repositories/index_repository_impl.dart';
import '../../features/navigation/domain/repositories/index_repository.dart';
import '../../features/navigation/presentation/cubit/index_list_cubit.dart';
import '../../features/reader/data/repositories/ayah_repository_impl.dart';
import '../../features/reader/data/repositories/last_read_repository_impl.dart';
import '../../features/reader/data/repositories/reader_settings_repository_impl.dart';
import '../../features/reader/domain/repositories/ayah_repository.dart';
import '../../features/reader/domain/repositories/last_read_repository.dart';
import '../../features/reader/domain/repositories/reader_settings_repository.dart';
import '../../features/reader/presentation/cubit/reader_cubit.dart';
import '../../features/surahs/data/repositories/surah_repository_impl.dart';
import '../../features/surahs/domain/repositories/surah_repository.dart';
import '../../features/surahs/presentation/cubit/surah_list_cubit.dart';
import '../database/app_database.dart';
import '../database/db_seeder.dart';
import '../theme/theme_cubit.dart';

final GetIt getIt = GetIt.instance;

/// Wires the object graph (PRD 7.1: DI via GetIt). Data → repositories →
/// cubits, with the single AppDatabase as the shared data source.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  // Copy/refresh the bundled seed DB before opening it, so an updated quran.db
  // (corrections, new translations) replaces the stale on-device copy.
  final dbFile = await ensureSeedDatabase(prefs);
  getIt
    // Data sources
    ..registerSingleton<AppDatabase>(AppDatabase(dbFile))
    ..registerSingleton<SharedPreferences>(prefs)
    // Repositories
    ..registerLazySingleton<SurahRepository>(
      () => SurahRepositoryImpl(getIt<AppDatabase>()),
    )
    ..registerLazySingleton<AyahRepository>(
      () => AyahRepositoryImpl(getIt<AppDatabase>()),
    )
    ..registerLazySingleton<IndexRepository>(
      () => IndexRepositoryImpl(getIt<AppDatabase>()),
    )
    // App-wide theme (light default), persisted.
    ..registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<LastReadRepository>(
      () => LastReadRepositoryImpl(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ReaderSettingsRepository>(
      () => ReaderSettingsRepositoryImpl(getIt<SharedPreferences>()),
    )
    // Cubits (new instance per screen)
    ..registerFactory<SurahListCubit>(
      () => SurahListCubit(getIt<SurahRepository>()),
    )
    ..registerFactory<ReaderCubit>(
      () => ReaderCubit(getIt<AyahRepository>(), getIt<LastReadRepository>()),
    )
    ..registerFactory<IndexListCubit>(
      () => IndexListCubit(getIt<IndexRepository>()),
    );
}
