import 'package:al_quran/core/scroll/quran_scroll_behavior.dart';
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

/// Enough rows to overflow the test viewport, so the list has real scroll
/// extent to exercise edge physics against.
class _FakeManySurahRepository implements SurahRepository {
  @override
  Future<List<Surah>> getSurahs() async => List.generate(
        30,
        (i) => _s(i + 1, 'سورة ${i + 1}', 'Surah ${i + 1}', 10),
      );
}

void main() {
  late SurahListCubit cubit;

  Future<void> pump(WidgetTester tester) async {
    cubit = SurahListCubit(_FakeSurahRepository());
    await cubit.load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const QuranScrollBehavior(),
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

  testWidgets('pulling down at the top does not overscroll', (tester) async {
    // Matches MushafView's clamped-edge behaviour (mushaf_view_test.dart) —
    // the home list shouldn't rubber-band past its true top either.
    // Needs enough rows to overflow the viewport, else minScrollExtent ==
    // maxScrollExtent == 0 and the list can't overscroll regardless of physics.
    cubit = SurahListCubit(_FakeManySurahRepository());
    await cubit.load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const QuranScrollBehavior(),
        home: BlocProvider<SurahListCubit>.value(
          value: cubit,
          child: const Scaffold(body: SurahListBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, 0);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView)));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      // Check mid-drag: bouncing physics rubber-bands past 0 while the
      // finger is still down, then springs back to 0 on release either
      // way — so the assertion must fire before `up()`, not after.
      expect(
        position.pixels,
        greaterThanOrEqualTo(position.minScrollExtent),
        reason: 'no rubber-band while pulling down at the true top',
      );
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    expect(position.pixels, greaterThanOrEqualTo(position.minScrollExtent));
  });

  testWidgets(
      'repeated discrete swipes (pull-down, swipe-up, swipe-back-down) '
      'return to the exact starting position each time', (tester) async {
    // Regression for a reported "odd padding" glitch after sliding the list
    // down and up several times — each release must settle the first tile
    // back at its exact original offset, not a drifted one.
    cubit = SurahListCubit(_FakeManySurahRepository());
    await cubit.load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const QuranScrollBehavior(),
        home: BlocProvider<SurahListCubit>.value(
          value: cubit,
          child: const Scaffold(body: SurahListBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final startTop = tester.getTopLeft(find.byType(SurahTile).first);

    Future<void> dragRelease(double dy) async {
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(ListView)));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, dy / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    for (var cycle = 0; cycle < 5; cycle++) {
      await dragRelease(200); // pull down at the top (clamped, no movement)
      await dragRelease(-80); // swipe up, scrolling into content a bit
      await dragRelease(200); // swipe back down to the top

      expect(
        position.pixels,
        0,
        reason: 'cycle $cycle: must settle back at the true top',
      );
      expect(
        tester.getTopLeft(find.byType(SurahTile).first),
        startTop,
        reason: 'cycle $cycle: first tile must land at its exact original '
            'offset — no leftover fractional-pixel gap reading as '
            'extra/missing padding',
      );
    }
  });
}
