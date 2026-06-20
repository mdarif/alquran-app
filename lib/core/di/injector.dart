import 'package:get_it/get_it.dart';

import '../../features/navigation/data/repositories/index_repository_impl.dart';
import '../../features/navigation/domain/repositories/index_repository.dart';
import '../../features/navigation/presentation/cubit/index_list_cubit.dart';
import '../../features/reader/data/repositories/ayah_repository_impl.dart';
import '../../features/reader/domain/repositories/ayah_repository.dart';
import '../../features/reader/presentation/cubit/reader_cubit.dart';
import '../../features/surahs/data/repositories/surah_repository_impl.dart';
import '../../features/surahs/domain/repositories/surah_repository.dart';
import '../../features/surahs/presentation/cubit/surah_list_cubit.dart';
import '../database/app_database.dart';

final GetIt getIt = GetIt.instance;

/// Wires the object graph (PRD 7.1: DI via GetIt). Data → repositories →
/// cubits, with the single AppDatabase as the shared data source.
Future<void> configureDependencies() async {
  getIt
    // Data source
    ..registerSingleton<AppDatabase>(AppDatabase())
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
    // Cubits (new instance per screen)
    ..registerFactory<SurahListCubit>(
      () => SurahListCubit(getIt<SurahRepository>()),
    )
    ..registerFactory<ReaderCubit>(
      () => ReaderCubit(getIt<AyahRepository>()),
    )
    ..registerFactory<IndexListCubit>(
      () => IndexListCubit(getIt<IndexRepository>()),
    );
}
