import 'package:al_quran/core/navigation/route_observer.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/presentation/widgets/last_read_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class _FakeLastRead implements LastReadRepository {
  _FakeLastRead(this._value);
  final LastRead? _value;
  @override
  Future<void> save(LastRead value) async {}
  @override
  Future<LastRead?> load() async => _value;
}

class _FakeAyahRepo implements AyahRepository {
  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => const {
        2: SurahHeading(number: 2, nameEnglish: 'Al-Baqarah', totalAyahs: 286),
      };
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => const [];
  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

Future<void> _pump(WidgetTester tester, LastRead? value) async {
  GetIt.I
    ..registerLazySingleton<LastReadRepository>(() => _FakeLastRead(value))
    ..registerLazySingleton<AyahRepository>(_FakeAyahRepo.new);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [routeObserver],
      home: const Scaffold(body: LastReadBanner()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(GetIt.I.reset);

  testWidgets('shows "Last Read" with the exact verse reference',
      (tester) async {
    await _pump(
      tester,
      const LastRead(
        target: ReaderTarget.surah(2, 'Al-Baqarah'),
        ayahId: 262,
        surahId: 2,
        ayahNumber: 255,
      ),
    );

    expect(find.text('Last Read'), findsOneWidget);
    expect(find.text('Al-Baqarah · Ayah 255'), findsOneWidget);
  });

  testWidgets('is hidden when nothing has been read', (tester) async {
    await _pump(tester, null);

    expect(find.text('Last Read'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });
}
