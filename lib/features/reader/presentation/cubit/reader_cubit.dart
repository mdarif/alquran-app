import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ayah.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/ayah_repository.dart';

part 'reader_state.dart';

class ReaderCubit extends Cubit<ReaderState> {
  ReaderCubit(this._repository) : super(const ReaderState());

  final AyahRepository _repository;

  Future<void> load(int surahId) async {
    emit(state.copyWith(status: ReaderStatus.loading));
    try {
      final resources = await _repository.getTranslationResources();
      final ayahs = await _repository.getAyahs(surahId);
      emit(
        state.copyWith(
          status: ReaderStatus.loaded,
          ayahs: ayahs,
          resources: resources,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReaderStatus.error, error: e.toString()));
    }
  }
}
