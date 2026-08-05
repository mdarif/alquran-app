import 'package:equatable/equatable.dart';

class TafsirEntry extends Equatable {
  const TafsirEntry({
    required this.resource,
    required this.ayahKey,
    required this.groupAyahKey,
    required this.fromAyah,
    required this.toAyah,
    required this.ayahKeys,
    required this.text,
  });

  final String resource;
  final String ayahKey;
  final String groupAyahKey;
  final String fromAyah;
  final String toAyah;
  final List<String> ayahKeys;
  final String text;

  bool get spansMultipleAyahs => fromAyah != toAyah;

  @override
  List<Object?> get props => [
        resource,
        ayahKey,
        groupAyahKey,
        fromAyah,
        toAyah,
        ayahKeys,
        text,
      ];
}
