import 'package:equatable/equatable.dart';

import 'reader_target.dart';

/// Where the reader left off (PRD §12: last-read resume): the [target] section
/// to reopen, plus the exact ayah within it so we can scroll back to that verse.
///
/// [ayahId] is the global ayah id (unique, used to locate/scroll). [surahId] and
/// [ayahNumber] are kept for the human reference shown on the home card
/// ("Al-Baqarah 2:255") without a DB lookup.
class LastRead extends Equatable {
  const LastRead({
    required this.target,
    required this.ayahId,
    required this.surahId,
    required this.ayahNumber,
  });

  final ReaderTarget target;
  final int ayahId;
  final int surahId;
  final int ayahNumber;

  @override
  List<Object?> get props => [target, ayahId, surahId, ayahNumber];
}
