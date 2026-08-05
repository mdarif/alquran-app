import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/tafsir_catalogue_entry.dart';
import '../../domain/entities/tafsir_entry.dart';
import '../../domain/entities/tafsir_resource.dart';
import '../../domain/repositories/tafsir_repository.dart';

part 'tafsir_state.dart';

class TafsirCubit extends Cubit<TafsirState> {
  TafsirCubit(this._repository) : super(const TafsirState());

  final TafsirRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: TafsirStatus.loading));
    var catalogueUnavailable = false;
    List<TafsirCatalogueEntry> available = const [];
    final installed = await _repository.installed();
    try {
      available = (await _repository.catalogue()).resources;
    } catch (_) {
      catalogueUnavailable = true;
    }
    emit(
      state.copyWith(
        status: TafsirStatus.ready,
        items: _merge(available: available, installed: installed),
        catalogueUnavailable: catalogueUnavailable,
        clearFailure: true,
      ),
    );
  }

  Future<void> install(String slug) async {
    final item = state.item(slug);
    final entry = item?.catalogueEntry;
    if (entry == null || state.isInstalling(slug)) return;
    _updateItem(slug, item!.copyWith(status: TafsirItemStatus.installing));
    try {
      await _repository.install(
        entry,
        onProgress: (progress) {
          final current = state.item(slug);
          if (current != null) {
            _updateItem(
              slug,
              current.copyWith(
                status: TafsirItemStatus.installing,
                progress: progress,
              ),
            );
          }
        },
      );
      await load();
    } catch (e) {
      final current = state.item(slug);
      if (current != null) {
        _updateItem(
          slug,
          current.copyWith(
            status: TafsirItemStatus.failed,
            progress: 0,
          ),
        );
      }
      emit(state.copyWith(failure: '$e'));
    }
  }

  Future<TafsirAyahResult?> entryForAyah({
    required int surah,
    required int ayah,
  }) async {
    final installed = await _repository.installed();
    for (final resource in installed) {
      final entry = await _repository.entryForAyah(
        slug: resource.slug,
        surah: surah,
        ayah: ayah,
      );
      if (entry != null) {
        return TafsirAyahResult(resource: resource, entry: entry);
      }
    }
    return null;
  }

  void _updateItem(String slug, TafsirItem item) {
    emit(
      state.copyWith(
        items: [
          for (final candidate in state.items)
            if (candidate.slug == slug) item else candidate,
        ],
      ),
    );
  }

  List<TafsirItem> _merge({
    required List<TafsirCatalogueEntry> available,
    required List<TafsirResource> installed,
  }) {
    final installedBySlug = {for (final r in installed) r.slug: r};
    final catalogueBySlug = {for (final e in available) e.slug: e};
    final slugs = <String>{
      ...catalogueBySlug.keys,
      ...installedBySlug.keys,
    }.toList()
      ..sort((a, b) {
        final left =
            catalogueBySlug[a]?.sortOrder ?? installedBySlug[a]?.sortOrder ?? 0;
        final right =
            catalogueBySlug[b]?.sortOrder ?? installedBySlug[b]?.sortOrder ?? 0;
        final cmp = left.compareTo(right);
        return cmp == 0 ? a.compareTo(b) : cmp;
      });

    final items = [
      for (final slug in slugs)
        TafsirItem(
          slug: slug,
          catalogueEntry: catalogueBySlug[slug],
          resource: installedBySlug[slug],
          status: installedBySlug.containsKey(slug)
              ? TafsirItemStatus.installed
              : TafsirItemStatus.available,
        ),
    ];
    if (items.isEmpty) return const [_plannedIbnKathir];
    return items;
  }
}

const _plannedIbnKathir = TafsirItem(
  slug: 'en-ibn-kathir-abridged',
  status: TafsirItemStatus.unavailable,
  plannedName: 'Tafsir Ibn Kathir',
  plannedSubtitle: 'English abridged edition',
);
