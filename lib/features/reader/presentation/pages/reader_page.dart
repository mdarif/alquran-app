import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../../../core/theme/theme_toggle_button.dart';
import '../../domain/reader_navigation.dart';
import '../../domain/repositories/reader_settings_repository.dart';
import '../cubit/reader_cubit.dart';
import '../widgets/ayah_tile.dart';
import '../widgets/mushaf_view.dart';
import '../widgets/scroll_to_top_button.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({required this.target, this.focusAyahId, super.key});

  final ReaderTarget target;

  /// Global ayah id to scroll to on open (from "Last Read"); null starts at top.
  final int? focusAyahId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<ReaderCubit>()..load(target),
      child: _ReaderView(initialTarget: target, focusAyahId: focusAyahId),
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({required this.initialTarget, this.focusAyahId});

  final ReaderTarget initialTarget;
  final int? focusAyahId;

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

  late double _arabicFont = _settings.fontSize.clamp(_minFont, _maxFont);

  // The currently displayed section. Swiping moves it to an adjacent section
  // (next/previous) within the same dimension, keeping font/viewport state.
  late ReaderTarget _target = widget.initialTarget;

  // The verse to scroll to on open ("Last Read" resume). Consumed by the first
  // section's viewport; cleared once we navigate away so swiped sections start
  // at the top.
  late int? _focusAyahId = widget.focusAyahId;

  // Viewport preference (PRD lists Reading first), restored from settings.
  late _Viewport _viewport =
      _settings.detailed ? _Viewport.detailed : _Viewport.reading;

  // Whether the inline text-size slider is revealed (toggled by the "Aa" button).
  bool _showFontSlider = false;

  // Pinch + swipe are both handled through a raw Listener (not GestureDetector)
  // so they do NOT enter the gesture arena. This matters because SelectionArea
  // and the scroll view claim drags in the arena — a Listener still sees every
  // pointer event, so pinch-zoom, vertical scroll, text selection, and the
  // horizontal swipe all coexist.
  final Map<int, Offset> _pointers = {};
  double? _pinchBaseDistance;
  double _fontAtPinchStart = 28;

  // Single-finger swipe tracking (distance-based; ignored once a 2nd finger
  // joins, so a pinch is never mistaken for a swipe).
  Offset? _swipeStart;
  bool _multiTouch = false;
  static const double _swipeDistance = 64;

  @override
  Widget build(BuildContext context) {
    final isReading = _viewport == _Viewport.reading;
    return Scaffold(
      appBar: AppBar(
        title: Text(_target.title),
        actions: [
          // Reading ⇄ Detailed in one tap (icon shows the view you'll switch to).
          IconButton(
            tooltip: isReading ? 'Detailed view' : 'Reading view',
            icon: Icon(
              isReading ? Icons.subject_rounded : Icons.menu_book_rounded,
            ),
            onPressed: () => _setDetailed(isReading),
          ),
          // Text size: reveals the inline slider below the bar.
          IconButton(
            tooltip: 'Text size',
            icon: const Icon(Icons.format_size_rounded),
            onPressed: _toggleFontSlider,
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: Stack(
        children: [
          Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: SelectionArea(
              child: BlocBuilder<ReaderCubit, ReaderState>(
                builder: (context, state) {
                  if (state.status == ReaderStatus.error) {
                    return Center(child: Text(state.error ?? 'Failed to load'));
                  }
                  // Keep showing the previous section while the next one loads
                  // (no spinner flash on swipe); spinner only before first load.
                  if (state.ayahs.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Key by the section's first ayah so a new section starts at the
                  // top, while a same-section rebuild preserves scroll position.
                  final sectionKey = ValueKey(state.ayahs.first.id);
                  if (isReading) {
                    return MushafView(
                      key: sectionKey,
                      ayahs: state.ayahs,
                      headings: state.headings,
                      arabicFontSize: _arabicFont,
                      focusAyahId: _focusAyahId,
                      onVisibleAyah: _onVisibleAyah,
                    );
                  }
                  return _DetailedList(
                    key: sectionKey,
                    ayahs: state.ayahs,
                    resources: state.resources,
                    headings: state.headings,
                    arabicFontSize: _arabicFont,
                    focusAyahId: _focusAyahId,
                    onVisibleAyah: _onVisibleAyah,
                  );
                },
              ),
            ),
          ),
          // Tap-away barrier: dismiss the size slider by tapping the page.
          if (_showFontSlider)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideFontSlider,
              ),
            ),
          // The inline text-size slider, anchored under the app bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FontSizeBar(
              visible: _showFontSlider,
              fontSize: _arabicFont,
              minFont: _minFont,
              maxFont: _maxFont,
              onChanged: _applyFont,
            ),
          ),
        ],
      ),
    );
  }

  void _goToAdjacent(int delta) {
    final cubit = context.read<ReaderCubit>();
    final next = adjacentTarget(_target, delta, cubit.state.headings);
    if (next == null) return; // at the first/last section — no wrap-around
    setState(() {
      _target = next;
      _focusAyahId = null; // a swiped section opens at its top, not a resume
    });
    cubit.load(next);
  }

  /// The viewport reports its topmost-visible verse (on scroll-idle); record it
  /// so "Last Read" resumes exactly here.
  void _onVisibleAyah(Ayah ayah) =>
      context.read<ReaderCubit>().saveProgress(ayah);

  // --- Pinch-to-zoom (two-finger) + swipe (one-finger) ----------------------

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 1) {
      _swipeStart = event.position;
      _multiTouch = false;
    }
    if (_pointers.length == 2) {
      // A pinch — disqualify this gesture from also being treated as a swipe.
      _multiTouch = true;
      _pinchBaseDistance = _pointerDistance();
      _fontAtPinchStart = _arabicFont;
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
    final endPosition = _pointers[event.pointer] ?? event.position;
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchBaseDistance = null;
    if (_pointers.isEmpty) {
      final start = _swipeStart;
      if (_multiTouch) {
        // End of a pinch — persist the final zoom level.
        unawaited(_settings.setFontSize(_arabicFont));
      } else if (start != null) {
        _maybeSwipe(start, endPosition);
      }
      _swipeStart = null;
      _multiTouch = false;
    }
  }

  /// A deliberate, mostly-horizontal one-finger drag moves to an adjacent
  /// section: left → next, right → previous (no wrap at the bounds).
  void _maybeSwipe(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx.abs() >= _swipeDistance && dx.abs() > dy.abs()) {
      _goToAdjacent(dx < 0 ? 1 : -1);
    }
  }

  double _pointerDistance() {
    final points = _pointers.values.toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  // --------------------------------------------------------------------------

  void _toggleFontSlider() =>
      setState(() => _showFontSlider = !_showFontSlider);

  void _hideFontSlider() {
    if (_showFontSlider) setState(() => _showFontSlider = false);
  }

  void _setDetailed(bool detailed) {
    setState(() {
      _viewport = detailed ? _Viewport.detailed : _Viewport.reading;
    });
    unawaited(_settings.setDetailed(detailed));
  }

  /// Slider: set the zoom to an absolute value and persist it.
  void _applyFont(double value) {
    _setFont(value);
    unawaited(_settings.setFontSize(_arabicFont));
  }

  void _setFont(double value) {
    final clamped = value.clamp(_minFont, _maxFont);
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
    required this.headings,
    required this.arabicFontSize,
    this.focusAyahId,
    this.onVisibleAyah,
    super.key,
  });

  final List<Ayah> ayahs;
  final List<TranslationResource> resources;
  final Map<int, SurahHeading> headings;
  final double arabicFontSize;
  final int? focusAyahId;
  final ValueChanged<Ayah>? onVisibleAyah;

  @override
  State<_DetailedList> createState() => _DetailedListState();
}

class _DetailedListState extends State<_DetailedList> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();

  late final List<Object> _rows;
  final Map<int, int> _ayahRowIndex = {}; // ayah id -> row index

  Timer? _reportTimer;
  Timer? _highlightTimer;
  int? _highlightAyahId;

  // "Back to top" appears once the list is roughly a screen deep.
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _buildRows();
    _positions.itemPositions.addListener(_onPositions);
    final id = widget.focusAyahId;
    if (id != null && _ayahRowIndex.containsKey(id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus(id));
    }
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    _highlightTimer?.cancel();
    _positions.itemPositions.removeListener(_onPositions);
    super.dispose();
  }

  void _buildRows() {
    // Flatten into header/ayah rows so the list stays lazy. A header marks each
    // surah boundary, and notes whether the Basmala should precede it (shown for
    // every surah except Al-Fatihah — where it is ayah 1 — and At-Tawbah).
    _rows = <Object>[];
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

  void _scrollToFocus(int ayahId) {
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
    return Stack(
      children: [
        ScrollablePositionedList.builder(
          itemScrollController: _scrollController,
          itemPositionsListener: _positions,
          itemCount: _rows.length,
          itemBuilder: _buildRow,
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: ScrollToTopButton(visible: _showTop, onPressed: _scrollToTop),
        ),
      ],
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
    final tile = AyahTile(
      ayah: ayah,
      resources: widget.resources,
      arabicFontSize: widget.arabicFontSize,
      surahName: widget.headings[ayah.surahId]?.nameEnglish,
      highlight: _highlightAyahId == ayah.id,
    );
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
          // A soft hairline: solid `outline` read too dark; a 40%-alpha `outline`
          // lands between it and the near-invisible `outlineVariant` — visible
          // separation without a heavy rule. Tune the alpha to taste.
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
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

/// Inline text-size control: a slim bar that slides down from under the app bar
/// with a small "A" → slider → large "A". Hidden (slid up + faded) when not
/// [visible]. Pinch-to-zoom stays the primary gesture; this is the discoverable,
/// precise one. The parent anchors it at the top of the reader Stack.
class _FontSizeBar extends StatelessWidget {
  const _FontSizeBar({
    required this.visible,
    required this.fontSize,
    required this.minFont,
    required this.maxFont,
    required this.onChanged,
  });

  final bool visible;
  final double fontSize;
  final double minFont;
  final double maxFont;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  const Text('A', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: fontSize.clamp(minFont, maxFont),
                      min: minFont,
                      max: maxFont,
                      divisions: ((maxFont - minFont) / 2).round(),
                      label: '${fontSize.round()}',
                      onChanged: onChanged,
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 22)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
