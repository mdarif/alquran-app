import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/tafsir_catalogue_entry.dart';
import '../../domain/entities/tafsir_entry.dart';
import '../../domain/entities/tafsir_resource.dart';
import '../../domain/repositories/tafsir_repository.dart';

part 'tafsir_state.dart';

class TafsirCubit extends Cubit<TafsirState> {
  TafsirCubit(
    this._repository, {
    SharedPreferences? prefs,
  })  : _prefs = prefs,
        super(const TafsirState());

  static const String _kSelectedTafsir = 'tafsir_selected_slugs';

  final TafsirRepository _repository;
  final SharedPreferences? _prefs;

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
      ),
    );
  }

  Future<void> install(String slug) async {
    final item = state.item(slug);
    final entry = item?.catalogueEntry;
    if (entry == null || state.isInstalling(slug)) return;
    _updateItem(
      slug,
      item!.copyWith(status: TafsirItemStatus.installing, clearError: true),
    );
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
      await _selectInstalled(slug);
      await load();
    } on TafsirIntegrityException catch (e) {
      // Say plainly that the file didn't match, rather than offering a retry
      // that looks like a flaky network — this is a corrupted/wrong artifact.
      final current = state.item(slug);
      if (current != null) {
        _updateItem(
          slug,
          current.copyWith(
            status: TafsirItemStatus.failed,
            progress: 0,
            error: 'The download did not match its checksum and was discarded.',
          ),
        );
      }
      addError(e);
    } catch (e) {
      final current = state.item(slug);
      if (current != null) {
        _updateItem(
          slug,
          current.copyWith(
            status: TafsirItemStatus.failed,
            progress: 0,
            error: 'Download failed. Check your connection and try again.',
          ),
        );
      }
      addError(e);
    }
  }

  Future<void> remove(String slug) async {
    await _repository.remove(slug);
    await _deselectRemoved(slug);
    await load();
  }

  Future<void> toggleSelected(String slug) async {
    final item = state.item(slug);
    if (item == null || item.status != TafsirItemStatus.installed) return;
    final prefs = _prefs;
    if (prefs == null) return;
    final installedSlugs = [
      for (final i in state.items)
        if (i.status == TafsirItemStatus.installed) i.slug,
    ];
    final current = (_selectedTafsirSlugs() ?? installedSlugs).toSet();
    if (current.contains(slug)) {
      if (current.length == 1) return;
      current.remove(slug);
    } else {
      current.add(slug);
    }
    await prefs.setStringList(_kSelectedTafsir, current.toList());
    _updateItem(slug, item.copyWith(selected: current.contains(slug)));
  }

  Future<TafsirAyahResult?> entryForAyah({
    required int surah,
    required int ayah,
  }) async {
    final results = await entriesForAyah(surah: surah, ayah: ayah);
    return results.isEmpty ? null : results.first;
  }

  Future<List<TafsirAyahResult>> entriesForAyah({
    required int surah,
    required int ayah,
  }) async {
    final installed = await _repository.installed();
    final selected = _selectedTafsirSlugs()?.toSet();
    final results = <TafsirAyahResult>[];
    for (final resource in installed) {
      if (selected != null && !selected.contains(resource.slug)) continue;
      final entry = await _repository.entryForAyah(
        slug: resource.slug,
        surah: surah,
        ayah: ayah,
      );
      if (entry != null) {
        results.add(TafsirAyahResult(resource: resource, entry: entry));
      }
    }
    return results;
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
    final selectedSlugs =
        (_selectedTafsirSlugs() ?? installedBySlug.keys.toList()).toSet();
    final hiddenSlugs = {
      for (final entry in available)
        if (!entry.visible) entry.slug,
    };
    final visibleCatalogueBySlug = {
      for (final entry in available)
        if (entry.visible) entry.slug: entry,
    };
    final slugs = <String>{
      ...visibleCatalogueBySlug.keys,
      for (final slug in installedBySlug.keys)
        if (!hiddenSlugs.contains(slug)) slug,
    }.toList()
      ..sort((a, b) {
        final left = visibleCatalogueBySlug[a]?.sortOrder ??
            installedBySlug[a]?.sortOrder ??
            0;
        final right = visibleCatalogueBySlug[b]?.sortOrder ??
            installedBySlug[b]?.sortOrder ??
            0;
        final cmp = left.compareTo(right);
        return cmp == 0 ? a.compareTo(b) : cmp;
      });

    final items = [
      for (final slug in slugs)
        TafsirItem(
          slug: slug,
          catalogueEntry: visibleCatalogueBySlug[slug],
          resource: installedBySlug[slug],
          selected: selectedSlugs.contains(slug),
          status: installedBySlug.containsKey(slug)
              ? TafsirItemStatus.installed
              : TafsirItemStatus.available,
        ),
    ];
    if (items.isEmpty) return const [_plannedIbnKathir];
    return items;
  }

  Future<void> _selectInstalled(String slug) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final installed = await _repository.installed();
    final installedSlugs = {for (final resource in installed) resource.slug};
    final current = (_selectedTafsirSlugs() ?? installedSlugs.toList()).toSet();
    if (current.contains(slug)) return;
    current.add(slug);
    await prefs.setStringList(_kSelectedTafsir, current.toList());
  }

  Future<void> _deselectRemoved(String slug) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final current = _selectedTafsirSlugs();
    if (current == null || !current.contains(slug)) return;
    await prefs.setStringList(_kSelectedTafsir, [
      for (final s in current)
        if (s != slug) s,
    ]);
  }

  List<String>? _selectedTafsirSlugs() => _prefs?.getStringList(
        _kSelectedTafsir,
      );
}

const _plannedIbnKathir = TafsirItem(
  slug: 'en-ibn-kathir-abridged',
  status: TafsirItemStatus.unavailable,
  plannedName: 'Tafsir Ibn Kathir',
  plannedSubtitle: 'English abridged edition',
);
