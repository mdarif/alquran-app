import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/translations/domain/entities/catalogue_entry.dart';
import 'package:al_quran/features/translations/domain/entities/installed_edition.dart';
import 'package:al_quran/features/translations/domain/repositories/edition_repository.dart';
import 'package:al_quran/features/translations/presentation/cubit/translations_cubit.dart';
import 'package:al_quran/features/translations/presentation/pages/translations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements EditionRepository {
  _FakeRepo({
    this.available = const [],
    this.local = const [],
    this.catalogueThrows = false,
    this.installThrows,
  });

  List<CatalogueEntry> available;
  List<InstalledEdition> local;
  bool catalogueThrows;
  Exception? installThrows;
  final List<String> installCalls = [];
  final List<String> removeCalls = [];

  @override
  Future<EditionCatalogue> catalogue() async {
    if (catalogueThrows) {
      throw const EditionDownloadException('offline');
    }
    return EditionCatalogue(editions: available);
  }

  @override
  Future<List<InstalledEdition>> installed() async => local;

  @override
  Future<void> install(
    CatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {
    installCalls.add(entry.slug);
    if (installThrows != null) throw installThrows!;
    onProgress?.call(1);
    local = [
      for (final e in local)
        if (e.slug != entry.slug) e,
      InstalledEdition(
        slug: entry.slug,
        type: entry.type,
        languageCode: entry.languageCode,
        name: entry.name,
        author: entry.author,
        bytes: entry.uncompressedBytes,
        sha256: entry.sha256,
        installedAt: DateTime(2026),
      ),
    ];
  }

  @override
  Future<void> remove(String slug) async {
    removeCalls.add(slug);
    local = [
      for (final e in local)
        if (e.slug != slug) e,
    ];
  }
}

class _FakeSettings implements ReaderSettingsRepository {
  _FakeSettings({this.selectedTranslations});

  @override
  List<String>? selectedTranslations;

  @override
  Future<void> setSelectedTranslations(List<String> slugs) async {
    selectedTranslations = slugs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CatalogueEntry _entry(String slug, String lang, String name) => CatalogueEntry(
      slug: slug,
      type: 'translation',
      languageCode: lang,
      name: name,
      file: '$slug.db.gz',
      bytes: 1024,
      sha256: 'x',
      uncompressedBytes: 4096,
      uncompressedSha256: 'y',
      ayahCount: 6236,
    );

const _bundledUrdu = TranslationResource(
  id: 1,
  slug: 'ur-junagarhi',
  languageCode: 'ur',
  name: 'Junagarhi',
  defaultOn: true,
);

void main() {
  Future<void> pumpTranslationsPage(
    WidgetTester tester,
    TranslationsCubit cubit,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: BlocProvider.value(
          value: cubit,
          child: const TranslationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('bundled editions are listed but offer no action', () async {
    final cubit = TranslationsCubit(_FakeRepo(), const [_bundledUrdu]);
    await cubit.load();

    final item = cubit.state.items.single;
    expect(item.slug, 'ur-junagarhi');
    // Bundled: there is no download to undo, and removing it would leave the
    // reader with nothing.
    expect(item.state, EditionState.bundled);
    expect(item.selected, isTrue);
  });

  test('a default bundled edition is not offered again for download', () async {
    final repo = _FakeRepo(
      available: [_entry('ur-junagarhi', 'ur', 'Junagarhi')],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu]);
    await cubit.load();

    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.items.single.state, EditionState.bundled);
    expect(cubit.state.items.single.bytes, 1024);
  });

  test('a non-default bundled edition remains available for CDN install',
      () async {
    const bundledHindi = TranslationResource(
      id: 2,
      slug: 'hi-suhel-farooq-nadwi',
      languageCode: 'hi',
      name: 'Suhel Farooq Khan',
      defaultOn: false,
    );
    final repo = _FakeRepo(
      available: [_entry('hi-suhel-farooq-nadwi', 'hi', 'Suhel Farooq Khan')],
    );
    final cubit = TranslationsCubit(
      repo,
      const [_bundledUrdu, bundledHindi],
    );
    await cubit.load();

    expect(cubit.state.downloaded.map((i) => i.slug), ['ur-junagarhi']);
    expect(cubit.state.available.single.slug, 'hi-suhel-farooq-nadwi');
  });

  test('two editions of one language are both listed under it', () async {
    final repo = _FakeRepo(
      available: [
        _entry('hi-suhel-farooq-nadwi', 'hi', 'Suhel Farooq Khan'),
        _entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam'),
      ],
    );
    final cubit = TranslationsCubit(repo, const []);
    await cubit.load();

    expect(cubit.state.byLanguage['hi'], hasLength(2));
  });

  test('installing moves an edition from available to installed', () async {
    final repo = _FakeRepo(
      available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
    );
    final cubit = TranslationsCubit(repo, const []);
    await cubit.load();
    expect(cubit.state.items.single.state, EditionState.available);

    await cubit.install('hi-ahsanul-kalam');

    expect(repo.installCalls, ['hi-ahsanul-kalam']);
    expect(cubit.state.items.single.state, EditionState.installed);
  });

  test('installing selects the edition for the reader and refreshes caches',
      () async {
    final repo = _FakeRepo(
      available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
    );
    final settings = _FakeSettings(selectedTranslations: ['ur-junagarhi']);
    var invalidations = 0;
    final cubit = TranslationsCubit(
      repo,
      const [_bundledUrdu],
      settings: settings,
      onTranslationsChanged: () => invalidations += 1,
    );
    await cubit.load();

    await cubit.install('hi-ahsanul-kalam');

    expect(settings.selectedTranslations, [
      'ur-junagarhi',
      'hi-ahsanul-kalam',
    ]);
    expect(invalidations, 1);
  });

  test('installing with no saved choice preserves default Urdu too', () async {
    final repo = _FakeRepo(
      available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
    );
    final settings = _FakeSettings();
    final cubit = TranslationsCubit(
      repo,
      const [_bundledUrdu],
      settings: settings,
    );
    await cubit.load();

    await cubit.install('hi-ahsanul-kalam');

    expect(settings.selectedTranslations, [
      'ur-junagarhi',
      'hi-ahsanul-kalam',
    ]);
  });

  test('toggling a downloaded edition hides it without uninstalling', () async {
    final repo = _FakeRepo(
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final settings = _FakeSettings(
      selectedTranslations: ['ur-junagarhi', 'hi-ahsanul-kalam'],
    );
    var invalidations = 0;
    final cubit = TranslationsCubit(
      repo,
      const [_bundledUrdu],
      settings: settings,
      onTranslationsChanged: () => invalidations += 1,
    );
    await cubit.load();

    await cubit.toggleSelected('hi-ahsanul-kalam');

    expect(settings.selectedTranslations, ['ur-junagarhi']);
    expect(repo.removeCalls, isEmpty);
    expect(
      cubit.state.items
          .singleWhere((i) => i.slug == 'hi-ahsanul-kalam')
          .selected,
      isFalse,
    );
    expect(invalidations, 1);
  });

  test('Ahsanul Kalam author metadata is corrected for older installs',
      () async {
    final repo = _FakeRepo(
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          author: 'Shaikh Muhammad Rais Qureshi',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu]);
    await cubit.load();

    expect(
      cubit.state.items.singleWhere((i) => i.slug == 'hi-ahsanul-kalam').author,
      'Muhammad Rais Qureshi Salafi',
    );
  });

  test('an installed edition with newer catalogue bytes shows update available',
      () async {
    final repo = _FakeRepo(
      available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          sha256: 'older-sha',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu]);
    await cubit.load();

    final item = cubit.state.items.singleWhere(
      (i) => i.slug == 'hi-ahsanul-kalam',
    );
    expect(item.state, EditionState.updateAvailable);
    expect(cubit.state.downloaded.map((i) => i.slug), contains(item.slug));
    expect(
      cubit.state.available.map((i) => i.slug),
      isNot(contains(item.slug)),
    );
  });

  test('an edition removed from the catalogue stays installed and usable',
      () async {
    final repo = _FakeRepo(
      available: const [], // the CDN no longer lists it
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          sha256: 'some-sha',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu]);
    await cubit.load();

    final item = cubit.state.items.singleWhere(
      (i) => i.slug == 'hi-ahsanul-kalam',
    );
    expect(item.state, EditionState.installed);
    expect(cubit.state.catalogueUnavailable, isFalse);
    expect(cubit.state.downloaded.map((i) => i.slug), contains(item.slug));
  });

  test('a newly available edition is flagged unseen until marked seen',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeRepo(
      available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu], prefs: prefs);
    await cubit.load();

    expect(cubit.state.hasUnseenEditions, isTrue);
    expect(cubit.state.newSlugs, {'hi-ahsanul-kalam'});

    await cubit.markCatalogueSeen();
    expect(cubit.state.hasUnseenEditions, isFalse);

    // Persisted — a later refresh doesn't resurrect the badge for the same
    // edition.
    await cubit.load();
    expect(cubit.state.hasUnseenEditions, isFalse);
  });

  test('a silent load never clears the unseen badge on its own', () async {
    // load() also runs as a launch-time background fetch (and a manual
    // pull-to-refresh) — only actually opening the screen should clear it.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeRepo(
      available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu], prefs: prefs);

    await cubit.load();
    expect(cubit.state.hasUnseenEditions, isTrue);

    await cubit.load();
    expect(cubit.state.hasUnseenEditions, isTrue);
  });

  test('toggling the last selected edition keeps it visible', () async {
    final repo = _FakeRepo(
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final settings = _FakeSettings(selectedTranslations: ['hi-ahsanul-kalam']);
    var invalidations = 0;
    final cubit = TranslationsCubit(
      repo,
      const [_bundledUrdu],
      settings: settings,
      onTranslationsChanged: () => invalidations += 1,
    );
    await cubit.load();

    await cubit.toggleSelected('hi-ahsanul-kalam');

    expect(settings.selectedTranslations, ['hi-ahsanul-kalam']);
    expect(repo.removeCalls, isEmpty);
    expect(
      cubit.state.items
          .singleWhere((i) => i.slug == 'hi-ahsanul-kalam')
          .selected,
      isTrue,
    );
    expect(invalidations, 0);
  });

  test('removing deselects the edition for the reader and refreshes caches',
      () async {
    final repo = _FakeRepo(
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final settings = _FakeSettings(
      selectedTranslations: ['ur-junagarhi', 'hi-ahsanul-kalam'],
    );
    var invalidations = 0;
    final cubit = TranslationsCubit(
      repo,
      const [_bundledUrdu],
      settings: settings,
      onTranslationsChanged: () => invalidations += 1,
    );
    await cubit.load();

    await cubit.remove('hi-ahsanul-kalam');

    expect(settings.selectedTranslations, ['ur-junagarhi']);
    expect(invalidations, 1);
  });

  test('a checksum failure is reported as such, not as a network error',
      () async {
    // The distinction matters: "try again" is the wrong advice when the bytes
    // did not match what the catalogue described.
    final repo = _FakeRepo(
      available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
      installThrows: const EditionIntegrityException('hi-ahsanul-kalam', 'bad'),
    );
    final cubit = TranslationsCubit(repo, const []);
    await cubit.load();
    await cubit.install('hi-ahsanul-kalam');

    final item = cubit.state.items.single;
    expect(item.state, EditionState.failed);
    expect(item.error, contains('checksum'));
  });

  test('offline still lists what is on the device', () async {
    // The reader's own translations must not disappear because the catalogue
    // is unreachable — this app's whole promise is that it works offline.
    final repo = _FakeRepo(
      catalogueThrows: true,
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu]);
    await cubit.load();

    expect(cubit.state.catalogueUnavailable, isTrue);
    expect(cubit.state.items.map((i) => i.slug), [
      'ur-junagarhi',
      'hi-ahsanul-kalam',
    ]);
  });

  test('removing an edition drops it from the list', () async {
    final repo = _FakeRepo(
      local: [
        InstalledEdition(
          slug: 'hi-ahsanul-kalam',
          type: 'translation',
          languageCode: 'hi',
          name: 'Ahsanul Kalam',
          installedAt: DateTime(2026),
        ),
      ],
    );
    final cubit = TranslationsCubit(repo, const []);
    await cubit.load();
    expect(cubit.state.items, hasLength(1));

    await cubit.remove('hi-ahsanul-kalam');

    expect(repo.removeCalls, ['hi-ahsanul-kalam']);
    expect(cubit.state.items, isEmpty);
  });

  group('TranslationsPage selection contract', () {
    testWidgets(
        'checked row tap hides a downloaded edition without uninstalling',
        (tester) async {
      final repo = _FakeRepo(
        local: [
          InstalledEdition(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            author: 'Muhammad Rais Qureshi Salafi',
            bytes: 2900000,
            installedAt: DateTime(2026),
          ),
        ],
      );
      final settings = _FakeSettings(
        selectedTranslations: ['ur-junagarhi', 'hi-ahsanul-kalam'],
      );
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      expect(
        tester
            .widget<Icon>(
              find.byKey(WidgetKeys.editionSelected('hi-ahsanul-kalam')),
            )
            .icon,
        Icons.check_box_rounded,
      );
      expect(find.text('Experimental'), findsOneWidget);
      expect(find.text('Muhammad Rais Qureshi Salafi'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.editionRow('hi-ahsanul-kalam')));
      await tester.pumpAndSettle();

      expect(settings.selectedTranslations, ['ur-junagarhi']);
      expect(repo.removeCalls, isEmpty);
      expect(repo.local.map((e) => e.slug), ['hi-ahsanul-kalam']);
      expect(
        tester
            .widget<Icon>(
              find.byKey(WidgetKeys.editionSelected('hi-ahsanul-kalam')),
            )
            .icon,
        Icons.check_box_outline_blank_rounded,
      );
    });

    testWidgets(
        'unchecked row tap shows a downloaded edition without reinstalling',
        (tester) async {
      final repo = _FakeRepo(
        local: [
          InstalledEdition(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            installedAt: DateTime(2026),
          ),
        ],
      );
      final settings = _FakeSettings(selectedTranslations: ['ur-junagarhi']);
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      expect(
        tester
            .widget<Icon>(
              find.byKey(WidgetKeys.editionSelected('hi-ahsanul-kalam')),
            )
            .icon,
        Icons.check_box_outline_blank_rounded,
      );

      await tester.tap(find.byKey(WidgetKeys.editionRow('hi-ahsanul-kalam')));
      await tester.pumpAndSettle();

      expect(settings.selectedTranslations, [
        'ur-junagarhi',
        'hi-ahsanul-kalam',
      ]);
      expect(repo.installCalls, isEmpty);
      expect(repo.removeCalls, isEmpty);
      expect(
        tester
            .widget<Icon>(
              find.byKey(WidgetKeys.editionSelected('hi-ahsanul-kalam')),
            )
            .icon,
        Icons.check_box_rounded,
      );
    });

    testWidgets(
        'delete icon asks for confirmation before uninstalling a downloaded '
        'edition', (tester) async {
      final repo = _FakeRepo(
        local: [
          InstalledEdition(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            installedAt: DateTime(2026),
          ),
        ],
      );
      final settings = _FakeSettings(
        selectedTranslations: ['ur-junagarhi', 'hi-ahsanul-kalam'],
      );
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      await tester
          .tap(find.byKey(WidgetKeys.editionRemove('hi-ahsanul-kalam')));
      await tester.pumpAndSettle();

      // Nothing removed yet — the dialog is up, asking to confirm.
      expect(find.text('Remove Ahsanul Kalam?'), findsOneWidget);
      expect(repo.removeCalls, isEmpty);
      expect(
        find.byKey(WidgetKeys.editionRow('hi-ahsanul-kalam')),
        findsOneWidget,
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(repo.removeCalls, ['hi-ahsanul-kalam']);
      expect(settings.selectedTranslations, ['ur-junagarhi']);
      expect(
        find.byKey(WidgetKeys.editionRow('hi-ahsanul-kalam')),
        findsNothing,
      );
    });

    testWidgets('cancelling the removal confirmation keeps the edition',
        (tester) async {
      final repo = _FakeRepo(
        local: [
          InstalledEdition(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            installedAt: DateTime(2026),
          ),
        ],
      );
      final settings = _FakeSettings(
        selectedTranslations: ['ur-junagarhi', 'hi-ahsanul-kalam'],
      );
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      await tester
          .tap(find.byKey(WidgetKeys.editionRemove('hi-ahsanul-kalam')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.removeCalls, isEmpty);
      expect(settings.selectedTranslations, [
        'ur-junagarhi',
        'hi-ahsanul-kalam',
      ]);
      expect(
        find.byKey(WidgetKeys.editionRow('hi-ahsanul-kalam')),
        findsOneWidget,
      );
    });

    testWidgets('tapping the last checked row leaves it checked',
        (tester) async {
      final repo = _FakeRepo(
        local: [
          InstalledEdition(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            installedAt: DateTime(2026),
          ),
        ],
      );
      final settings =
          _FakeSettings(selectedTranslations: ['hi-ahsanul-kalam']);
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      expect(find.text('Done'), findsNothing);
      await tester.tap(find.byKey(WidgetKeys.editionRow('hi-ahsanul-kalam')));
      await tester.pumpAndSettle();

      expect(settings.selectedTranslations, ['hi-ahsanul-kalam']);
      expect(repo.removeCalls, isEmpty);
      expect(
        tester
            .widget<Icon>(
              find.byKey(WidgetKeys.editionSelected('hi-ahsanul-kalam')),
            )
            .icon,
        Icons.check_box_rounded,
      );
    });

    testWidgets('row tap on an updateable edition toggles visibility only',
        (tester) async {
      final repo = _FakeRepo(
        available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
        local: [
          InstalledEdition(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            sha256: 'older-sha',
            installedAt: DateTime(2026),
          ),
        ],
      );
      final settings = _FakeSettings(
        selectedTranslations: ['ur-junagarhi', 'hi-ahsanul-kalam'],
      );
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      await tester.tap(find.byKey(WidgetKeys.editionRow('hi-ahsanul-kalam')));
      await tester.pumpAndSettle();

      expect(settings.selectedTranslations, ['ur-junagarhi']);
      expect(repo.installCalls, isEmpty);
      expect(repo.removeCalls, isEmpty);
      expect(
        find.byKey(WidgetKeys.editionDownload('hi-ahsanul-kalam')),
        findsOneWidget,
      );
    });

    testWidgets('update icon reinstalls a newer installed edition',
        (tester) async {
      final repo = _FakeRepo(
        available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
        local: [
          InstalledEdition(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            sha256: 'older-sha',
            installedAt: DateTime(2026),
          ),
        ],
      );
      final settings = _FakeSettings(
        selectedTranslations: ['ur-junagarhi', 'hi-ahsanul-kalam'],
      );
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      expect(find.text('Update'), findsOneWidget);
      await tester.tap(
        find.byKey(WidgetKeys.editionDownload('hi-ahsanul-kalam')),
      );
      await tester.pumpAndSettle();

      expect(repo.installCalls, ['hi-ahsanul-kalam']);
      expect(settings.selectedTranslations, [
        'ur-junagarhi',
        'hi-ahsanul-kalam',
      ]);
    });

    testWidgets('download icon installs and selects an available edition',
        (tester) async {
      final repo = _FakeRepo(
        available: [_entry('hi-ahsanul-kalam', 'hi', 'Ahsanul Kalam')],
      );
      final settings = _FakeSettings(selectedTranslations: ['ur-junagarhi']);
      final cubit = TranslationsCubit(
        repo,
        const [_bundledUrdu],
        settings: settings,
      );
      await cubit.load();

      await pumpTranslationsPage(tester, cubit);
      await tester.tap(
        find.byKey(WidgetKeys.editionDownload('hi-ahsanul-kalam')),
      );
      await tester.pumpAndSettle();

      expect(repo.installCalls, ['hi-ahsanul-kalam']);
      expect(settings.selectedTranslations, [
        'ur-junagarhi',
        'hi-ahsanul-kalam',
      ]);
      expect(
        tester
            .widget<Icon>(
              find.byKey(WidgetKeys.editionSelected('hi-ahsanul-kalam')),
            )
            .icon,
        Icons.check_box_rounded,
      );
    });
  });
}
