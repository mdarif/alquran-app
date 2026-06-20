import 'package:al_quran/features/navigation/domain/entities/index_entry.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:al_quran/features/navigation/domain/repositories/index_repository.dart';
import 'package:al_quran/features/navigation/presentation/cubit/index_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIndexRepository implements IndexRepository {
  _FakeIndexRepository({this.result = const [], this.error});

  final List<IndexEntry> result;
  final Object? error;

  @override
  Future<List<IndexEntry>> entries(IndexKind kind) async {
    if (error != null) throw error!;
    return result;
  }
}

const _juz1 = IndexEntry(
  number: 1,
  startSurahId: 1,
  startSurahName: 'Al-Fatihah',
  startAyah: 1,
);

void main() {
  group('IndexListCubit', () {
    test('initial state is initial with no entries', () {
      final cubit = IndexListCubit(_FakeIndexRepository());
      expect(cubit.state.status, IndexListStatus.initial);
      expect(cubit.state.entries, isEmpty);
      cubit.close();
    });

    test('load() emits loading then loaded with entries', () async {
      final cubit = IndexListCubit(
        _FakeIndexRepository(result: const [_juz1]),
      );

      final expectation = expectLater(
        cubit.stream.map((s) => s.status),
        emitsInOrder([IndexListStatus.loading, IndexListStatus.loaded]),
      );

      await cubit.load(IndexKind.juz);
      await expectation;

      expect(cubit.state.entries, const [_juz1]);
      await cubit.close();
    });

    test('load() emits loading then error when the repository throws',
        () async {
      final cubit = IndexListCubit(
        _FakeIndexRepository(error: Exception('boom')),
      );

      final expectation = expectLater(
        cubit.stream.map((s) => s.status),
        emitsInOrder([IndexListStatus.loading, IndexListStatus.error]),
      );

      await cubit.load(IndexKind.page);
      await expectation;

      expect(cubit.state.error, contains('boom'));
      await cubit.close();
    });
  });
}
