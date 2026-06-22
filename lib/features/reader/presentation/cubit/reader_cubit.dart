import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ayah.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/ayah_repository.dart';
import '../../domain/repositories/last_read_repository.dart';

part 'reader_state.dart';

class ReaderCubit extends Cubit<ReaderState> {
  ReaderCubit(this._repository, this._lastRead) : super(const ReaderState());

  final AyahRepository _repository;
  final LastReadRepository _lastRead;

  /// The section currently shown — needed to record last-read progress.
  ReaderTarget? _target;

  /// The viewport the reader is in (true = Detailed) and the last verse reported,
  /// so Last Read records which view to resume in — and so a viewport switch
  /// re-stamps the existing resume point with the new view.
  bool _detailed = false;
  Ayah? _lastAyah;

  Future<void> load(ReaderTarget target) async {
    _target = target;
    emit(state.copyWith(status: ReaderStatus.loading));
    try {
      final resources = await _repository.getTranslationResources();
      final headings = await _repository.getSurahHeadings();
      final ayahs = await _repository.getAyahs(target);
      emit(
        state.copyWith(
          status: ReaderStatus.loaded,
          ayahs: ayahs,
          resources: resources,
          headings: headings,
        ),
      );
      // Remember the resume point: the section opened, at its first verse until
      // the user scrolls (then [saveProgress] refines it).
      if (ayahs.isNotEmpty) saveProgress(ayahs.first);
    } catch (e) {
      emit(state.copyWith(status: ReaderStatus.error, error: e.toString()));
    }
  }

  /// Records the active viewport (true = Detailed) so Last Read resumes in the
  /// same view. Re-stamps the existing resume point when it changes, so leaving
  /// right after switching views still records the new view.
  void setViewportDetailed(bool detailed) {
    if (_detailed == detailed) return;
    _detailed = detailed;
    final ayah = _lastAyah;
    if (ayah != null) saveProgress(ayah);
  }

  /// Records [ayah] as the last-read verse within the current section, so the
  /// home "Last Read" card resumes exactly here (in the current viewport).
  void saveProgress(Ayah ayah) {
    _lastAyah = ayah;
    final target = _target;
    if (target == null) return;
    unawaited(
      _lastRead.save(
        LastRead(
          target: target,
          ayahId: ayah.id,
          surahId: ayah.surahId,
          ayahNumber: ayah.ayahNumber,
          detailed: _detailed,
        ),
      ),
    );
  }
}
