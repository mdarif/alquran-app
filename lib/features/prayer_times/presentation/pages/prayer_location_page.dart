// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/repositories/city_repository.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../cubit/city_search_cubit.dart';
import '../cubit/prayer_times_cubit.dart';

class PrayerLocationPage extends StatelessWidget {
  const PrayerLocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<CitySearchCubit>(),
      child: const _PrayerLocationView(),
    );
  }
}

class _PrayerLocationView extends StatefulWidget {
  const _PrayerLocationView();

  @override
  State<_PrayerLocationView> createState() => _PrayerLocationViewState();
}

class _PrayerLocationViewState extends State<_PrayerLocationView> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    await context.read<PrayerTimesCubit>().enableLocation();
    if (mounted && context.read<PrayerTimesCubit>().state.hasLocation) {
      Navigator.pop(context);
    }
  }

  Future<void> _choose(City city) async {
    await GetIt.I<PrayerTimesRepository>().saveLocation(city.toGeoLocation());
    GetIt.I<PrayerTimesCubit>().refresh();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _coordinates() async {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid latitude and longitude.')));
      return;
    }
    final city = await GetIt.I<CityRepository>().nearest(latitude, longitude);
    if (city == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No nearby city was found.')),
        );
      }
      return;
    }
    await GetIt.I<PrayerTimesRepository>().saveLocation(
      GeoLocation(
        latitude: latitude,
        longitude: longitude,
        label: city.name,
        timezoneId: city.timezoneId,
        source: LocationSource.coordinates,
      ),
    );
    GetIt.I<PrayerTimesCubit>().refresh();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: WidgetKeys.prayerLocationPage,
      appBar: AppBar(title: const Text('Set location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: WidgetKeys.prayerLocationUseGps,
              leading: const AppIcon(AppIcons.myLocation),
              title: const Text('Use my location'),
              subtitle: const Text('Uses your device location'),
              onTap: _useGps,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: WidgetKeys.prayerCitySearchField,
            decoration: const InputDecoration(labelText: 'Search city'),
            onChanged: context.read<CitySearchCubit>().search,
          ),
          BlocBuilder<CitySearchCubit, CitySearchState>(
            builder: (context, state) => Column(
              children: [
                if (state.loading) const LinearProgressIndicator(),
                for (var i = 0; i < state.cities.length; i++)
                  ListTile(
                    key: WidgetKeys.cityResult(i),
                    title: Text(state.cities[i].name),
                    subtitle: Text(
                        '${state.cities[i].admin1}, ${state.cities[i].country}'),
                    onTap: () => _choose(state.cities[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            initiallyExpanded: false,
            title: const Text('Advanced'),
            subtitle: const Text('Use only if your city is missing'),
            children: [
              TextField(
                  controller: _latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Latitude')),
              TextField(
                  controller: _longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Longitude')),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: _coordinates,
                      child: const Text('Use coordinates'))),
            ],
          ),
        ],
      ),
    );
  }
}
