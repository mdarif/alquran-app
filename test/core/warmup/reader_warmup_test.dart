import 'package:al_quran/core/warmup/reader_warmup.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Records which reader-repo methods the startup warm-up touches, so we can
/// assert it primes exactly the caches that make "Continue reading" and the
/// first surah open flash-free — without ever throwing.
class _RecordingRepo implements AyahRepository {
  final List<ReaderTarget> ayahCalls = [];
  int headingCalls = 0;
  int resourceCalls = 0;
  bool throwOnConstants = false;

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    ayahCalls.add(target);
    return const [];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async {
    headingCalls++;
    if (throwOnConstants) throw StateError('db down');
    return const {};
  }

  @override
  Future<List<TranslationResource>> getTranslationResources() async {
    resourceCalls++;
    return const [];
  }
}

class _StubLastRead implements LastReadRepository {
  _StubLastRead(this._value);
  final LastRead? _value;
  @override
  Future<LastRead?> load() async => _value;
  @override
  Future<void> save(LastRead value) async {}
}

class _ThrowingLastRead implements LastReadRepository {
  @override
  Future<LastRead?> load() async => throw StateError('prefs unavailable');
  @override
  Future<void> save(LastRead value) async {}
}

const _target = ReaderTarget.surah(47, 'Muhammad');
const _lastRead = LastRead(
  target: _target,
  ayahId: 4555,
  surahId: 47,
  ayahNumber: 10,
);

void main() {
  tearDown(GetIt.I.reset);

  test('primes the mushaf-wide constants and the Last-Read section', () async {
    final repo = _RecordingRepo();
    GetIt.I
      ..registerSingleton<AyahRepository>(repo)
      ..registerSingleton<LastReadRepository>(_StubLastRead(_lastRead));

    await warmReaderCache();

    expect(repo.headingCalls, 1);
    expect(repo.resourceCalls, 1);
    // The section the reader would resume to is warmed into the cache.
    expect(repo.ayahCalls, [_target]);
  });

  test('warms constants but no section when there is no resume point',
      () async {
    final repo = _RecordingRepo();
    GetIt.I
      ..registerSingleton<AyahRepository>(repo)
      ..registerSingleton<LastReadRepository>(_StubLastRead(null));

    await warmReaderCache();

    expect(repo.headingCalls, 1);
    expect(repo.resourceCalls, 1);
    expect(repo.ayahCalls, isEmpty);
  });

  test('never throws when the reader repos are not registered', () async {
    // An isolated pump (widget test) may not register the reader graph.
    await expectLater(warmReaderCache(), completes);
  });

  test('swallows repo failures — the reader just loads on demand', () async {
    final repo = _RecordingRepo()..throwOnConstants = true;
    GetIt.I
      ..registerSingleton<AyahRepository>(repo)
      ..registerSingleton<LastReadRepository>(_ThrowingLastRead());

    // Both the constants prime and the Last-Read load throw; warm must still
    // complete quietly.
    await expectLater(warmReaderCache(), completes);
  });
}
