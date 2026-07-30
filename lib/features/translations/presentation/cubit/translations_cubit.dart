import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/translations/translation_metadata_overrides.dart';
import '../../../reader/domain/entities/translation_resource.dart';
import '../../../reader/domain/repositories/reader_settings_repository.dart';
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
    this.selected = false,
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
  final bool selected;

  /// 0..1 while downloading.
  final double? progress;
  final String? error;

  EditionItem copyWith({
    EditionState? state,
    bool? selected,
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
        selected: selected ?? this.selected,
        state: state ?? this.state,
        progress: progress,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [slug, state, selected, progress, error, bytes];
}

enum EditionState {
  /// Ships inside the app. Cannot be removed — there is no download to undo,
  /// and removing it would leave nothing to read.
  bundled,
  installed,
  updateAvailable,
  available,
  downloading,
  failed,
}

class TranslationsState extends Equatable {
  const TranslationsState({
    this.items = const [],
    this.loading = true,
    this.catalogueUnavailable = false,
    this.newSlugs = const {},
    this.error,
  });

  final List<EditionItem> items;
  final bool loading;

  /// True when the remote catalogue could not be reached AND nothing was
  /// cached. The screen still lists bundled and installed editions — being
  /// offline must not make the reader's own translations disappear.
  final bool catalogueUnavailable;

  /// Available-for-download slugs the reader hasn't opened this screen since
  /// seeing — cleared by [TranslationsCubit.markCatalogueSeen], never by
  /// [TranslationsCubit.load] itself (which also runs silently at launch and
  /// must not clear a badge the reader hasn't actually looked at).
  final Set<String> newSlugs;
  final String? error;

  bool get hasUnseenEditions => newSlugs.isNotEmpty;

  Map<String, List<EditionItem>> get byLanguage {
    final out = <String, List<EditionItem>>{};
    for (final i in items) {
      (out[i.languageCode] ??= []).add(i);
    }
    return out;
  }

  List<EditionItem> get downloaded => [
        for (final i in items)
          if (i.state == EditionState.bundled ||
              i.state == EditionState.installed ||
              i.state == EditionState.updateAvailable)
            i,
      ];

  List<EditionItem> get available => [
        for (final i in items)
          if (i.state == EditionState.available ||
              i.state == EditionState.downloading ||
              i.state == EditionState.failed)
            i,
      ];

  TranslationsState copyWith({
    List<EditionItem>? items,
    bool? loading,
    bool? catalogueUnavailable,
    Set<String>? newSlugs,
    String? error,
    bool clearError = false,
  }) =>
      TranslationsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        catalogueUnavailable: catalogueUnavailable ?? this.catalogueUnavailable,
        newSlugs: newSlugs ?? this.newSlugs,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props =>
      [items, loading, catalogueUnavailable, newSlugs, error];
}

class TranslationsCubit extends Cubit<TranslationsState> {
  TranslationsCubit(
    this._repo,
    this._bundled, {
    ReaderSettingsRepository? settings,
    SharedPreferences? prefs,
    VoidCallback? onTranslationsChanged,
  })  : _settings = settings,
        _prefs = prefs,
        _onTranslationsChanged = onTranslationsChanged,
        super(const TranslationsState());

  static const String _kSeenSlugs = 'translations_seen_slugs';

  final EditionRepository _repo;
  final ReaderSettingsRepository? _settings;
  final SharedPreferences? _prefs;
  final VoidCallback? _onTranslationsChanged;

  /// Editions compiled into the app. Listed but never removable.
  final List<TranslationResource> _bundled;

  /// Fires exactly on a real mutation (install/remove/toggle) — never on a
  /// routine [load], so a caller (e.g. the reader screen, re-opening this same
  /// shared cubit's sheet) can react only to an actual change, not to the
  /// background refresh that also calls [load] at launch.
  final StreamController<void> _mutations = StreamController<void>.broadcast();
  Stream<void> get mutations => _mutations.stream;

  @override
  Future<void> close() {
    unawaited(_mutations.close());
    return super.close();
  }

  void _notifyChanged() {
    _onTranslationsChanged?.call();
    _mutations.add(null);
  }

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

    final defaultBundledSlugs = {
      for (final r in _bundled)
        if (r.defaultOn) r.slug,
    };
    final selectedSlugs =
        (_settings?.selectedTranslations ?? defaultBundledSlugs.toList())
            .toSet();
    final installedSlugs = {for (final e in installed) e.slug};
    final catalogueBySlug = {for (final c in available) c.slug: c};

    final items = <EditionItem>[
      for (final r in _bundled)
        if (r.defaultOn)
          EditionItem(
            slug: r.slug,
            languageCode: r.languageCode,
            languageLabel: r.languageLabel,
            name: r.name,
            author: TranslationMetadataOverrides.author(r.slug, r.author),
            license: r.license,
            sourceUrl: r.sourceUrl,
            bytes: catalogueBySlug[r.slug]?.bytes ?? 0,
            selected: selectedSlugs.contains(r.slug),
            state: EditionState.bundled,
          ),
      for (final e in installed)
        _installedItem(e, catalogueBySlug[e.slug], selectedSlugs),
      for (final c in available)
        // Skip only what is already active on the device. Non-default bundled
        // editions are deliberately still presented as CDN downloads: future
        // seed DBs keep only Urdu bundled, and this keeps the UX model stable
        // while older/dev DBs still carry Hindi or English rows.
        if (!installedSlugs.contains(c.slug) &&
            !defaultBundledSlugs.contains(c.slug))
          EditionItem(
            slug: c.slug,
            languageCode: c.languageCode,
            languageLabel: c.languageLabel,
            name: c.name,
            author: TranslationMetadataOverrides.author(c.slug, c.author),
            license: c.license,
            sourceUrl: c.sourceUrl,
            bytes: c.bytes,
            state: EditionState.available,
          ),
    ];

    final seenSlugs = _prefs?.getStringList(_kSeenSlugs)?.toSet() ?? const {};
    final newSlugs = {
      for (final i in items)
        if (i.state == EditionState.available && !seenSlugs.contains(i.slug))
          i.slug,
    };

    _catalogue = catalogueBySlug;
    emit(
      TranslationsState(
        items: items,
        loading: false,
        catalogueUnavailable: unavailable,
        newSlugs: newSlugs,
      ),
    );
  }

  Map<String, CatalogueEntry> _catalogue = const {};

  /// Call when the Translations screen is actually opened, so the "new
  /// edition" badge clears the moment the reader sees the list — not merely
  /// because a silent background [load] happened to run.
  Future<void> markCatalogueSeen() async {
    final prefs = _prefs;
    if (prefs == null || state.newSlugs.isEmpty) return;
    final currentlyAvailable = {
      for (final i in state.items)
        if (i.state == EditionState.available) i.slug,
    };
    await prefs.setStringList(_kSeenSlugs, currentlyAvailable.toList());
    emit(state.copyWith(newSlugs: const {}));
  }

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
      await _selectInstalled(slug);
      _notifyChanged();
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
    await _deselectRemoved(slug);
    _notifyChanged();
    await load();
  }

  Future<bool> _selectInstalled(String slug) => _selectInstalledSlugs({slug});

  Future<void> toggleSelected(String slug) async {
    EditionItem? item;
    for (final i in state.items) {
      if (i.slug == slug) {
        item = i;
        break;
      }
    }
    if (item == null ||
        (item.state != EditionState.bundled &&
            item.state != EditionState.installed &&
            item.state != EditionState.updateAvailable)) {
      return;
    }
    final settings = _settings;
    if (settings == null) return;
    final defaults = [
      for (final r in _bundled)
        if (r.defaultOn) r.slug,
    ];
    final current = (settings.selectedTranslations ?? defaults).toSet();
    if (current.contains(slug)) {
      if (current.length == 1) return;
      current.remove(slug);
    } else {
      current.add(slug);
    }
    await settings.setSelectedTranslations(current.toList());
    _notifyChanged();
    _update(slug, (i) => i.copyWith(selected: current.contains(slug)));
  }

  EditionItem _installedItem(
    InstalledEdition edition,
    CatalogueEntry? catalogue,
    Set<String> selectedSlugs,
  ) {
    final updateAvailable = catalogue != null &&
        edition.sha256 != null &&
        edition.sha256 != catalogue.sha256;
    return EditionItem(
      slug: edition.slug,
      languageCode: edition.languageCode,
      languageLabel: edition.nativeName ?? edition.languageCode,
      name: edition.name,
      author: TranslationMetadataOverrides.author(edition.slug, edition.author),
      license: edition.license,
      sourceUrl: edition.sourceUrl,
      bytes: updateAvailable ? catalogue.bytes : edition.bytes,
      selected: selectedSlugs.contains(edition.slug),
      state: updateAvailable
          ? EditionState.updateAvailable
          : EditionState.installed,
    );
  }

  Future<bool> _selectInstalledSlugs(Set<String> slugs) async {
    final settings = _settings;
    if (settings == null) return false;
    final current = settings.selectedTranslations ??
        [
          for (final r in _bundled)
            if (r.defaultOn) r.slug,
        ];
    final missing = [
      for (final slug in slugs)
        if (!current.contains(slug)) slug,
    ];
    if (missing.isEmpty) return false;
    await settings.setSelectedTranslations([...current, ...missing]);
    return true;
  }

  Future<void> _deselectRemoved(String slug) async {
    final settings = _settings;
    if (settings == null) return;
    final current = settings.selectedTranslations;
    if (current == null || !current.contains(slug)) return;
    await settings.setSelectedTranslations([
      for (final s in current)
        if (s != slug) s,
    ]);
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
