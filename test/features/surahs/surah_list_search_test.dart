import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/domain/repositories/surah_repository.dart';
import 'package:al_quran/features/surahs/presentation/cubit/surah_list_cubit.dart';
import 'package:al_quran/features/surahs/presentation/pages/surah_list_page.dart';
import 'package:al_quran/features/surahs/presentation/widgets/surah_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The body renders `state.visibleHits`; search is driven by the host (the Home
/// app bar) via the cubit, so these tests drive the cubit directly.
class _FakeSurahRepository implements SurahRepository {
  @override
  Future<List<Surah>> getSurahs() async => [
        _s(1, 'الفاتحة', 'Al-Fatihah', 7),
        _s(2, 'البقرة', 'Al-Baqarah', 286),
        _s(18, 'الكهف', 'Al-Kahf', 110),
      ];
}

Surah _s(int id, String ar, String en, int total) =>
    Surah(id: id, nameArabic: ar, nameEnglish: en, totalAyahs: total);

void main() {
  late SurahListCubit cubit;

  Future<void> pump(WidgetTester tester) async {
    cubit = SurahListCubit(_FakeSurahRepository());
    await cubit.load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SurahListCubit>.value(
          value: cubit,
          child: const Scaffold(body: SurahListBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders all surahs when the query is empty', (tester) async {
    await pump(tester);
    expect(find.byType(SurahTile), findsNWidgets(3));
  });

  testWidgets('a name query narrows the list; clearing restores it',
      (tester) async {
    await pump(tester);

    cubit.search('kahf');
    await tester.pumpAndSettle();
    expect(find.byType(SurahTile), findsOneWidget);
    expect(find.text('Al-Kahf'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsNothing);

    cubit.search('');
    await tester.pumpAndSettle();
    expect(find.byType(SurahTile), findsNWidgets(3));
  });

  testWidgets('a number query narrows to that surah', (tester) async {
    await pump(tester);
    cubit.search('18');
    await tester.pumpAndSettle();
    expect(find.text('Al-Kahf'), findsOneWidget);
    expect(find.byType(SurahTile), findsOneWidget);
  });

  testWidgets('a verse reference shows a single Ayah-N jump row',
      (tester) async {
    await pump(tester);
    cubit.search('18:5');
    await tester.pumpAndSettle();
    expect(find.byType(SurahTile), findsOneWidget);
    expect(find.text('Al-Kahf'), findsOneWidget);
    expect(find.textContaining('Ayah 5'), findsOneWidget);
  });

  testWidgets('a non-matching query shows the empty placeholder',
      (tester) async {
    await pump(tester);
    cubit.search('zzzzz');
    await tester.pumpAndSettle();
    expect(find.byType(SurahTile), findsNothing);
    expect(find.textContaining('No surah matches'), findsOneWidget);
  });
}
