import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
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
import '../../features/reader/domain/entities/translation_resource.dart';
import '../../features/reader/presentation/cubit/ayah_audio_cubit.dart';
import '../../features/reader/presentation/cubit/reader_cubit.dart';
import '../../features/translations/data/repositories/edition_repository_impl.dart';
import '../../features/translations/domain/repositories/edition_repository.dart';
import '../../features/translations/presentation/cubit/translations_cubit.dart';
import '../../features/reminders/data/repositories/reminder_settings_repository_impl.dart';
import '../../features/reminders/data/scheduling/local_notification_scheduler.dart';
import '../../features/reminders/domain/repositories/reminder_settings_repository.dart';
import '../../features/reminders/domain/scheduling/notification_scheduler.dart';
import '../../features/reminders/presentation/cubit/reminders_cubit.dart';
import '../../features/surahs/data/repositories/surah_repository_impl.dart';
import '../../features/surahs/domain/repositories/surah_repository.dart';
import '../../features/surahs/presentation/cubit/surah_list_cubit.dart';
import '../audio/ayah_recitation_player.dart';
import '../database/app_database.dart';
import '../database/editions_database.dart';
import '../editions_config.dart';
import '../feature_flags.dart';
import '../database/db_seeder.dart';
import '../hijri/hijri_anchor_repository.dart';
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
  // Downloaded editions live in their OWN database, which the seeder above
  // never touches. Merging them into quran.db would destroy every download on
  // the next app update, silently. → EditionsDatabase
  final editionsFile = await editionsDatabaseFile();
  final supportDir = await getApplicationSupportDirectory();
  getIt
    // Data sources
    ..registerSingleton<AppDatabase>(AppDatabase(dbFile))
    ..registerSingleton<HijriAnchorRepository>(
      HijriAnchorRepository(getIt<AppDatabase>()),
    )
    ..registerSingleton<EditionsDatabase>(EditionsDatabase(editionsFile))
    ..registerSingleton<SharedPreferences>(prefs)
    // Repositories
    ..registerLazySingleton<SurahRepository>(
      () => SurahRepositoryImpl(getIt<AppDatabase>()),
    )
    ..registerLazySingleton<AyahRepository>(
      () => AyahRepositoryImpl(
        getIt<AppDatabase>(),
        getIt<ReaderSettingsRepository>(),
        getIt<EditionsDatabase>(),
      ),
    )
    ..registerLazySingleton<EditionRepository>(
      () => EditionRepositoryImpl(
        db: getIt<EditionsDatabase>(),
        supportDir: supportDir,
        catalogueUrl: Uri.parse(editionCatalogueUrl),
      ),
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
          // With prayer times gated off, "Light of Day" stays on but tracks the
          // clock rather than the user's real prayer boundaries (and we never
          // touch the location-backed repo).
          if (!FeatureFlags.prayerTimes) {
            return MushafPalette.phaseForHour(now.hour);
          }
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
          if (FeatureFlags.homeScreenWidgets) {
            getIt<WidgetPublisher>().publish();
          }
        },
      ),
    )
    ..registerLazySingleton<LastReadRepository>(
      () => LastReadRepositoryImpl(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ReaderSettingsRepository>(
      () => ReaderSettingsRepositoryImpl(getIt<SharedPreferences>()),
    )
    // Sunnah reminders: local notifications only. The scheduler is init'd in
    // main.dart (after timezone setup); the cubit is app-wide (Home + resume).
    ..registerLazySingleton<NotificationScheduler>(
      LocalNotificationScheduler.new,
    )
    ..registerLazySingleton<ReminderSettingsRepository>(
      () => ReminderSettingsRepositoryImpl(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<RemindersCubit>(
      () => RemindersCubit(
        getIt<ReminderSettingsRepository>(),
        getIt<NotificationScheduler>(),
      ),
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

  // Translations screen: an app-lifetime singleton (like RemindersCubit /
  // ThemeCubit) so it can be refreshed proactively at launch and carry a
  // "new edition available" signal even when the screen isn't open. The
  // bundled list is resolved once, here, so the registration below stays a
  // plain sync closure like every other lazy-singleton cubit.
  final bundledTranslations = await _bundledTranslations(getIt<AppDatabase>());
  getIt.registerLazySingleton<TranslationsCubit>(
    () => TranslationsCubit(
      getIt<EditionRepository>(),
      bundledTranslations,
      settings: getIt<ReaderSettingsRepository>(),
      prefs: getIt<SharedPreferences>(),
      onTranslationsChanged: () =>
          (getIt<AyahRepository>() as AyahRepositoryImpl)
              .invalidateTranslations(),
    ),
  );

  // Audio recitation. Registered UNCONDITIONALLY but LAZILY: the player (lazy
  // singleton) and cubit (factory) aren't constructed until the reader actually
  // reads them, which only happens behind FeatureFlags.audioRecitation. So while
  // the flag is off the just_audio plugin is still never touched and no network
  // runs — and because DI no longer depends on the flag, flipping it survives a
  // hot reload (gating DI on the flag crashed on reload: main/DI doesn't re-run,
  // so the reloaded UI saw flag=true but GetIt had no AyahAudioCubit).
  getIt
    ..registerLazySingleton<AyahRecitationPlayer>(JustAudioRecitationPlayer.new)
    ..registerFactory<AyahAudioCubit>(
      () => AyahAudioCubit(
        getIt<AyahRecitationPlayer>(),
        getIt<ReaderSettingsRepository>(),
      ),
    );

  // Best-effort: an older bundled DB without the anchor table, or any read
  // failure, just leaves the repository's in-memory list empty (raw tabular
  // dates), never blocks startup.
  await getIt<HijriAnchorRepository>().preload();
}

/// Editions compiled into the app (as opposed to downloaded ones), for
/// [TranslationsCubit]'s bundled/default-on filtering.
Future<List<TranslationResource>> _bundledTranslations(AppDatabase db) async {
  final rows = await db.translationResources();
  return [
    for (final r in rows)
      TranslationResource(
        id: r.id,
        slug: r.slug,
        languageCode: r.languageCode,
        name: r.name,
        nativeName: r.nativeName,
        author: r.author,
        direction: r.direction,
        sortOrder: r.sortOrder,
        defaultOn: r.defaultOn == 1,
        license: r.license,
        sourceUrl: r.sourceUrl,
      ),
  ];
}
