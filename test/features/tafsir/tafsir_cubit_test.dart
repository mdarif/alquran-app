import 'package:al_quran/features/tafsir/domain/entities/tafsir_catalogue_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:al_quran/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:al_quran/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load hides catalogue entries marked visible=false', () async {
    final cubit = TafsirCubit(
      const _FakeTafsirRepository(
        catalogue: TafsirCatalogue(
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
      const _FakeTafsirRepository(
        catalogue: TafsirCatalogue(resources: [_hiddenUrdu]),
        installedResources: [
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

class _FakeTafsirRepository implements TafsirRepository {
  const _FakeTafsirRepository({
    required TafsirCatalogue catalogue,
    List<TafsirResource> installedResources = const [],
  })  : _catalogue = catalogue,
        _installedResources = installedResources;

  final TafsirCatalogue _catalogue;
  final List<TafsirResource> _installedResources;

  @override
  Future<TafsirCatalogue> catalogue() async => _catalogue;

  @override
  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  }) async =>
      null;

  @override
  Future<void> install(
    TafsirCatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {}

  @override
  Future<List<TafsirResource>> installed() async => _installedResources;
}
