import 'package:al_quran/features/navigation/domain/entities/index_entry.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:al_quran/features/navigation/domain/repositories/index_repository.dart';
import 'package:al_quran/features/navigation/presentation/cubit/index_list_cubit.dart';
import 'package:al_quran/features/navigation/presentation/widgets/index_list_view.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class _FakeIndexRepository implements IndexRepository {
  @override
  Future<List<IndexEntry>> entries(IndexKind kind) async => const [
        IndexEntry(
          number: 1,
          startSurahId: 1,
          startSurahName: 'Al-Fatihah',
          startAyah: 1,
        ),
        IndexEntry(
          number: 2,
          startSurahId: 2,
          startSurahName: 'Al-Baqarah',
          startAyah: 142,
        ),
      ];
}

void main() {
  setUp(() {
    GetIt.I.registerFactory<IndexListCubit>(
      () => IndexListCubit(_FakeIndexRepository()),
    );
  });
  tearDown(GetIt.I.reset);

  testWidgets('shows a short "Name surah:ayah" reference per entry',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IndexListView(kind: IndexKind.juz, label: 'Juz'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juz 1'), findsOneWidget);
    expect(find.text('Al-Fatihah 1:1'), findsOneWidget);
    expect(find.text('Juz 2'), findsOneWidget);
    expect(find.text('Al-Baqarah 2:142'), findsOneWidget);
  });

  testWidgets('uses the embedded target callback when provided',
      (tester) async {
    ReaderTarget? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndexListView(
            kind: IndexKind.page,
            label: 'Page',
            onTargetSelected: (target) => selected = target,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Page 2'));
    await tester.pumpAndSettle();

    expect(selected, const ReaderTarget.page(2));
  });

  testWidgets('uses Surah-list row rhythm and soft inset dividers',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IndexListView(kind: IndexKind.page, label: 'Page'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final minHeights = [
      for (final element in find.byType(ConstrainedBox).evaluate())
        (element.widget as ConstrainedBox).constraints.minHeight,
    ];
    expect(minHeights, contains(60));

    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect(divider.height, 1);
    expect(divider.thickness, 1);
  });
}
