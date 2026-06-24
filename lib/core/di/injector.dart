import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/navigation/data/repositories/index_repository_impl.dart';
import '../../features/navigation/domain/repositories/index_repository.dart';
import '../../features/navigation/presentation/cubit/index_list_cubit.dart';
import '../../features/prayer_times/data/location/geolocator_location_provider.dart';
import '../../features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import '../../features/prayer_times/domain/repositories/prayer_times_repository.dart';
import '../../features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
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
import '../home_widget/widget_bridge.dart';
import '../home_widget/widget_publisher.dart';
import '../theme/mushaf_palette.dart';
import '../theme/prayer_phase.dart';
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
    // Prayer times: location (geolocator) + on-device adhan calc. Registered
    // before ThemeCubit since its resolver reads this repo.
    ..registerLazySingleton<PrayerTimesRepository>(
      () => PrayerTimesRepositoryImpl(
        getIt<SharedPreferences>(),
        const GeolocatorLocationProvider(),
      ),
    )
    // Home-screen widget bridge: the pure WidgetBridge serialises the schedule;
    // the publisher pushes it to the OS widget. Best-effort, never throws.
    ..registerLazySingleton<WidgetPublisher>(
      () => WidgetPublisher(
        WidgetBridge(getIt<PrayerTimesRepository>()),
        const PluginHomeWidgetClient(),
      ),
    )
    // App-wide theme. "Light of Day" auto-phase snaps to the user's real prayer
    // times when a location is set, falling back to clock hours otherwise.
    ..registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(
        getIt<SharedPreferences>(),
        phaseResolver: (now) {
          final repo = getIt<PrayerTimesRepository>();
          final loc = repo.location;
          if (loc == null) return MushafPalette.phaseForHour(now.hour);
          final t = repo.timesFor(loc, now);
          return phaseForBoundaries(
            fajr: t.fajr,
            sunrise: t.sunrise,
            asr: t.asr,
            maghrib: t.maghrib,
            isha: t.isha,
            now: now,
          );
        },
      ),
    )
    // App-wide prayer-times cubit (shown in both app bars). On a fresh location
    // fix it nudges the theme to re-resolve to the prayer-based phase.
    ..registerLazySingleton<PrayerTimesCubit>(
      () => PrayerTimesCubit(
        getIt<PrayerTimesRepository>(),
        onLocationFixed: () {
          getIt<ThemeCubit>().refresh();
          getIt<WidgetPublisher>().publish();
        },
      ),
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
