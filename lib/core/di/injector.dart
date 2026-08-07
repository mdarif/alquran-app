import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/navigation/data/repositories/index_repository_impl.dart';
import '../../features/navigation/domain/repositories/index_repository.dart';
import '../../features/navigation/presentation/cubit/index_list_cubit.dart';
import '../../features/app_update/data/repositories/app_update_repository_impl.dart';
import '../../features/app_update/domain/repositories/app_update_repository.dart';
import '../../features/app_update/presentation/cubit/app_update_cubit.dart';
import '../../features/prayer_times/data/location/geolocator_location_provider.dart';
import '../../features/prayer_times/data/repositories/prayer_notification_settings_repository_impl.dart';
import '../../features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import '../../features/prayer_times/domain/repositories/prayer_notification_settings_repository.dart';
import '../../features/prayer_times/domain/repositories/prayer_times_repository.dart';
import '../../features/prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import '../../features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import '../../features/reader/data/repositories/ayah_repository_impl.dart';
import '../../features/reader/data/repositories/ayah_bookmark_repository_impl.dart';
import '../../features/reader/data/repositories/last_read_repository_impl.dart';
import '../../features/reader/data/repositories/reader_settings_repository_impl.dart';
import '../../features/reader/domain/repositories/ayah_repository.dart';
import '../../features/reader/domain/repositories/ayah_bookmark_repository.dart';
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
import '../../features/tafsir/data/repositories/tafsir_repository_impl.dart';
import '../../features/tafsir/domain/repositories/tafsir_repository.dart';
import '../../features/tafsir/presentation/cubit/tafsir_cubit.dart';
import '../audio/ayah_recitation_player.dart';
import '../app_update_config.dart';
import '../database/app_database.dart';
import '../database/editions_database.dart';
import '../database/tafsir_database.dart';
import '../editions_config.dart';
import '../feature_flags.dart';
import '../database/db_seeder.dart';
import '../hijri/hijri_anchor_repository.dart';
import '../home_widget/widget_bridge.dart';
import '../tafsir_config.dart';
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
  final tafsirFile = await tafsirDatabaseFile();
  final supportDir = await getApplicationSupportDirectory();
  getIt
    // Data sources
    ..registerSingleton<AppDatabase>(AppDatabase(dbFile))
    ..registerSingleton<HijriAnchorRepository>(
      HijriAnchorRepository(getIt<AppDatabase>()),
    )
    ..registerSingleton<EditionsDatabase>(EditionsDatabase(editionsFile))
    ..registerSingleton<TafsirDatabase>(TafsirDatabase(tafsirFile))
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
    ..registerLazySingleton<TafsirRepository>(
      () => TafsirRepositoryImpl(
        db: getIt<TafsirDatabase>(),
        supportDir: supportDir,
        catalogueUrl: Uri.parse(tafsirCatalogueUrl),
      ),
    )
    ..registerLazySingleton<IndexRepository>(
      () => IndexRepositoryImpl(getIt<AppDatabase>()),
    )
    ..registerLazySingleton<AppUpdateRepository>(
      () => AppUpdateRepositoryImpl(
        prefs: getIt<SharedPreferences>(),
        configUrl: Uri.parse(appUpdateConfigUrl),
      ),
    )
    ..registerLazySingleton<AppUpdateCubit>(
      () => AppUpdateCubit(getIt<AppUpdateRepository>()),
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
          // No schedule for this day (polar latitude) → "Light of Day" tracks
          // the clock instead of prayer boundaries, exactly as it does before
          // a location is set.
          if (t == null) return MushafPalette.phaseForHour(now.hour);
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
    ..registerLazySingleton<AyahBookmarkRepository>(
      () => AyahBookmarkRepositoryImpl(
        getIt<SharedPreferences>(),
        getIt<AppDatabase>(),
      ),
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
    ..registerLazySingleton<PrayerNotificationSettingsRepository>(
      () => PrayerNotificationSettingsRepositoryImpl(
        getIt<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<PrayerNotificationsCubit>(
      () => PrayerNotificationsCubit(
        getIt<PrayerNotificationSettingsRepository>(),
        getIt<NotificationScheduler>(),
        getIt<PrayerTimesRepository>(),
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
  final bundled = await bundledTranslations(getIt<AppDatabase>());
  getIt.registerLazySingleton<TranslationsCubit>(
    () => TranslationsCubit(
      getIt<EditionRepository>(),
      bundled,
      settings: getIt<ReaderSettingsRepository>(),
      prefs: getIt<SharedPreferences>(),
      onTranslationsChanged: () =>
          (getIt<AyahRepository>() as AyahRepositoryImpl)
              .invalidateTranslations(),
    ),
  );

  getIt.registerLazySingleton<TafsirCubit>(
    () => TafsirCubit(
      getIt<TafsirRepository>(),
      prefs: getIt<SharedPreferences>(),
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
///
/// `resources` in quran.db carries a metadata row for EVERY edition
/// (including downloadable-only ones like hi-ahsanul-kalam/ur-roman-abu-rayyan
/// — needed so the picker/search can describe them before they're ever
/// downloaded), but only `default_on` rows are actually meant to be treated
/// as bundled here. Filtered to match AyahRepositoryImpl's own
/// `r.defaultOn == 1` bundled filter — without this, a downloadable edition
/// would be permanently claimed as "bundled" in the picker (no
/// install/remove lifecycle, and its `editions.installed()` row — with the
/// fresher creditName/experimental/author — would never be consulted).
///
/// Public (not `_`-prefixed) and [visibleForTesting] specifically so this
/// filter has a regression test — see
/// test/core/di/injector_bundled_translations_test.dart.
@visibleForTesting
Future<List<TranslationResource>> bundledTranslations(AppDatabase db) async {
  final rows = await db.translationResources();
  return [
    for (final r in rows)
      if (r.defaultOn == 1)
        TranslationResource(
          id: r.id,
          slug: r.slug,
          languageCode: r.languageCode,
          name: r.name,
          nativeName: r.nativeName,
          author: r.author,
          direction: r.direction,
          sortOrder: r.sortOrder,
          defaultOn: true,
          license: r.license,
          sourceUrl: r.sourceUrl,
          creditName: r.creditName,
          experimental: r.experimental == 1,
        ),
  ];
}
