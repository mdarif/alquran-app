import 'package:equatable/equatable.dart';

/// The five MVP navigation dimensions (PRD 4.2).
enum ReaderDimension { surah, juz, hizb, page, ruku }

/// What the reader should display: one value of one [ReaderDimension], plus a
/// human title for the app bar. A juz/hizb/page/ruku section may span surahs.
class ReaderTarget extends Equatable {
  const ReaderTarget({
    required this.dimension,
    required this.value,
    required this.title,
  });

  const ReaderTarget.surah(int id, String surahTitle)
      : dimension = ReaderDimension.surah,
        value = id,
        title = surahTitle;

  const ReaderTarget.juz(int n)
      : dimension = ReaderDimension.juz,
        value = n,
        title = 'Juz $n';

  const ReaderTarget.hizb(int n)
      : dimension = ReaderDimension.hizb,
        value = n,
        title = 'Hizb $n';

  const ReaderTarget.page(int n)
      : dimension = ReaderDimension.page,
        value = n,
        title = 'Page $n';

  const ReaderTarget.ruku(int n)
      : dimension = ReaderDimension.ruku,
        value = n,
        title = 'Ruku $n';

  final ReaderDimension dimension;
  final int value;
  final String title;

  @override
  List<Object?> get props => [dimension, value, title];
}
