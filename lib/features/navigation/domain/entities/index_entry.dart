import 'package:equatable/equatable.dart';

/// One entry in an index list (e.g. "Juz 5"), labelled with where it begins.
class IndexEntry extends Equatable {
  const IndexEntry({
    required this.number,
    required this.startSurahId,
    required this.startSurahName,
    required this.startAyah,
  });

  final int number;
  final int startSurahId;
  final String startSurahName;
  final int startAyah;

  @override
  List<Object?> get props => [number, startSurahId, startSurahName, startAyah];
}
