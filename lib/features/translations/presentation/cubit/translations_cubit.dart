import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../reader/domain/entities/translation_resource.dart';
import '../../domain/entities/catalogue_entry.dart';
import '../../domain/entities/installed_edition.dart';
import '../../domain/repositories/edition_repository.dart';

/// One row on the Translations screen: an edition and what can be done with it.
class EditionItem extends Equatable {
  const EditionItem({
    required this.slug,
    required this.languageCode,
    required this.name,
    required this.state,
    this.languageLabel = '',
    this.author,
    this.license,
    this.sourceUrl,
    this.bytes = 0,
    this.progress,
    this.error,
  });

  final String slug;
  final String languageCode;
  final String languageLabel;
  final String name;
  final String? author;
  final String? license;
  final String? sourceUrl;

  /// Download size for an available edition; on-disk size once installed.
  final int bytes;
  final EditionState state;

  /// 0..1 while downloading.
  final double? progress;
  final String? error;

  EditionItem copyWith({
    EditionState? state,
    double? progress,
    String? error,
    bool clearError = false,
  }) =>
      EditionItem(
        slug: slug,
        languageCode: languageCode,
        languageLabel: languageLabel,
        name: name,
        author: author,
        license: license,
        sourceUrl: sourceUrl,
        bytes: bytes,
        state: state ?? this.state,
        progress: progress,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [slug, state, progress, error, bytes];
}

enum EditionState {
  /// Ships inside the app. Cannot be removed — there is no download to undo,
  /// and removing it would leave nothing to read.
  bundled,
  installed,
  available,
  downloading,
  failed,
}

class TranslationsState extends Equatable {
  const TranslationsState({
    this.items = const [],
    this.loading = true,
    this.catalogueUnavailable = false,
    this.error,
  });

  final List<EditionItem> items;
  final bool loading;

  /// True when the remote catalogue could not be reached AND nothing was
  /// cached. The screen still lists bundled and installed editions — being
  /// offline must not make the reader's own translations disappear.
  final bool catalogueUnavailable;
  final String? error;

  Map<String, List<EditionItem>> get byLanguage {
    final out = <String, List<EditionItem>>{};
    for (final i in items) {
      (out[i.languageCode] ??= []).add(i);
    }
    return out;
  }

  TranslationsState copyWith({
    List<EditionItem>? items,
    bool? loading,
    bool? catalogueUnavailable,
    String? error,
    bool clearError = false,
  }) =>
      TranslationsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        catalogueUnavailable: catalogueUnavailable ?? this.catalogueUnavailable,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [items, loading, catalogueUnavailable, error];
}

class TranslationsCubit extends Cubit<TranslationsState> {
  TranslationsCubit(this._repo, this._bundled)
      : super(const TranslationsState());

  final EditionRepository _repo;

  /// Editions compiled into the app. Listed but never removable.
  final List<TranslationResource> _bundled;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));

    List<InstalledEdition> installed = const [];
    try {
      installed = await _repo.installed();
    } catch (_) {
      // A local read failing is unexpected; show the bundled set rather than
      // an empty screen.
    }

    var unavailable = false;
    List<CatalogueEntry> available = const [];
    try {
      available = (await _repo.catalogue()).editions;
    } on EditionDownloadException {
      // Offline with no cache. Not an error state for the screen — the reader's
      // own editions are all still here and usable.
      unavailable = true;
    }

    final installedSlugs = {for (final e in installed) e.slug};
    final bundledSlugs = {for (final r in _bundled) r.slug};

    final items = <EditionItem>[
      for (final r in _bundled)
        EditionItem(
          slug: r.slug,
          languageCode: r.languageCode,
          languageLabel: r.languageLabel,
          name: r.name,
          author: r.author,
          license: r.license,
          sourceUrl: r.sourceUrl,
          state: EditionState.bundled,
        ),
      for (final e in installed)
        EditionItem(
          slug: e.slug,
          languageCode: e.languageCode,
          languageLabel: e.nativeName ?? e.languageCode,
          name: e.name,
          author: e.author,
          license: e.license,
          sourceUrl: e.sourceUrl,
          bytes: e.bytes,
          state: EditionState.installed,
        ),
      for (final c in available)
        // Skip anything already present, from either source, so an edition
        // never appears twice with contradictory actions.
        if (!installedSlugs.contains(c.slug) && !bundledSlugs.contains(c.slug))
          EditionItem(
            slug: c.slug,
            languageCode: c.languageCode,
            languageLabel: c.languageLabel,
            name: c.name,
            author: c.author,
            license: c.license,
            sourceUrl: c.sourceUrl,
            bytes: c.bytes,
            state: EditionState.available,
          ),
    ];

    _catalogue = {for (final c in available) c.slug: c};
    emit(
      TranslationsState(
        items: items,
        loading: false,
        catalogueUnavailable: unavailable,
      ),
    );
  }

  Map<String, CatalogueEntry> _catalogue = const {};

  Future<void> install(String slug) async {
    final entry = _catalogue[slug];
    if (entry == null) return;

    _update(
      slug,
      (i) => i.copyWith(
        state: EditionState.downloading,
        progress: 0,
        clearError: true,
      ),
    );
    try {
      await _repo.install(
        entry,
        onProgress: (p) => _update(
          slug,
          (i) => i.copyWith(state: EditionState.downloading, progress: p),
        ),
      );
      await load();
    } on EditionIntegrityException catch (e) {
      // Say plainly that the file did not match, rather than offering a retry
      // that looks like a flaky network. This is a corrupted or wrong artifact.
      _update(
        slug,
        (i) => i.copyWith(
          state: EditionState.failed,
          error: 'The download did not match its checksum and was discarded.',
        ),
      );
      addError(e);
    } catch (e) {
      _update(
        slug,
        (i) => i.copyWith(
          state: EditionState.failed,
          error: 'Download failed. Check your connection and try again.',
        ),
      );
      addError(e);
    }
  }

  Future<void> remove(String slug) async {
    await _repo.remove(slug);
    await load();
  }

  void _update(String slug, EditionItem Function(EditionItem) f) {
    if (isClosed) return;
    emit(
      state.copyWith(
        items: [
          for (final i in state.items)
            if (i.slug == slug) f(i) else i,
        ],
      ),
    );
  }
}
