import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/translations/domain/entities/catalogue_entry.dart';
import 'package:al_quran/features/translations/domain/entities/installed_edition.dart';
import 'package:al_quran/features/translations/domain/repositories/edition_repository.dart';
import 'package:al_quran/features/translations/presentation/cubit/translations_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<EditionCatalogue> catalogue({bool forceRefresh = false}) async {
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
      ...local,
      InstalledEdition(
        slug: entry.slug,
        type: entry.type,
        languageCode: entry.languageCode,
        name: entry.name,
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
  test('bundled editions are listed but offer no action', () async {
    final cubit = TranslationsCubit(_FakeRepo(), const [_bundledUrdu]);
    await cubit.load();

    final item = cubit.state.items.single;
    expect(item.slug, 'ur-junagarhi');
    // Bundled: there is no download to undo, and removing it would leave the
    // reader with nothing.
    expect(item.state, EditionState.bundled);
  });

  test('an edition already bundled is not offered again for download',
      () async {
    final repo = _FakeRepo(
      available: [_entry('ur-junagarhi', 'ur', 'Junagarhi')],
    );
    final cubit = TranslationsCubit(repo, const [_bundledUrdu]);
    await cubit.load();

    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.items.single.state, EditionState.bundled);
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
}
