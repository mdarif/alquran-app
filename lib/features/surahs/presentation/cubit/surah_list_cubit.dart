import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/surah.dart';
import '../../domain/repositories/surah_repository.dart';
import '../../domain/surah_search.dart';

part 'surah_list_state.dart';

class SurahListCubit extends Cubit<SurahListState> {
  SurahListCubit(this._repository) : super(const SurahListState());

  final SurahRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: SurahListStatus.loading));
    try {
      final surahs = await _repository.getSurahs();
      emit(state.copyWith(status: SurahListStatus.loaded, surahs: surahs));
    } catch (e) {
      emit(state.copyWith(status: SurahListStatus.error, error: e.toString()));
    }
  }

  /// Update the live search query; the filtered result is [SurahListState.visibleSurahs].
  void search(String query) => emit(state.copyWith(query: query));
}
