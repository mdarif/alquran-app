// ignore_for_file: require_trailing_commas

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/city.dart';
import '../../domain/repositories/city_repository.dart';

class CitySearchCubit extends Cubit<CitySearchState> {
  CitySearchCubit(this._cities) : super(const CitySearchState());

  final CityRepository _cities;
  Timer? _debounce;

  void search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      emit(const CitySearchState());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      emit(CitySearchState(query: query, loading: true));
      try {
        final results = await _cities.search(query);
        if (!isClosed) emit(CitySearchState(query: query, cities: results));
      } catch (_) {
        if (!isClosed) emit(CitySearchState(query: query));
      }
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

class CitySearchState {
  const CitySearchState(
      {this.query = '', this.cities = const [], this.loading = false});

  final String query;
  final List<City> cities;
  final bool loading;
}
