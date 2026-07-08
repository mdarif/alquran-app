import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ayah_share.dart' show nativeLanguageName;
import '../../domain/entities/arabic_script.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../../../core/theme/theme_toggle_button.dart';
import '../../domain/reader_navigation.dart';
import '../../domain/repositories/reader_settings_repository.dart';
import '../cubit/ayah_audio_cubit.dart';
import '../cubit/reader_cubit.dart';
import '../widgets/ayah_tile.dart';
import '../widgets/mushaf_view.dart';
import '../widgets/scroll_to_top_button.dart';
import '../widgets/translation_chip.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({
    required this.target,
    this.focusAyahId,
    this.initialDetailed = false,
    super.key,
  });

  final ReaderTarget target;

  /// Global ayah id to scroll to on open (from "Last Read"); null starts at top.
  final int? focusAyahId;

  /// Open in Detailed view rather than Reading. Used by "Last Read" to resume in
  /// the same viewport the reader left off in; a fresh open from the index leaves
  /// this false (always Reading).
  final bool initialDetailed;

  @override
  Widget build(BuildContext context) {
    final view = _ReaderView(
      initialTarget: target,
      focusAyahId: focusAyahId,
      initialDetailed: initialDetailed,
    );
    // The audio cubit rides alongside the reader cubit only when the feature is
    // on; it's a per-screen factory, so leaving the reader closes it (which stops
    // playback). Flag off → single provider, identical to before.
    if (FeatureFlags.audioRecitation) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => GetIt.I<ReaderCubit>()..load(target)),
          BlocProvider(create: (_) => GetIt.I<AyahAudioCubit>()),
        ],
        child: view,
      );
    }
    return BlocProvider(
      create: (_) => GetIt.I<ReaderCubit>()..load(target),
      child: view,
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({
    required this.initialTarget,
    this.focusAyahId,
    this.initialDetailed = false,
  });

  final ReaderTarget initialTarget;
  final int? focusAyahId;
  final bool initialDetailed;

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

/// Dual viewport (PRD 3 / 4.3): Reading = Arabic-only Mushaf flow;
/// Detailed = Arabic stacked over Urdu + Hindi translations.
enum _Viewport { reading, detailed }

class _ReaderViewState extends State<_ReaderView> {
  // Pinch-to-zoom font scaling is an accessibility requirement (PRD 4.1).
  // Bounds target 20–48pt; tune on-device.
  static const double _minFont = 20;
  static const double _maxFont = 48;

  // Reading preferences persist across launches (zoom + viewport).
  final ReaderSettingsRepository _settings =
      GetIt.I<ReaderSettingsRepository>();

  // Cached so it can be used without a context lookup — notably from
  // _onVisibleAyah, which the Detailed list invokes from its dispose() (a
  // resume-point flush). An ancestor lookup there is illegal ("deactivated
  // widget's ancestor is unsafe"), so we hold the reference instead.
  late final ReaderCubit _cubit;

  // The active viewport registers its position-flush here so _setDetailed()
  // can capture the exact current verse synchronously — before the debounce
  // timer fires — ensuring a viewport toggle never loses your place.
  VoidCallback? _flushCurrentPosition;

  late double _arabicFont = _settings.fontSize.clamp(_minFont, _maxFont);

  // The currently displayed section. Swiping moves it to an adjacent section
  // (next/previous) within the same dimension, keeping font/viewport state.
  late ReaderTarget _target = widget.initialTarget;

  // The verse to scroll to on open ("Last Read" resume). Consumed by the first
  // section's viewport; cleared once we navigate away so swiped sections start
  // at the top.
  late int? _focusAyahId = widget.focusAyahId;

  // A fresh open (from the index) always starts in Reading (Mushaf) — the calm,
  // Arabic-only default. "Last Read" instead resumes in the viewport the reader
  // left off in (widget.initialDetailed), so Reading stays Reading and Detailed
  // stays Detailed.
  late _Viewport _viewport =
      widget.initialDetailed ? _Viewport.detailed : _Viewport.reading;

  // The Arabic script the reader renders the ayah text in. The toggle only
  // appears while FeatureFlags.indopakScript is on; persisted across launches.
  late ArabicScript _script = _settings.script;
  TextStyle get _arabicStyle => _script == ArabicScript.indopak
      ? QuranTextStyle.indopak
      : QuranTextStyle.madani;

  // The reader's chosen translation editions, shared by the Reading peek and the
  // Detailed view (set once, honoured in both). null = not yet chosen → resolved
  // to a sensible default. Restored from settings so it survives restarts.
  late Set<String>? _selected = _settings.selectedTranslations?.toSet();

  // Whether the Reading peek card shows the translation (+ its language chips).
  // Collapsible from the peek so the reader can read/listen to the Arabic alone;
  // persisted like the other reading prefs, so it holds across verses + launches.
  // Reading-only — Detailed is the translation view and ignores this.
  late bool _readingTranslation = _settings.readingTranslationVisible;

  // Section paging is a standard PageView (one page per section in the active
  // dimension). It gives native finger-tracking, momentum and snap, and keeps
  // the neighbours mounted — so swiping is smooth and nothing remounts.
  late final PageController _pageController =
      PageController(initialPage: widget.initialTarget.value - 1);

  // Pinch-to-zoom rides on a raw Listener wrapping the PageView (it sees every
  // pointer, even though the PageView claims horizontal drags in the arena).
  // While two fingers are down the PageView is locked so a pinch never pans it.
  final Map<int, Offset> _pointers = {};
  double? _pinchBaseDistance;
  double _fontAtPinchStart = 28;
  bool _pageLocked = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ReaderCubit>();
    // Tell the cubit which viewport we opened in, so Last Read records it (this
    // runs before the cubit's first progress save, which is async).
    _cubit.setViewportDetailed(_viewport == _Viewport.detailed);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReading = _viewport == _Viewport.reading;
    return Scaffold(
      appBar: AppBar(
        title: Text(_target.title),
        actions: [
          // Reading ⇄ Detailed in one tap (icon shows the view you'll switch to).
          // The app-bar action set stays identical in both views so positions
          // never shift; translation languages live in the Settings sheet (below),
          // not here.
          IconButton(
            key: WidgetKeys.viewportToggle,
            tooltip: isReading ? 'Detailed view' : 'Reading view',
            icon: AppIcon(
              isReading ? AppIcons.viewDetailed : AppIcons.viewReading,
            ),
            onPressed: () => _setDetailed(isReading),
          ),
          if (FeatureFlags.lightOfDay) const ThemeToggleButton(),
          // Settings sits last (rightmost): reading size, Arabic font +
          // translation, in a bottom sheet. (Prayer times live on the Home bar,
          // so there's no indicator here — keeps the reader calm.)
          IconButton(
            key: WidgetKeys.settingsButton,
            tooltip: 'Settings',
            icon: const AppIcon(AppIcons.settings),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: BlocConsumer<ReaderCubit, ReaderState>(
          // Keep the audio cubit's verse order in sync with the section on
          // screen, so "play from here" can roll verse→verse to the surah end.
          // Guarded by the flag (the cubit only exists when audio is on).
          listenWhen: (a, b) =>
              FeatureFlags.audioRecitation && a.ayahs != b.ayahs,
          listener: (context, state) => context
              .read<AyahAudioCubit>()
              .setSequence([for (final a in state.ayahs) a.id]),
          builder: (context, state) {
            if (state.status == ReaderStatus.error) {
              return Center(child: Text(state.error ?? 'Failed to load'));
            }
            // Spinner only before the very first section loads.
            if (state.ayahs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            // One page per section in the active dimension. In Reading mode
            // the audio highlight rides on its own BlocBuilder so an audio
            // tick repaints the active page without extra plumbing.
            Widget pages(AyahAudioState? audio) => PageView.builder(
                  controller: _pageController,
                  physics:
                      _pageLocked ? const NeverScrollableScrollPhysics() : null,
                  // Only the on-screen section builds on open. Neighbour VERSES
                  // are still prefetched into the cubit cache (_prefetchNeighbours
                  // after every load), so the first swipe renders from memory in a
                  // single cheap frame (one virtualized Mushaf page) — we don't
                  // also pay two off-screen MushafView builds under the open slide.
                  allowImplicitScrolling: false,
                  itemCount: _target.dimension.count,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) => _sectionPage(i, state, audio),
                );
            // The tree shape must be IDENTICAL in both viewports: the
            // BlocBuilder wraps the PageView whenever audio is on, and
            // Detailed simply ignores the audio state. Branching on the
            // viewport here (Reading wrapped, Detailed bare) used to remount
            // the PageView on every toggle — the controller re-attached at its
            // initial page, silently jumping back to the surah the reader was
            // opened on (and to an endless spinner once that section had been
            // evicted from the cache after a long fling).
            return FeatureFlags.audioRecitation
                ? BlocBuilder<AyahAudioCubit, AyahAudioState>(
                    builder: (context, audio) =>
                        pages(isReading ? audio : null),
                  )
                : pages(null);
          },
        ),
      ),
    );
  }

  /// Builds the section for the current viewport. [interactive] true is the live
  /// page (wired to last-read, language toggles, audio); false is a peeking
  /// neighbour — wired to last-read / language toggles / audio only when it is
  /// the active page, so the off-screen pages stay inert and uniform (same
  /// widget type ⇒ the element is reused, not remounted, when a page activates).
  Widget _buildSection({
    required List<Ayah> ayahs,
    required Map<int, SurahHeading> headings,
    required List<TranslationResource> resources,
    required bool interactive,
    AyahAudioState? audio,
  }) {
    // Key by the section's first ayah so a new section starts at the top, while
    // a same-section rebuild preserves scroll position.
    final key = ValueKey(ayahs.first.id);
    final Widget view;
    if (_viewport == _Viewport.reading) {
      // No SelectionArea in Reading mode — it competes in the gesture arena and
      // swallows the taps needed for tap-to-peek translation.
      view = MushafView(
        key: key,
        ayahs: ayahs,
        headings: headings,
        arabicFontSize: _arabicFont,
        arabicStyle: _arabicStyle,
        resources: resources,
        focusAyahId: interactive ? _focusAyahId : null,
        onVisibleAyah: interactive ? _onVisibleAyah : null,
        selectedLanguages: _activeLangs(resources),
        onRegisterFlush:
            interactive ? (cb) => _flushCurrentPosition = cb : null,
        audioState: audio,
        onTogglePlay: interactive && audio != null
            ? (id) => context.read<AyahAudioCubit>().toggle(id)
            : null,
        onToggleLanguage:
            interactive ? (code) => _toggleLang(code, resources) : null,
        showTranslation: _readingTranslation,
        onToggleTranslation: interactive ? _toggleReadingTranslation : null,
      );
    } else {
      // Copy/share in Detailed is per-verse (the tile's ⋯ menu) — no
      // SelectionArea in either viewport, it steals gestures (taps in Reading,
      // horizontal swipes in Detailed); translation languages are chosen in
      // the Settings sheet.
      view = _DetailedList(
        key: key,
        ayahs: ayahs,
        resources: resources,
        enabledLanguages: _activeLangs(resources),
        headings: headings,
        arabicFontSize: _arabicFont,
        arabicStyle: _arabicStyle,
        focusAyahId: interactive ? _focusAyahId : null,
        onVisibleAyah: interactive ? _onVisibleAyah : null,
        onRegisterFlush:
            interactive ? (cb) => _flushCurrentPosition = cb : null,
      );
    }
    return view;
  }

  /// Builds the PageView page for section index [i] (0-based; value = i + 1) in
  /// the active dimension. Off-screen pages read their verses from the warm
  /// cache (the active section + its neighbours are always cached); the rare
  /// uncached page shows a spinner and warms itself for next time.
  Widget _sectionPage(int i, ReaderState state, AyahAudioState? audio) {
    final target = _targetForIndex(i);
    final ayahs = _cubit.cachedAyahs(target);
    if (ayahs == null || ayahs.isEmpty) {
      _cubit.warm(target);
      return const Center(child: CircularProgressIndicator());
    }
    final active = i == _target.value - 1;
    return _buildSection(
      ayahs: ayahs,
      headings: state.headings,
      resources: state.resources,
      interactive: active,
      audio: active ? audio : null,
    );
  }

  /// The [ReaderTarget] for page index [i] in the open dimension.
  ReaderTarget _targetForIndex(int i) {
    final value = i + 1;
    final headings = _cubit.state.headings;
    return switch (_target.dimension) {
      ReaderDimension.surah => ReaderTarget.surah(
          value,
          headings[value]?.nameEnglish ?? 'Surah $value',
        ),
      ReaderDimension.juz => ReaderTarget.juz(value),
      ReaderDimension.hizb => ReaderTarget.hizb(value),
      ReaderDimension.page => ReaderTarget.page(value),
      ReaderDimension.ruku => ReaderTarget.ruku(value),
    };
  }

  /// The PageView settled on a new section: retitle the bar, stop any audio from
  /// the section we left, and load the new one (records Last Read + warms its
  /// neighbours). A warm cache hit is synchronous, so there's no flash.
  void _onPageChanged(int i) {
    final next = _targetForIndex(i);
    if (next == _target) return;
    if (FeatureFlags.audioRecitation) {
      context.read<AyahAudioCubit>().stopAll();
    }
    setState(() {
      _target = next;
      _focusAyahId = null; // a swiped-to section opens at its top, not a resume
    });
    _cubit.load(next);
  }

  /// The viewport reports its topmost-visible verse (on scroll-idle); record it
  /// so "Last Read" resumes exactly here.
  void _onVisibleAyah(Ayah ayah) {
    // Advance the resume target to the live position. This is what the *next*
    // viewport built (on a Reading⇄Detailed toggle) homes to — so a toggle keeps
    // your place instead of snapping back to the original open/resume verse.
    // Deliberately no setState: the value is only read when a build next runs,
    // and re-passing it to the current viewport is inert (focus-scroll runs only
    // in initState), so this never re-homes the view you're already reading.
    _focusAyahId = ayah.id;
    _cubit.saveProgress(ayah);
  }

  // --- Pinch-to-zoom (two-finger) -------------------------------------------
  // The PageView handles horizontal paging; this raw Listener handles only the
  // two-finger pinch, and locks the PageView while two fingers are down so a
  // pinch never doubles as a page swipe.

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _pinchBaseDistance = _pointerDistance();
      _fontAtPinchStart = _arabicFont;
      if (!_pageLocked) setState(() => _pageLocked = true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final base = _pinchBaseDistance;
    if (_pointers.length == 2 && base != null && base > 0) {
      _setFont(_fontAtPinchStart * (_pointerDistance() / base));
    }
  }

  void _onPointerEnd(PointerEvent event) {
    final wasPinching = _pointers.length == 2;
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchBaseDistance = null;
    if (wasPinching) {
      // A finger lifted out of a pinch — persist the final zoom level.
      unawaited(_settings.setFontSize(_arabicFont));
    }
    if (_pointers.isEmpty && _pageLocked) {
      setState(() => _pageLocked = false);
    }
  }

  double _pointerDistance() {
    final points = _pointers.values.toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  // --------------------------------------------------------------------------

  /// Opens the Settings bottom sheet (reading size, Arabic font, translations).
  /// Changes apply live to the verses behind the sheet and persist, via
  /// _applyFont / _applyScript / _toggleLang.
  void _openSettingsSheet() {
    final resources = _cubit.state.resources;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SettingsSheet(
        fontSize: _arabicFont,
        minFont: _minFont,
        maxFont: _maxFont,
        onFontChanged: _applyFont,
        script: _script,
        onScriptChanged: _applyScript,
        resources: resources,
        selectedLanguages: _activeLangs(resources),
        onToggleLanguage: (code) => _toggleLang(code, resources),
      ),
    );
  }

  void _setDetailed(bool detailed) {
    // Capture the current reading position from the active viewport NOW —
    // before setState tears it down. This updates _focusAyahId synchronously
    // so the incoming viewport homes to the exact verse, not a stale debounce.
    _flushCurrentPosition?.call();
    // While a recitation is sounding, the reading position IS the verse being
    // recited — home the incoming viewport to it, overriding the flushed scroll
    // position. Reading follows the reciter only a Mushaf-PAGE at a time (and the
    // reader may have scrolled ahead to read while listening), so that flushed
    // top can be several verses from the verse actually playing; without this the
    // new viewport opens on a stale verse and doesn't catch up until the reciter
    // rolls into the next one. Only while SOUNDING (playing/buffering) — a
    // paused/idle reader is browsing and should keep wherever they scrolled to.
    if (FeatureFlags.audioRecitation) {
      final audio = context.read<AyahAudioCubit>().state;
      if (audio.isSounding && audio.playingAyahId != null) {
        _focusAyahId = audio.playingAyahId;
      }
    }
    // Session-only toggle: the choice holds while this reader is open (including
    // across swipes) but is intentionally NOT persisted as the open default — a
    // fresh open always starts in Reading. It IS recorded on the Last Read point
    // though, so resuming returns to the view you were last in.
    setState(() {
      _viewport = detailed ? _Viewport.detailed : _Viewport.reading;
    });
    _cubit.setViewportDetailed(detailed);
  }

  /// The reader's active translation editions — shared by the Reading peek and
  /// Detailed view. The saved selection (validated against what's available),
  /// or a sensible default when nothing is saved: a SINGLE language — Urdu (the
  /// flagship translation), regardless of device language, per owner decision;
  /// only as a last resort (no Urdu edition) the first available edition.
  Set<String> _activeLangs(List<TranslationResource> all) {
    final available = [for (final r in all) r.languageCode];
    if (available.isEmpty) return {};
    final saved = _selected;
    if (saved != null) {
      final valid = saved.where(available.contains).toSet();
      if (valid.isNotEmpty) return valid;
    }
    if (available.contains('ur')) return {'ur'};
    return {available.first};
  }

  /// Toggle a language in the shared selection, keeping at least one on, and
  /// persist it (so both views and a future launch see the same choice).
  void _toggleLang(String code, List<TranslationResource> all) {
    final current = {..._activeLangs(all)};
    if (current.contains(code)) {
      if (current.length <= 1) return; // never hide the last translation
      current.remove(code);
    } else {
      current.add(code);
    }
    setState(() => _selected = current);
    unawaited(_settings.setSelectedTranslations(current.toList()));
  }

  /// Show/hide the Reading peek card's translation (collapse to read/listen to
  /// the Arabic alone); persisted so it holds across verses and launches.
  void _toggleReadingTranslation() {
    setState(() => _readingTranslation = !_readingTranslation);
    unawaited(_settings.setReadingTranslationVisible(_readingTranslation));
  }

  /// Slider: set the zoom to an absolute value and persist it.
  void _applyFont(double value) {
    _setFont(value);
    unawaited(_settings.setFontSize(_arabicFont));
  }

  // Switch the Arabic script: persist it, drop the cached sections (they hold
  // the old column's text), then reload so the repo re-reads the matching
  // column. The current verse (_focusAyahId) is preserved when it reopens.
  void _applyScript(ArabicScript value) {
    if (value == _script) return;
    setState(() => _script = value);
    unawaited(_settings.setScript(value));
    _cubit.clearCache();
    _cubit.load(_target);
  }

  void _setFont(double value) {
    // Snap to whole points. Pinch-zoom feeds a *continuous* value on every
    // pointer-move; without snapping, each fractional change reshaped the entire
    // (up to 286-verse) Mushaf paragraph, so one pinch fired dozens of full
    // re-layouts — measured at build frames up to ~390ms on a long surah. Rounding
    // collapses those to a single reshape per 1pt crossing: imperceptible (the
    // size slider already steps in 2pt) but it removes the pinch stutter.
    final clamped = value.clamp(_minFont, _maxFont).roundToDouble();
    if (clamped != _arabicFont) setState(() => _arabicFont = clamped);
  }
}

/// Detailed viewport: a lazy list of ayah tiles, with a surah header inserted
/// wherever the section crosses into a new surah. Uses a positioned list so it
/// can scroll to the exact last-read verse (even when its tile isn't built yet)
/// and report the topmost-visible verse as the user scrolls.
class _DetailedList extends StatefulWidget {
  const _DetailedList({
    required this.ayahs,
    required this.resources,
    required this.enabledLanguages,
    required this.headings,
    required this.arabicFontSize,
    this.arabicStyle = QuranTextStyle.madani,
    this.focusAyahId,
    this.onVisibleAyah,
    this.onRegisterFlush,
    super.key,
  });

  final List<Ayah> ayahs;

  /// All available translation editions.
  final List<TranslationResource> resources;

  /// Which of [resources] are currently shown (the rest are filtered out);
  /// chosen in the Settings sheet.
  final Set<String> enabledLanguages;

  final Map<int, SurahHeading> headings;
  final double arabicFontSize;
  final TextStyle arabicStyle;
  final int? focusAyahId;
  final ValueChanged<Ayah>? onVisibleAyah;

  /// See [MushafView.onRegisterFlush] — same contract.
  final void Function(VoidCallback?)? onRegisterFlush;

  /// The editions actually rendered in each tile: the enabled ones, falling back
  /// to all if a stale saved selection matches nothing available.
  List<TranslationResource> get shownResources {
    final shown = [
      for (final r in resources)
        if (enabledLanguages.contains(r.languageCode)) r,
    ];
    return shown.isEmpty ? resources : shown;
  }

  @override
  State<_DetailedList> createState() => _DetailedListState();
}

class _DetailedListState extends State<_DetailedList> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();

  final List<Object> _rows =
      []; // rebuilt on a same-section reload (script switch)
  final Map<int, int> _ayahRowIndex = {}; // ayah id -> row index

  Timer? _reportTimer;
  Timer? _highlightTimer;
  int? _highlightAyahId;

  // The verse we resumed to (Last Read). While set, Last Read stays pinned here
  // so the post-scroll report never drifts it to the verse that ended up at the
  // top. Cleared the moment the reader scrolls (see the NotificationListener).
  int? _heldFocusId;

  // "Back to top" appears once the list is roughly a screen deep.
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _buildRows();
    _positions.itemPositions.addListener(_onPositions);
    final id = widget.focusAyahId;
    if (id != null && _ayahRowIndex.containsKey(id)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToFocus(id, resume: true));
    }
    widget.onRegisterFlush?.call(_reportTopmost);
  }

  @override
  void didUpdateWidget(_DetailedList old) {
    super.didUpdateWidget(old);
    // A same-section reload (a script switch reloads the SAME verses in a new
    // face — same widget key, so didUpdateWidget fires rather than a fresh
    // initState) must rebuild the flattened rows, or the tiles keep rendering
    // the old script's text. The index map stays parallel, so the
    // ScrollablePositionedList holds position across the reload.
    if (widget.ayahs != old.ayahs) _buildRows();
  }

  @override
  void dispose() {
    widget.onRegisterFlush?.call(null);
    // Flush the resume point before tearing down: a pending debounce timer is
    // about to be cancelled, so without this a quick pop (back-button mid-scroll,
    // within the 400ms window) would lose the final position and Last Read would
    // resume at a stale earlier verse.
    _reportTopmost();
    _reportTimer?.cancel();
    _highlightTimer?.cancel();
    _positions.itemPositions.removeListener(_onPositions);
    super.dispose();
  }

  void _buildRows() {
    // Flatten into header/ayah rows so the list stays lazy. A header marks each
    // surah boundary, and notes whether the Basmala should precede it (shown for
    // every surah except Al-Fatihah — where it is ayah 1 — and At-Tawbah).
    _rows.clear();
    _ayahRowIndex.clear();
    int? lastSurah;
    for (final ayah in widget.ayahs) {
      if (ayah.surahId != lastSurah) {
        _rows.add(
          _HeaderMarker(
            surahId: ayah.surahId,
            showBismillah:
                ayah.ayahNumber == 1 && ayah.surahId != 1 && ayah.surahId != 9,
          ),
        );
        lastSurah = ayah.surahId;
      }
      _ayahRowIndex[ayah.id] = _rows.length;
      _rows.add(ayah);
    }
  }

  void _scrollToFocus(int ayahId, {bool resume = false}) {
    // A resume pins Last Read to this verse and records it now (so it holds even
    // if the list can't scroll there); the reciter-follow scroll releases it.
    if (resume) {
      _heldFocusId = ayahId;
      final onVisible = widget.onVisibleAyah;
      if (onVisible != null) {
        final ayah = widget.ayahs.firstWhere(
          (a) => a.id == ayahId,
          orElse: () => widget.ayahs.first,
        );
        onVisible(ayah);
      }
    } else {
      _heldFocusId = null;
    }
    if (!mounted || !_scrollController.isAttached) return;
    final idx = _ayahRowIndex[ayahId];
    if (idx == null) return;
    _scrollController.scrollTo(
      index: idx,
      alignment: 0.06,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    _flash(ayahId);
  }

  void _flash(int ayahId) {
    setState(() => _highlightAyahId = ayahId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightAyahId = null);
    });
  }

  void _onPositions() {
    // "Back to top" visibility tracks live (cheap), but the resume-point report
    // is debounced until scrolling settles.
    _updateShowTop();
    _reportTimer?.cancel();
    _reportTimer = Timer(const Duration(milliseconds: 400), _reportTopmost);
  }

  void _updateShowTop() {
    final positions = _positions.itemPositions.value;
    bool showTop;
    if (positions.isEmpty) {
      showTop = false;
    } else {
      // Find the first row (index 0). Show the button once it has scrolled
      // roughly one viewport above the top, or is gone from view entirely.
      ItemPosition? first;
      for (final p in positions) {
        if (p.index == 0) {
          first = p;
          break;
        }
      }
      showTop = first == null || first.itemLeadingEdge < -1.0;
    }
    if (showTop != _showTop) setState(() => _showTop = showTop);
  }

  void _scrollToTop() {
    if (!_scrollController.isAttached) return;
    _scrollController.scrollTo(
      index: 0,
      alignment: 0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _reportTopmost() {
    final onVisible = widget.onVisibleAyah;
    if (onVisible == null) return;
    // While a resume verse is pinned, keep Last Read there (don't drift to the
    // verse that happened to land at the top after the programmatic scroll).
    final held = _heldFocusId;
    if (held != null) {
      onVisible(
        widget.ayahs.firstWhere(
          (a) => a.id == held,
          orElse: () => widget.ayahs.first,
        ),
      );
      return;
    }
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1);
    if (visible.isEmpty) return;
    final top = visible
        .reduce((a, b) => a.itemLeadingEdge <= b.itemLeadingEdge ? a : b);
    // The verse being read at the top is this row, or the next ayah row if the
    // topmost item is a surah header.
    for (var i = top.index; i < _rows.length; i++) {
      final row = _rows[i];
      if (row is Ayah) {
        onVisible(row);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Translation languages are chosen in the Settings sheet now, so the view is
    // just the verses — no top strip.
    final content = Stack(
      children: [
        // A finger-driven scroll (dragDetails set) releases the resume pin so
        // reporting tracks the top again; the programmatic scroll-to-focus and
        // reciter-follow scrolls carry no dragDetails.
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _heldFocusId = null;
            }
            return false;
          },
          // No SelectionArea here (mirrors Reading): on Android its touch
          // recognizer claims horizontal drags with EAGER victory
          // (SelectableRegion.eagerVictoryOnDrag), so swipes over the verses
          // selected text instead of turning the PageView's page — Detailed
          // couldn't be swiped at all. Copy/share stays available per verse
          // via the tile's ⋯ menu.
          child: ScrollablePositionedList.builder(
            itemScrollController: _scrollController,
            itemPositionsListener: _positions,
            itemCount: _rows.length,
            itemBuilder: _buildRow,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: ScrollToTopButton(
            visible: _showTop,
            onPressed: _scrollToTop,
          ),
        ),
      ],
    );
    // During continuous recitation, keep the now-playing verse in view as it
    // advances (the tile self-tints via `isActive`; this just scrolls). Listen
    // only — no list rebuild. Off-flag the cubit isn't provided, so skip it.
    if (!FeatureFlags.audioRecitation) return content;
    return BlocListener<AyahAudioCubit, AyahAudioState>(
      listenWhen: (a, b) => a.playingAyahId != b.playingAyahId,
      listener: (_, state) {
        final id = state.playingAyahId;
        if (id != null) _scrollToFocus(id);
      },
      child: content,
    );
  }

  Widget _ayahTile(BuildContext context, Ayah ayah, AyahAudioState? audio) {
    return AyahTile(
      ayah: ayah,
      resources: widget.shownResources,
      arabicFontSize: widget.arabicFontSize,
      arabicStyle: widget.arabicStyle,
      surahName: widget.headings[ayah.surahId]?.nameEnglish,
      highlight: _highlightAyahId == ayah.id,
      audioState: audio,
      onTogglePlay: audio == null
          ? null
          : () => context.read<AyahAudioCubit>().toggle(ayah.id),
    );
  }

  Widget _buildRow(BuildContext context, int i) {
    final row = _rows[i];
    if (row is _HeaderMarker) {
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, i == 0 ? 12 : 20, 16, 4),
            child: SurahHeaderCard(
              heading: widget.headings[row.surahId],
              fallbackNumber: row.surahId,
              fontSize: widget.arabicFontSize,
            ),
          ),
          if (row.showBismillah)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Bismillah(fontSize: widget.arabicFontSize),
            ),
        ],
      );
    }
    final ayah = row as Ayah;
    // Under the audio flag each tile rebuilds on its own audio state (cheap,
    // per-tile); off-flag it builds exactly as before.
    final Widget tile = FeatureFlags.audioRecitation
        ? BlocBuilder<AyahAudioCubit, AyahAudioState>(
            builder: (context, audio) => _ayahTile(context, ayah, audio),
          )
        : _ayahTile(context, ayah, null);
    // A light hairline separates consecutive verses. It's omitted after the
    // last verse (nothing follows) and before a surah header (the chapter
    // header is its own separator).
    final nextIsAyah = i + 1 < _rows.length && _rows[i + 1] is Ayah;
    if (!nextIsAyah) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          // A whisper-soft hairline: just enough to separate verses without
          // drawing the eye. `outlineVariant` (already a muted hairline tone) at
          // low alpha keeps it barely-there on the warm page.
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

class _HeaderMarker {
  const _HeaderMarker({required this.surahId, required this.showBismillah});
  final int surahId;
  final bool showBismillah;
}

// Script preview samples — the Bismillah in each script's own encoding, copied
// verbatim from Al-Fatihah:1 in the bundled quran.db (text_arabic_uthmani /
// text_arabic_indopak) rather than hand-typed, so the IndoPak form renders cleanly
// in Noorehuda (validated to 0 .notdef). They differ by design — e.g. Uthmani
// writes "ٱللَّه" with the waṣla alif (U+0671), IndoPak "اللّٰه" with a plain
// alif + explicit shadda/dagger-alef (Noorehuda draws no marks of its own).
const String _uthmaniSample = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';
const String _indopakSample = 'بِسۡمِ اللّٰهِ الرَّحۡمٰنِ الرَّحِيۡمِ';

/// The reader's "Settings" bottom sheet: reading size, Arabic font + translation.
/// Stateful so
/// the slider thumb and selected card update instantly; every change is also
/// forwarded to the reader (onFontChanged / onScriptChanged) so the verses reflow
/// live behind the sheet and the choice persists. Matches the app's other modal
/// sheets (drag handle + SafeArea + titleMedium header).
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.fontSize,
    required this.minFont,
    required this.maxFont,
    required this.onFontChanged,
    required this.script,
    required this.onScriptChanged,
    required this.resources,
    required this.selectedLanguages,
    required this.onToggleLanguage,
  });

  final double fontSize;
  final double minFont;
  final double maxFont;
  final ValueChanged<double> onFontChanged;
  final ArabicScript script;
  final ValueChanged<ArabicScript> onScriptChanged;
  final List<TranslationResource> resources;
  final Set<String> selectedLanguages;
  final ValueChanged<String> onToggleLanguage;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  // One size step — matches the slider's 2pt divisions and the size grid.
  static const double _step = 2;

  late double _fontSize = widget.fontSize;
  late ArabicScript _script = widget.script;
  late Set<String> _selectedLangs = {...widget.selectedLanguages};

  void _setFont(double value) {
    final v = value.clamp(widget.minFont, widget.maxFont).roundToDouble();
    if (v == _fontSize) return;
    setState(() => _fontSize = v);
    widget.onFontChanged(v); // reflow the verses behind the sheet + persist
  }

  void _setScript(ArabicScript value) {
    if (value == _script) return;
    setState(() => _script = value);
    widget.onScriptChanged(value); // reload behind the sheet + persist
  }

  void _toggleLang(String code) {
    final next = {..._selectedLangs};
    if (next.contains(code)) {
      if (next.length <= 1) return; // never hide the last translation
      next.remove(code);
    } else {
      next.add(code);
    }
    setState(() => _selectedLangs = next);
    widget
        .onToggleLanguage(code); // re-render verses behind the sheet + persist
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Settings', style: theme.textTheme.titleMedium),
              const SizedBox(height: 18),
              // Text size — header with a live point readout on the right.
              _SectionLabel(
                'Text size',
                trailing: Text(
                  '${_fontSize.round()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Live preview (above the slider) — the current Arabic face at the
              // chosen size. Fixed height so dragging the slider never reflows the
              // sheet; the line is RTL-aligned and clips on the left at the largest
              // sizes (you still see the true size, not a scaled-to-fit one).
              Container(
                key: WidgetKeys.textSizePreview,
                height: 72,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _script == ArabicScript.indopak
                      ? _indopakSample
                      : _uthmaniSample,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textDirection: TextDirection.rtl,
                  locale: const Locale('ar'),
                  style: (_script == ArabicScript.indopak
                          ? QuranTextStyle.indopak
                          : QuranTextStyle.madani)
                      .copyWith(fontSize: _fontSize),
                ),
              ),
              const SizedBox(height: 10),
              // A− / A+ steppers flank the slider (each nudges one grid step).
              Row(
                children: [
                  _StepButton(
                    key: WidgetKeys.fontDecrease,
                    glyphSize: 14,
                    tooltip: 'Smaller text',
                    onPressed: _fontSize > widget.minFont
                        ? () => _setFont(_fontSize - _step)
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _fontSize.clamp(widget.minFont, widget.maxFont),
                      min: widget.minFont,
                      max: widget.maxFont,
                      divisions:
                          ((widget.maxFont - widget.minFont) / _step).round(),
                      semanticFormatterCallback: (v) => '${v.round()} points',
                      onChanged: _setFont,
                    ),
                  ),
                  _StepButton(
                    key: WidgetKeys.fontIncrease,
                    glyphSize: 22,
                    tooltip: 'Larger text',
                    onPressed: _fontSize < widget.maxFont
                        ? () => _setFont(_fontSize + _step)
                        : null,
                  ),
                ],
              ),
              // Arabic script — only while the IndoPak feature is enabled.
              if (FeatureFlags.indopakScript) ...[
                const SizedBox(height: 18),
                const _SectionLabel('Arabic Script'),
                const SizedBox(height: 2),
                Column(
                  key: WidgetKeys.scriptToggle,
                  children: [
                    _ScriptPreview(
                      script: ArabicScript.uthmani,
                      label: 'Uthmani/Madani',
                      description: 'Madinah Mushaf',
                      sample: _uthmaniSample,
                      sampleStyle: QuranTextStyle.madani,
                      selected: _script == ArabicScript.uthmani,
                      onTap: () => _setScript(ArabicScript.uthmani),
                    ),
                    const Divider(height: 1),
                    _ScriptPreview(
                      script: ArabicScript.indopak,
                      label: 'IndoPak/Asian',
                      description: 'South-Asian Naskh',
                      sample: _indopakSample,
                      sampleStyle: QuranTextStyle.indopak,
                      selected: _script == ArabicScript.indopak,
                      onTap: () => _setScript(ArabicScript.indopak),
                    ),
                  ],
                ),
              ],
              if (widget.resources.length > 1) ...[
                const SizedBox(height: 18),
                const _SectionLabel('Translation'),
                const SizedBox(height: 10),
                // The same constant-width pills as the Reading peek card, so the
                // row never reflows ("jumps") when you toggle a language. The
                // parent keeps at least one translation on.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in widget.resources)
                      TranslationChip(
                        key: WidgetKeys.langOption(r.languageCode),
                        label: nativeLanguageName(r.languageCode),
                        selected: _selectedLangs.contains(r.languageCode),
                        onTap: () => _toggleLang(r.languageCode),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A round tap target showing a small/large "A" — the size-step affordance beside
/// the slider. Dimmed and inert at the size bounds ([onPressed] null).
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.glyphSize,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final double glyphSize;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Text(
        'A',
        style: TextStyle(
          fontSize: glyphSize,
          fontWeight: FontWeight.w600,
          color: onPressed == null
              ? cs.onSurface.withValues(alpha: 0.3)
              : cs.onSurface,
        ),
      ),
    );
  }
}

/// A full-width selectable row previewing an Arabic [script] in its real font
/// (the Bismillah) with the name + a one-line [description], so the
/// Uthmani↔IndoPak difference is large and each option explains itself.
/// Apple-style settings section header: small, UPPERCASE, muted, letter-spaced,
/// with an optional trailing widget (e.g. the live text-size readout).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// A typography preview of one Arabic face: the Bismillah specimen is the hero,
/// the face's name a quiet caption, and a checkmark marks the active one — no
/// card fill or border (Apple font-picker style).
class _ScriptPreview extends StatelessWidget {
  const _ScriptPreview({
    required this.script,
    required this.label,
    required this.description,
    required this.sample,
    required this.sampleStyle,
    required this.selected,
    required this.onTap,
  });

  final ArabicScript script;
  final String label;
  final String description;
  final String sample;
  final TextStyle sampleStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      selected: selected,
      child: InkWell(
        key: WidgetKeys.scriptCard(script.name),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // The specimen — full-strength, the hero of the row.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          sample,
                          textDirection: TextDirection.rtl,
                          locale: const Locale('ar'),
                          style: sampleStyle.copyWith(
                            fontSize: 28,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Fixed-width slot so the specimen never shifts.
                  SizedBox(
                    width: 22,
                    child: selected
                        ? Icon(Icons.check_rounded, size: 20, color: cs.primary)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: '  ·  $description'),
                  ],
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
