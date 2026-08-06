import 'package:al_quran/features/tafsir/domain/entities/tafsir_catalogue_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:al_quran/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:al_quran/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('load hides catalogue entries marked visible=false', () async {
    final cubit = TafsirCubit(
      _FakeTafsirRepository(
        catalogue: const TafsirCatalogue(
          resources: [
            _visibleEnglish,
            _hiddenUrdu,
          ],
        ),
      ),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(
      cubit.state.items.map((item) => item.slug),
      const ['en-ibn-kathir-abridged'],
    );
  });

  test('load hides an installed resource when the catalogue hides that slug',
      () async {
    final cubit = TafsirCubit(
      _FakeTafsirRepository(
        catalogue: const TafsirCatalogue(resources: [_hiddenUrdu]),
        installedResources: const [
          TafsirResource(
            slug: 'ur-ibn-kathir',
            languageCode: 'ur',
            name: 'Tafsir Ibn Kathir',
            nativeName: 'اردو',
            direction: 'rtl',
            ayahCount: 6236,
            bytes: 200,
          ),
        ],
      ),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(
      cubit.state.items.map((item) => item.slug),
      isNot(contains('ur-ibn-kathir')),
    );
  });

  test('entriesForAyah returns every installed Tafsir with commentary',
      () async {
    final cubit = TafsirCubit(
      _FakeTafsirRepository(
        catalogue: const TafsirCatalogue(resources: []),
        installedResources: const [
          TafsirResource(
            slug: 'en-ibn-kathir-abridged',
            languageCode: 'en',
            name: 'Tafsir Ibn Kathir',
            ayahCount: 6236,
            bytes: 200,
          ),
          TafsirResource(
            slug: 'ur-ibn-kathir',
            languageCode: 'ur',
            name: 'Tafsir Ibn Kathir',
            nativeName: 'اردو',
            direction: 'rtl',
            ayahCount: 6236,
            bytes: 200,
          ),
        ],
        entriesBySlug: {
          'en-ibn-kathir-abridged': _englishEntry,
          'ur-ibn-kathir': _urduEntry,
        },
      ),
    );
    addTearDown(cubit.close);

    final results = await cubit.entriesForAyah(surah: 2, ayah: 2);

    expect(
      results.map((result) => result.resource.slug),
      const ['en-ibn-kathir-abridged', 'ur-ibn-kathir'],
    );
    expect(results.map((result) => result.entry.text), [
      'English commentary.',
      'اردو تفسیر۔',
    ]);
  });

  test('remove deletes installed Tafsir and reloads catalogue row as available',
      () async {
    final repository = _FakeTafsirRepository.mutable(
      catalogue: const TafsirCatalogue(resources: [_visibleEnglish]),
      installedResources: [
        const TafsirResource(
          slug: 'en-ibn-kathir-abridged',
          languageCode: 'en',
          name: 'Tafsir Ibn Kathir',
          abridged: true,
          ayahCount: 6236,
          bytes: 200,
        ),
      ],
    );
    final cubit = TafsirCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect(
      cubit.state.item('en-ibn-kathir-abridged')?.status,
      TafsirItemStatus.installed,
    );

    await cubit.remove('en-ibn-kathir-abridged');

    expect(repository.removedSlugs, const ['en-ibn-kathir-abridged']);
    expect(
      cubit.state.item('en-ibn-kathir-abridged')?.status,
      TafsirItemStatus.available,
    );
  });

  test('toggleSelected moves installed Tafsir between shown and downloaded',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cubit = TafsirCubit(
      _FakeTafsirRepository(
        catalogue: const TafsirCatalogue(resources: []),
        installedResources: const [
          _installedEnglish,
          _installedUrdu,
        ],
      ),
      prefs: prefs,
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.item('en-ibn-kathir-abridged')?.selected, isTrue);
    expect(cubit.state.item('ur-ibn-kathir')?.selected, isTrue);

    await cubit.toggleSelected('ur-ibn-kathir');

    expect(cubit.state.item('en-ibn-kathir-abridged')?.selected, isTrue);
    expect(cubit.state.item('ur-ibn-kathir')?.selected, isFalse);
    expect(prefs.getStringList('tafsir_selected_slugs'), [
      'en-ibn-kathir-abridged',
    ]);
  });

  test('entriesForAyah only returns selected installed Tafsir', () async {
    SharedPreferences.setMockInitialValues({
      'tafsir_selected_slugs': ['ur-ibn-kathir'],
    });
    final prefs = await SharedPreferences.getInstance();
    final cubit = TafsirCubit(
      _FakeTafsirRepository(
        catalogue: const TafsirCatalogue(resources: []),
        installedResources: const [
          _installedEnglish,
          _installedUrdu,
        ],
        entriesBySlug: {
          'en-ibn-kathir-abridged': _englishEntry,
          'ur-ibn-kathir': _urduEntry,
        },
      ),
      prefs: prefs,
    );
    addTearDown(cubit.close);

    final results = await cubit.entriesForAyah(surah: 2, ayah: 2);

    expect(results.map((result) => result.resource.slug), ['ur-ibn-kathir']);
  });
}

const _visibleEnglish = TafsirCatalogueEntry(
  slug: 'en-ibn-kathir-abridged',
  languageCode: 'en',
  name: 'Tafsir Ibn Kathir',
  file: 'en.db.gz',
  bytes: 100,
  sha256: 'sha',
  uncompressedBytes: 200,
  uncompressedSha256: 'raw-sha',
  ayahCount: 6236,
  textGroupCount: 1902,
  visible: true,
);

const _hiddenUrdu = TafsirCatalogueEntry(
  slug: 'ur-ibn-kathir',
  languageCode: 'ur',
  name: 'Tafsir Ibn Kathir',
  nativeName: 'اردو',
  direction: 'rtl',
  file: 'ur.db.gz',
  bytes: 100,
  sha256: 'sha',
  uncompressedBytes: 200,
  uncompressedSha256: 'raw-sha',
  ayahCount: 6236,
  textGroupCount: 2101,
  visible: false,
);

const _englishEntry = TafsirEntry(
  resource: 'en-ibn-kathir-abridged',
  ayahKey: '2:2',
  groupAyahKey: '2:2',
  fromAyah: '2:2',
  toAyah: '2:2',
  ayahKeys: ['2:2'],
  text: 'English commentary.',
);

const _urduEntry = TafsirEntry(
  resource: 'ur-ibn-kathir',
  ayahKey: '2:2',
  groupAyahKey: '2:2',
  fromAyah: '2:2',
  toAyah: '2:2',
  ayahKeys: ['2:2'],
  text: 'اردو تفسیر۔',
);

const _installedEnglish = TafsirResource(
  slug: 'en-ibn-kathir-abridged',
  languageCode: 'en',
  name: 'Tafsir Ibn Kathir',
  abridged: true,
  ayahCount: 6236,
  bytes: 200,
);

const _installedUrdu = TafsirResource(
  slug: 'ur-ibn-kathir',
  languageCode: 'ur',
  name: 'Tafsir Ibn Kathir',
  nativeName: 'اردو',
  direction: 'rtl',
  ayahCount: 6236,
  bytes: 200,
);

class _FakeTafsirRepository implements TafsirRepository {
  _FakeTafsirRepository({
    required TafsirCatalogue catalogue,
    List<TafsirResource> installedResources = const [],
    Map<String, TafsirEntry> entriesBySlug = const {},
  })  : _catalogue = catalogue,
        _installedResources = List<TafsirResource>.of(installedResources),
        _entriesBySlug = entriesBySlug;

  _FakeTafsirRepository.mutable({
    required TafsirCatalogue catalogue,
    List<TafsirResource> installedResources = const [],
    Map<String, TafsirEntry> entriesBySlug = const {},
  })  : _catalogue = catalogue,
        _installedResources = List<TafsirResource>.of(installedResources),
        _entriesBySlug = entriesBySlug;

  final TafsirCatalogue _catalogue;
  final List<TafsirResource> _installedResources;
  final Map<String, TafsirEntry> _entriesBySlug;
  final List<String> removedSlugs = [];

  @override
  Future<TafsirCatalogue> catalogue() async => _catalogue;

  @override
  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  }) async =>
      _entriesBySlug[slug];

  @override
  Future<void> install(
    TafsirCatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {}

  @override
  Future<List<TafsirResource>> installed() async => _installedResources;

  @override
  Future<void> remove(String slug) async {
    removedSlugs.add(slug);
    _installedResources.removeWhere((resource) => resource.slug == slug);
  }
}
