import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/index_entry.dart';
import '../../domain/entities/index_kind.dart';
import '../../domain/repositories/index_repository.dart';

part 'index_list_state.dart';

class IndexListCubit extends Cubit<IndexListState> {
  IndexListCubit(this._repository) : super(const IndexListState());

  final IndexRepository _repository;

  Future<void> load(IndexKind kind) async {
    emit(state.copyWith(status: IndexListStatus.loading));
    try {
      final entries = await _repository.entries(kind);
      emit(state.copyWith(status: IndexListStatus.loaded, entries: entries));
    } catch (e) {
      emit(state.copyWith(status: IndexListStatus.error, error: e.toString()));
    }
  }
}
