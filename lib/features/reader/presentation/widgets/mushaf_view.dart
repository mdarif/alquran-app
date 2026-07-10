import 'dart:async';
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../../domain/ayah_share.dart' show nativeLanguageName;
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../cubit/ayah_audio_cubit.dart';
import 'scroll_to_top_button.dart';
import 'translation_chip.dart';

/// The Basmala, in the exact QPC Uthmanic encoding (matches the bundled font and
/// quran.db). Shown before every surah except Al-Fatihah (where it is ayah 1)
/// and At-Tawbah (which has none) — and only when a surah is shown from ayah 1.
const String _bismillah = 'بِسۡمِ ٱللَّهِ'
    ' ٱلرَّحۡمَٰنِ'
    ' ٱلرَّحِيمِ';

const int _surahAlFatiha = 1;
const int _surahAtTawbah = 9;

// Verse numbers are Western digits everywhere (TOC, chapter medallion, ayah badge,
// and — overlaid on the Reading-view ayah medallion — see [_MarkedParagraph]). The
// font's Arabic-Indic rosette (٢) is dropped: it reads like "4" to Urdu readers.

/// A row in the lazy Reading list: a chapter header, or one Mushaf-page chunk of
/// verses. Chunking by page keeps each paragraph small so only the on-screen
/// pages lay out — a long surah opens as fast as a short one.
sealed class _ReadingRow {
  const _ReadingRow();
}

class _HeaderRow extends _ReadingRow {
  const _HeaderRow(this.surahId, this.showBismillah);
  final int surahId;
  final bool showBismillah;
}

class _ChunkRow extends _ReadingRow {
  const _ChunkRow(this.ayahs);
  final List<Ayah> ayahs; // the verses on one Mushaf page of one surah
}

/// Reading viewport (PRD 4.3): Arabic-only, Mushaf-style flow, rendered as a lazy
/// list of per-page chunks. A section may span surahs (juz/hizb/page/ruku), so
/// ayahs are grouped by surah, each group gets a chapter header (and Basmala
/// where appropriate), then one paragraph per Mushaf page.
class MushafView extends StatefulWidget {
  const MushafView({
    required this.ayahs,
    required this.headings,
    required this.arabicFontSize,
    required this.resources,
    this.arabicStyle = QuranTextStyle.madani,
    this.focusAyahId,
    this.onVisibleAyah,
    this.selectedLanguages = const {},
    this.onRegisterFlush,
    this.audioState,
    this.onToggleLanguage,
    this.showPeek = false,
    this.onSelectVerse,
    super.key,
  });

  final List<Ayah> ayahs;
  final Map<int, SurahHeading> headings;
  final double arabicFontSize;

  /// Base Arabic style (font/features/height) for the AYAH text — Uthmani
  /// (default) or IndoPak (Noorehuda). Surah-name/bismillah headers keep the
  /// default Uthmani face.
  final TextStyle arabicStyle;
  final List<TranslationResource> resources;

  /// Global ayah id to scroll to on open (Last Read resume); null starts at top.
  final int? focusAyahId;

  /// Reports the topmost-visible verse when scrolling settles (drives "Last
  /// Read"), so the resume point reflects where the reader actually stopped.
  final ValueChanged<Ayah>? onVisibleAyah;

  /// The reader's selected translation editions (shared with the Detailed view);
  /// the peek card displays these. Chosen in the Display sheet.
  final Set<String> selectedLanguages;

  /// Called once in initState with a flush callback, and again with null on
  /// dispose. The parent stores the callback and invokes it before switching
  /// viewports so it can capture the exact reading position synchronously —
  /// before the debounce timer fires and before this widget is torn down.
  final void Function(VoidCallback?)? onRegisterFlush;

  /// Live recitation state (audio feature on); null when off. Drives the sticky
  /// now-playing highlight in the page (the gold verse) and the peek's follow.
  final AyahAudioState? audioState;

  /// Toggle a translation edition in the shared selection (from the peek card's
  /// inline language chips, which also drive Detailed view). Null hides them.
  final ValueChanged<String>? onToggleLanguage;

  /// Whether a verse tap opens the translation peek card at all. Default false —
  /// the always-on player owns playback, so a tap just SELECTS the verse (the
  /// green highlight + [onSelectVerse]); turning this on additionally opens the
  /// translation-only peek. The select highlight shows either way.
  final bool showPeek;

  /// Called whenever the selected/queued verse changes (a tap, a stepper move, or
  /// a dismiss → null). The reader uses it to cue the always-on player's Play.
  final ValueChanged<Ayah?>? onSelectVerse;

  @override
  State<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends State<MushafView>
    with SingleTickerProviderStateMixin {
  // Lazy, index-based scrolling (mirrors the Detailed view): only the on-screen
  // Mushaf-page chunks lay out, so a long surah opens as fast as a short one.
  final ItemScrollController _scrollCtrl = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();

  Timer? _reportTimer;
  Timer? _hideTimer;
  Timer? _highlightTimer;
  Timer? _zoomTimer;
  Timer? _followCorrectTimer;
  int? _highlightAyahId;

  // True for a short window after a font/script change (a pinch fires many).
  // A pinch can leak an incidental scroll into the list; while zooming we don't
  // let that drop the resume pin, so a zoom holds your exact verse.
  bool _zooming = false;

  // The verse we resumed to (Last Read) — pinned so the post-scroll report can't
  // drift it; cleared the moment the reader finger-scrolls.
  int? _heldFocusId;

  // Set when a scroll-to-top disturbed the view mid-playback, so the NEXT reciter
  // advance re-homes with a corrective pass even if its first scroll looked precise
  // (the single scroll can be interrupted by the scroll-to-top animation).
  bool _forceFollowCorrection = false;

  // Tap-to-peek translation card.
  Ayah? _selectedAyah; // highlighted verse (null = none)
  Ayah? _shownAyah; // kept during slide-out so card doesn't blink
  late final AnimationController _peekCtrl;
  late final Animation<Offset> _peekSlide;

  int? _currentPage;
  bool _showPage = false;

  /// Whether the section spans more than one Mushaf page — when it doesn't,
  /// the page pill is suppressed (it would always show the same number).
  bool _multiPage = false;

  bool _showTop = false;

  // Flattened rows for the lazy list: a header per surah, then one paragraph per
  // Mushaf page. `_ayahRowIndex` maps a verse to its chunk's row (for
  // focus/resume). Each chunk paragraph owns its own render-object key and
  // resolves its own taps, so no per-chunk key is held here (a parent-held key
  // clashes inside the SPL dual list mid-animation).
  final List<_ReadingRow> _rows = [];
  final Map<int, int> _ayahRowIndex = {};

  // Each verse's measured TOP as a fraction (0..1) of its page-chunk's height,
  // reported by the paragraphs as they lay out. The reciter-follow uses this to
  // scroll a verse to the top of its flowing paragraph precisely (no split); it
  // falls back to a char-length estimate for a verse not yet measured.
  final Map<int, double> _verseTops = {};

  // Where the list first lays out. For a resume/verse-jump open we position the
  // SPL AT the focus row via initialScrollIndex, not a post-build scrollTo — the
  // ItemScrollController isn't attached yet on the first post-frame after an
  // async-loaded section builds, so a scrollTo there silently no-ops (the verse
  // jump from search / Last Read would land at the top instead).
  int _initialIndex = 0;
  double _initialAlignment = 0;

  /// A focused verse sits just below the very top (4%), so a sliver of the
  /// preceding verse shows it's mid-surah, not the chapter start.
  static const double _focusAlignment = 0.04;

  void _buildRows() {
    _rows.clear();
    _ayahRowIndex.clear();
    for (final group in groupAyahsBySurah(widget.ayahs)) {
      _rows.add(_HeaderRow(group.first.surahId, _showBismillah(group)));
      var chunk = <Ayah>[];
      int? page;
      void flush() {
        if (chunk.isEmpty) return;
        final verses = List<Ayah>.of(chunk);
        final rowIndex = _rows.length;
        for (final a in verses) {
          _ayahRowIndex[a.id] = rowIndex;
        }
        _rows.add(_ChunkRow(verses));
        chunk = <Ayah>[];
      }

      for (final a in group) {
        if (page != null && a.page != page) flush();
        // Start a fresh chunk exactly at the resume / verse-jump focus so it lands
        // at the top via initialScrollIndex. The reciter-follow does NOT split — it
        // keeps the page one flowing paragraph and scrolls to the verse's position
        // WITHIN it (see _scrollFollowVerse), so playback never reshapes the page.
        if (a.id == widget.focusAyahId && chunk.isNotEmpty) flush();
        page = a.page;
        chunk.add(a);
      }
      flush();
    }
    _multiPage = widget.ayahs.isNotEmpty &&
        widget.ayahs.first.page != null &&
        widget.ayahs.first.page != widget.ayahs.last.page;
    _currentPage = widget.ayahs.isNotEmpty ? widget.ayahs.first.page : null;
  }

  @override
  void initState() {
    super.initState();
    _peekCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _peekSlide =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _peekCtrl, curve: Curves.easeOutCubic),
    );
    // Once the slide-out animation fully completes, drop the displayed ayah
    // so the card returns SizedBox.shrink() — guaranteeing it's truly
    // invisible rather than relying solely on translation + clipping.
    _peekCtrl.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _shownAyah = null);
      }
    });
    _buildRows();
    _positions.itemPositions.addListener(_onPositions);
    final id = widget.focusAyahId;
    if (id != null && _ayahRowIndex.containsKey(id)) {
      // The focus verse begins its own chunk (see _buildRows), so opening the list
      // AT that row lands the verse itself near the top — deterministic, no
      // measurement. Pin Last Read to it; report + highlight after the first frame.
      _initialIndex = _ayahRowIndex[id]!;
      _initialAlignment = _focusAlignment;
      _heldFocusId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onVisibleAyah?.call(
          widget.ayahs.firstWhere(
            (a) => a.id == id,
            orElse: () => widget.ayahs.first,
          ),
        );
        _flash(id);
      });
    }
    widget.onRegisterFlush?.call(_reportTopmost);
  }

  @override
  void didUpdateWidget(MushafView old) {
    super.didUpdateWidget(old);

    // Follow the reciter: when the now-playing verse advances (continuous
    // playback), scroll it up near the top and advance the peek card to it —
    // WITHOUT reshaping the page (the follow scrolls to the verse's position
    // within its flowing paragraph, see _scrollFollowVerse). Deferred a frame so
    // the scroll measures settled layout; re-run once more after the animation so
    // a verse whose chunk was off-screen (a big jump / page turn) still homes.
    final playing = widget.audioState?.playingAyahId;
    final oldPlaying = old.audioState?.playingAyahId;
    if (playing != null && playing != oldPlaying) {
      // Playback started or advanced. The tap selection steps aside — the gold
      // now-playing tint represents the current verse, so the green cue shouldn't
      // linger on a stale verse while you skip prev/next. Clear it LOCALLY only:
      // we're inside the parent's rebuild here, so notifying it (onSelectVerse →
      // its setState) would be a re-entrant build and corrupt the element tree.
      if (oldPlaying == null) _selectedAyah = null;
      // The peek FOLLOWS the reciter (shows the playing verse's translation).
      _syncPeek();
      final ayah = _ayahById(playing);
      if (ayah != null) {
        _followCorrectTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final precise = _scrollFollowVerse(ayah.id);
          // Pin the reciter so the report saves the PLAYING verse as Last Read —
          // not whatever verse is topmost. Set AFTER the scroll (which clears the
          // pin). A finger-scroll during playback still releases it (see the
          // ScrollStartNotification handler); a pause keeps playingAyahId, so the
          // pin holds the paused verse too.
          _heldFocusId = ayah.id;
          // REPORT it now, directly — Last Read must track the reciter even when
          // the follow SKIPS the scroll (a short surah that fits on screen, or the
          // verse already near the top after a scroll-to-top). Relying on the
          // scroll's ScrollEnd would leave Last Read frozen on an earlier verse.
          _reportTopmost();
          // Re-home once more after the layout settles when the first pass had to
          // ESTIMATE (off-screen chunk — a page turn / big jump), or when a
          // scroll-to-top just disturbed the view (its single scroll can be
          // interrupted). A precise within-page advance is already correct, so
          // skipping the second scroll otherwise kills the double-scroll "jump".
          if (!precise || _forceFollowCorrection) {
            _forceFollowCorrection = false;
            _followCorrectTimer = Timer(const Duration(milliseconds: 480), () {
              if (!mounted) return;
              _scrollFollowVerse(ayah.id);
              _heldFocusId = ayah.id;
            });
          }
        });
      }
    } else if (playing == null && oldPlaying != null) {
      // Audio fully stopped (idle / end-of-surah / error) — no current verse, so
      // release the reciter pin and let Last Read track the reading position again.
      _heldFocusId = null;
      // The peek was following the reciter; with nothing playing it reverts to the
      // tap selection (null here → it slides closed).
      _syncPeek();
    }

    // The SPL holds a PIXEL offset across a rebuild, not a logical row — so a
    // font-size change or a script reload (same verses, longer/shorter glyphs)
    // reflows every chunk and the old offset lands on an earlier verse. Capture
    // the top row now (old layout) and jump it back to the same spot after the
    // reflow, so the reader stays on their verse.
    final fontChanged = widget.arabicFontSize != old.arabicFontSize;
    final styleChanged = widget.arabicStyle != old.arabicStyle;
    final ayahsChanged = widget.ayahs != old.ayahs;
    if (fontChanged || styleChanged) {
      _zooming = true;
      _zoomTimer?.cancel();
      _zoomTimer = Timer(
        const Duration(milliseconds: 300),
        () => _zooming = false,
      );
    }
    if (fontChanged || styleChanged || ayahsChanged) _reanchor();
    // Rows only depend on the verses + the focus split; the reciter-follow never
    // rebuilds them (it scrolls within the flowing paragraph), so playback never
    // reshapes the page.
    if (ayahsChanged) _buildRows();
  }

  /// Hold the current top verse across a reflow (font/script change): capture the
  /// topmost row and its alignment from the pre-reflow layout, then jump back to
  /// it once the new layout settles. Runs before [_buildRows] so it reads the old
  /// rows; the post-frame jump resolves the verse's NEW row index.
  void _reanchor() {
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1);
    if (visible.isEmpty) return;
    final top = visible
        .reduce((a, b) => a.itemLeadingEdge <= b.itemLeadingEdge ? a : b);
    final align = top.itemLeadingEdge;
    final held = _heldFocusId;
    final topRow = top.index < _rows.length ? _rows[top.index] : null;
    final anchorAyahId =
        held ?? (topRow is _ChunkRow ? topRow.ayahs.first.id : null);
    final rawIndex = top.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.isAttached) return;
      final idx = (anchorAyahId != null ? _ayahRowIndex[anchorAyahId] : null) ??
          rawIndex;
      _scrollCtrl.jumpTo(index: idx, alignment: held != null ? 0.04 : align);
    });
  }

  @override
  void dispose() {
    widget.onRegisterFlush?.call(null);
    // Flush the resume point before teardown (a pending debounce is about to be
    // cancelled), so a quick pop right after scrolling still saves the position.
    _reportTopmost();
    _reportTimer?.cancel();
    _hideTimer?.cancel();
    _highlightTimer?.cancel();
    _zoomTimer?.cancel();
    _followCorrectTimer?.cancel();
    _positions.itemPositions.removeListener(_onPositions);
    _peekCtrl.dispose();
    super.dispose();
  }

  /// A verse was tapped in one of the chunk paragraphs (each resolves the hit
  /// against its own render object, so no per-chunk GlobalKey has to survive in
  /// this parent — which would clash inside the SPL dual list mid-animation).
  void _onVerseTapped(Ayah tapped) {
    if (_selectedAyah?.id == tapped.id) {
      _dismissPeek();
      return;
    }
    _selectVerse(tapped);
  }

  /// The verse with [id] in the loaded section, or null if it isn't here (e.g.
  /// an off-screen neighbour page never carries the active audio state anyway).
  Ayah? _ayahById(int id) {
    for (final ayah in widget.ayahs) {
      if (ayah.id == id) return ayah;
    }
    return null;
  }

  /// The verse the translation peek should show. While a verse is loaded in the
  /// player the peek FOLLOWS the reciter (the playing verse, so the translation
  /// keeps pace with the audio); otherwise it's the verse the reader tapped.
  Ayah? get _peekAyah {
    final playing = widget.audioState?.playingAyahId;
    if (playing != null) return _ayahById(playing);
    return _selectedAyah;
  }

  /// Open/keep or slide the peek to match [_peekAyah] (only when opted in). Kept
  /// in one place so a tap, a dismiss, and the reciter-follow all agree.
  void _syncPeek() {
    final target = widget.showPeek ? _peekAyah : null;
    if (target != null) {
      _shownAyah = target; // populate + retain through the slide-out
      _peekCtrl.forward();
    } else {
      _peekCtrl
          .reverse(); // _shownAyah cleared by the dismissed-status listener
    }
  }

  /// Select [ayah] as the peeked verse (highlight + slide the card up). When
  /// [scroll] is set (stepping with ‹/›, not a direct tap) it also animates the
  /// verse into view — but [onlyScrollIfNeeded] skips that when the verse is
  /// already on screen, so stepping through a short surah (or the top of any
  /// surah) doesn't re-align the page and jump.
  void _selectVerse(
    Ayah ayah, {
    bool scroll = false,
    bool onlyScrollIfNeeded = false,
  }) {
    setState(() => _selectedAyah = ayah);
    // Always cue the verse for the always-on player (Reading has no per-verse
    // play button); the green select-highlight shows whether or not the peek does.
    widget.onSelectVerse?.call(ayah);
    _syncPeek(); // open the peek on this verse when opted in
    if (scroll) _scrollToFocus(ayah.id, onlyIfNeeded: onlyScrollIfNeeded);
  }

  void _dismissPeek() {
    setState(() => _selectedAyah = null);
    widget.onSelectVerse?.call(null); // clear the player's cue too
    _syncPeek();
  }

  /// Scroll the verse's Mushaf-page chunk to the top (reciter follow / verse
  /// stepper). Both release the resume pin — this is a deliberate move. The
  /// initial resume/verse-jump does NOT come through here: it opens the list AT
  /// the focus verse via initialScrollIndex (the verse begins its own chunk).
  ///
  /// [onlyIfNeeded] (the ‹/› stepper) skips the scroll when the verse's chunk is
  /// already on screen — re-aligning a visible verse only lurches the page.
  void _scrollToFocus(int ayahId, {bool onlyIfNeeded = false}) {
    _heldFocusId = null;
    final idx = _ayahRowIndex[ayahId];
    if (idx != null &&
        mounted &&
        _scrollCtrl.isAttached &&
        !(onlyIfNeeded && _rowVisible(idx))) {
      _scrollCtrl.scrollTo(
        index: idx,
        alignment: _focusAlignment,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
    _flash(ayahId);
  }

  /// Follow the reciter WITHOUT reshaping the page: scroll so the playing verse
  /// sits near the top of its (unsplit) flowing Mushaf-page paragraph. The SPL
  /// aligns a whole item (chunk), so to put a verse that lives INSIDE the chunk at
  /// [_focusAlignment] we offset the alignment by the verse's position down the
  /// chunk — estimated from its char offset (a good proxy in justified text) times
  /// the chunk's measured on-screen height. A verse low in a tall page needs the
  /// chunk's leading edge ABOVE the viewport top (a negative alignment), which SPL
  /// honours for an already-visible item (it scrolls by pure arithmetic). If the
  /// chunk is off-screen (a big jump), we can't measure it yet, so fall back to the
  /// chunk top and let the follow's second pass refine it once it's on screen.
  /// Scrolls the playing verse to the top WITHIN its flowing paragraph. Returns
  /// true when the target was computed from the MEASURED verse top (precise);
  /// false when it fell back to an estimate (the verse's chunk is off-screen) and
  /// the caller should schedule one corrective re-scroll once it lays out.
  bool _scrollFollowVerse(int ayahId) {
    _heldFocusId = null;
    final idx = _ayahRowIndex[ayahId];
    if (idx == null || !mounted || !_scrollCtrl.isAttached) {
      _flash(ayahId);
      return false;
    }
    // A short section that fits entirely on screen (e.g. Al-Fatihah): the verse is
    // already visible, so following it would only shove the surah header off the
    // top — a pointless "jump" on every verse change. Skip the scroll (still flash).
    final positions = _positions.itemPositions.value;
    if (positions.length >= _rows.length &&
        positions.every(
          (p) => p.itemLeadingEdge >= -0.02 && p.itemTrailingEdge <= 1.02,
        )) {
      _flash(ayahId);
      return true;
    }
    var alignment = _focusAlignment;
    var precise = false;
    final row = idx < _rows.length ? _rows[idx] : null;
    ItemPosition? pos;
    for (final p in _positions.itemPositions.value) {
      if (p.index == idx) {
        pos = p;
        break;
      }
    }
    if (row is _ChunkRow && pos != null) {
      final chunkFraction =
          pos.itemTrailingEdge - pos.itemLeadingEdge; // h / vp
      // Prefer the paragraph's MEASURED verse top; fall back to a char estimate
      // for a verse whose chunk hasn't laid out yet (a big jump / page turn).
      final measured = _verseTops[ayahId];
      final f = measured ?? _verseTopFraction(row.ayahs, ayahId);
      precise = measured != null;
      alignment = _focusAlignment - f * chunkFraction;
    }
    _scrollCtrl.scrollTo(
      index: idx,
      alignment: alignment,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    _flash(ayahId);
    return precise;
  }

  /// Fraction of the chunk's text that precedes [ayahId] — a proxy for where the
  /// verse starts down the flowing paragraph. Matches [_MarkedParagraph]'s layout
  /// (each verse is followed by ' ۝ ', i.e. +3 chars).
  static double _verseTopFraction(List<Ayah> ayahs, int ayahId) {
    var total = 0;
    var before = 0;
    var reached = false;
    for (final a in ayahs) {
      if (a.id == ayahId) reached = true;
      final len = a.textArabic.length + 3;
      if (!reached) before += len;
      total += len;
    }
    return total == 0 ? 0 : before / total;
  }

  /// Whether row [index] is currently within the viewport (even partially) — so a
  /// verse in it is already on screen and the stepper needn't scroll to it.
  bool _rowVisible(int index) {
    for (final p in _positions.itemPositions.value) {
      if (p.index == index) {
        return p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1;
      }
    }
    return false;
  }

  void _flash(int ayahId) {
    setState(() => _highlightAyahId = ayahId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightAyahId = null);
    });
  }

  void _onPositions() {
    _updateShowTop();
    _updatePage();
    _reportTimer?.cancel();
    _reportTimer = Timer(const Duration(milliseconds: 400), _reportTopmost);
  }

  void _updateShowTop() {
    final positions = _positions.itemPositions.value;
    ItemPosition? first;
    for (final p in positions) {
      if (p.index == 0) {
        first = p;
        break;
      }
    }
    final showTop =
        positions.isNotEmpty && (first == null || first.itemLeadingEdge < -1.0);
    if (showTop != _showTop) setState(() => _showTop = showTop);
  }

  /// The topmost visible chunk row (skipping headers), or null.
  _ChunkRow? _topChunk() {
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1);
    if (visible.isEmpty) return null;
    final top = visible
        .reduce((a, b) => a.itemLeadingEdge <= b.itemLeadingEdge ? a : b);
    for (var i = top.index; i < _rows.length; i++) {
      final row = _rows[i];
      if (row is _ChunkRow) return row;
    }
    return null;
  }

  void _updatePage() {
    if (!_multiPage) return;
    final page = _topChunk()?.ayahs.first.page;
    if (page != null && page != _currentPage) {
      setState(() => _currentPage = page);
    }
    if (!_showPage) setState(() => _showPage = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showPage = false);
    });
  }

  void _scrollToTop() {
    if (!_scrollCtrl.isAttached) return;
    // A deliberate jump to the surah start. Drop the reciter pin (Last Read now
    // tracks the top, like a finger-scroll) and cancel any pending follow
    // correction so it can't yank the view back. If audio is playing, flag the
    // NEXT advance to fully re-home so the follow reliably returns to the reciter.
    _heldFocusId = null;
    _followCorrectTimer?.cancel();
    if (widget.audioState?.playingAyahId != null) _forceFollowCorrection = true;
    _scrollCtrl.scrollTo(
      index: 0,
      alignment: 0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  /// Reports the topmost verse (drives "Last Read") — or the pinned resume verse
  /// while one is held.
  void _reportTopmost() {
    final onVisible = widget.onVisibleAyah;
    if (onVisible == null) return;
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
    final chunk = _topChunk();
    if (chunk != null) onVisible(chunk.ayahs.first);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.arabicFontSize;
    return Stack(
      children: [
        // SizedBox.expand fills the page so the lazy list has a bounded height
        // to lay its items out, and so the peek card's Positioned(bottom:0)
        // anchors to the real screen bottom on short surahs.
        SizedBox.expand(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // A finger-driven scroll (dragDetails set) releases the resume pin
              // so reporting tracks the top again; programmatic focus/reciter
              // scrolls carry no dragDetails. Report the resume point the moment
              // scrolling settles, so leaving right after a scroll still saves it.
              if (n is ScrollStartNotification &&
                  n.dragDetails != null &&
                  !_zooming) {
                _heldFocusId = null;
              }
              // Report after the settle frame lays out — the item positions
              // update during layout, so reading them here (mid-notification)
              // would still see the pre-scroll top.
              if (n is ScrollEndNotification) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _reportTopmost());
              }
              return false;
            },
            child: ScrollablePositionedList.builder(
              itemScrollController: _scrollCtrl,
              itemPositionsListener: _positions,
              initialScrollIndex: _initialIndex,
              initialAlignment: _initialAlignment,
              itemCount: _rows.length,
              padding: const EdgeInsets.only(top: 8, bottom: 56),
              itemBuilder: _buildRow,
            ),
          ),
        ),
        if (_currentPage != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: IgnorePointer(
              child: Center(
                child: _PagePill(page: _currentPage!, visible: _showPage),
              ),
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
        // Tap-to-peek translation card — always in the tree so it can animate.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _peekSlide,
            child: IgnorePointer(
              // The peek only opens when the reader opts in (Settings →
              // Translation on tap); otherwise a tap just cues the verse and this
              // stays an inert, zero-size box.
              // Interactive whenever the peek is actually showing a verse — during
              // playback that's the reciter's verse (via _shownAyah), not a tap.
              ignoring: !widget.showPeek || _shownAyah == null,
              child: _MushafPeekCard(
                ayah: widget.showPeek ? _shownAyah : null,
                resources: widget.resources,
                fontSize: fontSize,
                selected: widget.selectedLanguages,
                onDismiss: _dismissPeek,
                onToggleLanguage: widget.onToggleLanguage,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int i) {
    final row = _rows[i];
    if (row is _HeaderRow) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, i == 0 ? 12 : 28, 20, 4),
        child: Column(
          children: [
            SurahHeaderCard(
              heading: widget.headings[row.surahId],
              fallbackNumber: row.surahId,
              fontSize: widget.arabicFontSize,
            ),
            if (row.showBismillah) ...[
              const SizedBox(height: 12),
              Bismillah(fontSize: widget.arabicFontSize),
            ],
            const SizedBox(height: 6),
          ],
        ),
      );
    }
    final chunk = (row as _ChunkRow).ayahs;
    // One paragraph per Mushaf page — small enough that the lazy list only lays
    // out the on-screen pages. Consecutive pages of a surah butt together (tiny
    // vertical gap) so they still read continuously, with a break at each real
    // Mushaf page boundary.
    // The SPL viewport hands items an unbounded cross-axis, so bound the width
    // to the screen ourselves; the paragraph's Stack then sizes to its text
    // height (the lazy list's main axis is unbounded, which is fine).
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: SizedBox(
        width: width - 40,
        // IntrinsicHeight gives the paragraph's Stack a bounded height (its text
        // height) inside the unbounded-main-axis list. Cheap — a chunk is one
        // small Mushaf page, not the whole surah.
        child: IntrinsicHeight(
          child: _MarkedParagraph(
            group: chunk,
            fontSize: widget.arabicFontSize,
            arabicStyle: widget.arabicStyle,
            highlightAyahId: _highlightAyahId,
            // Green "cued" tint only while idle — once a verse is loaded the gold
            // now-playing tint owns the highlight, so a stale green never lingers
            // on the tapped verse while you skip prev/next.
            selectedAyahId: widget.audioState?.playingAyahId != null
                ? null
                : _selectedAyah?.id,
            // The now-playing tint follows the LOADED verse — it persists while
            // paused (a resume anchor, matching the Detailed tile) and clears only
            // when idle/stopped/errored (playingAyahId is null then).
            playingAyahId: widget.audioState?.playingAyahId,
            onVerseTap: _onVerseTapped,
            onVerseTops: (tops) => _verseTops.addAll(tops),
          ),
        ),
      ),
    );
  }

  bool _showBismillah(List<Ayah> group) =>
      group.first.surahId != _surahAlFatiha &&
      group.first.surahId != _surahAtTawbah &&
      group.first.ayahNumber == 1;
}

/// One surah group's continuous Mushaf paragraph.
///
/// Each ayah's number is drawn as a **Western digit centred inside the font's
/// ornate ayah medallion** (U+06DD). The medallion is inline *text*, so it orders
/// correctly in RTL, reflows and zooms with the verses, and is always drawn
/// (graceful degradation — if the overlay ever mis-measures, you still see the
/// medallion, never an empty gap). The number is overlaid (not composed into the
/// glyph) because KFGQPC's rosette can only hold the canonical Arabic-Indic ٢,
/// which reads like "4" to Urdu readers; a FittedBox keeps 1–3 digits inside.
///
/// (The elongated-madd fix for `مَىٰ` words like ٱلۡيَتَٰمَىٰٓ is in the FONT, not
/// here — `tool/patch_arabic_font.py` neutralises the Tajweed-form substitution
/// that dropped the madd. So this just renders the text straight.)
class _MarkedParagraph extends StatefulWidget {
  const _MarkedParagraph({
    required this.group,
    required this.fontSize,
    required this.arabicStyle,
    required this.highlightAyahId,
    required this.selectedAyahId,
    required this.playingAyahId,
    required this.onVerseTap,
    this.onVerseTops,
  });

  final List<Ayah> group;
  final double fontSize;
  final TextStyle arabicStyle;
  final int? highlightAyahId;
  final int? selectedAyahId;

  /// The verse currently being recited — kept tinted for the whole playback.
  final int? playingAyahId;

  /// Called with the verse the reader tapped. Resolved from this paragraph's own
  /// render object so no GlobalKey escapes to the parent — a parent-held key
  /// would collide in ScrollablePositionedList's dual list mid-animation.
  final void Function(Ayah) onVerseTap;

  /// Reports each verse's measured TOP as a fraction (0..1) of this paragraph's
  /// height, whenever the paragraph (re)measures. Lets the reciter-follow scroll a
  /// verse that lives inside the flowing paragraph precisely to the top without
  /// splitting it. Keyed by ayah id.
  final void Function(Map<int, double> tops)? onVerseTops;

  @override
  State<_MarkedParagraph> createState() => _MarkedParagraphState();
}

class _MarkedParagraphState extends State<_MarkedParagraph> {
  // The empty ayah medallion glyph; the Urdu numeral is overlaid on its centre.
  static const String _medallion = '۝';

  // This paragraph's render-object key — created here (not passed in) so it never
  // escapes to the parent. The SPL keeps two internal lists during a scroll
  // animation; a parent-shared GlobalKey would then be in two trees at once.
  final GlobalKey _paraKey = GlobalKey();

  // Character offset of each ayah's medallion glyph within the paragraph.
  final List<int> _markerOffsets = [];

  // Each verse's START char offset (parallel to widget.group) — for tap→verse.
  final List<int> _verseStarts = [];

  // Measured medallion boxes (paragraph-local), one per ayah; empty until laid out.
  List<Rect> _rects = const [];

  // Paragraph size at the last box measure. The medallion boxes only move when
  // the paragraph reflows (which changes its size), so this lets _measure skip
  // the O(n) box scan on plain rebuilds (e.g. every scroll frame). Reset on a
  // group change so a same-size different-surah paragraph still re-measures.
  Size? _lastMeasuredSize;

  @override
  void initState() {
    super.initState();
    _computeOffsets();
  }

  @override
  void didUpdateWidget(covariant _MarkedParagraph old) {
    super.didUpdateWidget(old);
    if (old.group != widget.group) _computeOffsets();
  }

  void _computeOffsets() {
    _markerOffsets
      ..clear()
      ..addAll(_offsetsFor(widget.group));
    _verseStarts.clear();
    var off = 0;
    for (final ayah in widget.group) {
      _verseStarts.add(off);
      // ' ۝ ' = leading space + medallion + trailing space.
      off += ayah.textArabic.length + 3;
    }
    // Force a re-measure: a new group may lay out to the same height as the old.
    // Also drop the stale medallion boxes — the new group can have a DIFFERENT
    // verse count (a page-chunk splits at the reciter's verse during playback),
    // and the badge overlay indexes widget.group by _rects position, so keeping
    // the old (longer) _rects would read past the new group. Re-measure repopulates.
    _lastMeasuredSize = null;
    _rects = const [];
  }

  /// Resolve the tapped verse against this paragraph's own render object and
  /// report it up. Kept here (not in the parent) so no GlobalKey has to survive
  /// outside — see [_paraKey].
  void _handleTap(TapUpDetails details) {
    final ro = _paraKey.currentContext?.findRenderObject();
    if (ro is! RenderParagraph) return;
    final charOffset = ro
        .getPositionForOffset(ro.globalToLocal(details.globalPosition))
        .offset;
    Ayah? tapped;
    for (var i = 0; i < widget.group.length; i++) {
      if (charOffset >= _verseStarts[i]) tapped = widget.group[i];
    }
    if (tapped != null) widget.onVerseTap(tapped);
  }

  static List<int> _offsetsFor(List<Ayah> group) {
    final offsets = <int>[];
    var offset = 0;
    for (final ayah in group) {
      // ' ۝ ' = leading space + medallion + trailing space; the medallion sits
      // one char past the verse text and the leading space.
      offsets.add(offset + ayah.textArabic.length + 1);
      offset += ayah.textArabic.length + 3;
    }
    return offsets;
  }

  void _measure() {
    if (!mounted) return;
    final obj = _paraKey.currentContext?.findRenderObject();
    if (obj is! RenderParagraph || !obj.attached) return;
    // The medallion boxes only move when the paragraph REFLOWS — a font-size,
    // width (rotation) or text change, each of which changes its size. On a plain
    // rebuild (the scroll page-pill tick, a highlight toggle) the layout is
    // identical, so skip the O(n) getBoxesForSelection scan that otherwise ran on
    // every scroll frame of a 286-verse surah. (_rects empty ⇒ first measure, or
    // boxes not ready yet — keep trying.)
    if (obj.size == _lastMeasuredSize && _rects.isNotEmpty) return;
    _lastMeasuredSize = obj.size;
    final rects = <Rect>[
      for (final off in _markerOffsets)
        () {
          final boxes = obj.getBoxesForSelection(
            TextSelection(baseOffset: off, extentOffset: off + 1),
            boxHeightStyle: BoxHeightStyle.tight,
          );
          return boxes.isEmpty ? Rect.zero : boxes.first.toRect();
        }(),
    ];
    // Report each verse's TOP (fraction of the paragraph height) for the reciter-
    // follow. Derived from the MEDALLION boxes (rects) — the same measurement the
    // verse-number badges use, so it's reliable on real Uthmani text where selecting
    // a verse's first *character* (a combining mark) can return an empty box. Verse i
    // begins on the line of verse i-1's medallion (rects[i-1].top); verse 0 at the
    // top. A missing box reuses the previous top so a verse never collapses to 0
    // (which would make the follow scroll to the page top instead of the verse).
    final onTops = widget.onVerseTops;
    final h = obj.size.height;
    if (onTops != null && h > 0) {
      final tops = <int, double>{};
      var lastTop = 0.0;
      for (var i = 0; i < widget.group.length; i++) {
        final topPx = i == 0
            ? 0.0
            : (rects[i - 1] != Rect.zero ? rects[i - 1].top : lastTop);
        lastTop = topPx;
        tops[widget.group[i].id] = (topPx / h).clamp(0.0, 1.0);
      }
      onTops(tops);
    }
    if (!_rectsClose(rects, _rects)) {
      setState(() => _rects = rects);
    }
  }

  static bool _rectsClose(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].center - b[i].center).distanceSquared > 0.25 ||
          (a[i].height - b[i].height).abs() > 0.5) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure after each layout (zoom / reflow / rotation). Guarded so it only
    // setStates when a medallion actually moves — no rebuild loop.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final cs = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    for (final ayah in widget.group) {
      // Two ORTHOGONAL signals, two colours (so they never look like one
      // ambiguous selection): the reciter's now-playing verse tints GOLD
      // (cs.tertiary — matching the Detailed tile), while the tap-peek / Last-Read
      // verse tints GREEN (cs.primary). Now-playing wins if a verse is both.
      final isNowPlaying = widget.playingAyahId == ayah.id;
      final isPeeked =
          widget.highlightAyahId == ayah.id || widget.selectedAyahId == ayah.id;
      final Color? tint = isNowPlaying
          ? cs.tertiary.withValues(alpha: 0.18)
          : isPeeked
              ? cs.primary.withValues(alpha: 0.16)
              : null;
      spans.add(
        TextSpan(
          text: ayah.textArabic,
          style: tint != null ? TextStyle(backgroundColor: tint) : null,
        ),
      );
      // The medallion glyph is INVISIBLE — it only reserves the inline slot and
      // is the measurable anchor (U+06DD boxes cleanly). The visible verse badge
      // is the circle overlaid on its box below.
      spans.add(
        const TextSpan(
          text: ' $_medallion ',
          // Invisible anchor: render the U+06DD rosette in the Uthmani face
          // ALWAYS, so the measured box — and thus the overlaid verse badge and
          // its inline spacing — stay the same size whatever the ayah font is
          // (Noorehuda's rosette is far larger). It still scales with the
          // inherited font size (zoom).
          style: TextStyle(
            color: Color(0x00000000),
            fontFamily: AppTheme.arabicFontFamily,
          ),
        ),
      );
    }

    return Stack(
      children: [
        // The paragraph itself is the only non-positioned child, so the Stack
        // sizes to its (finite) height — essential inside the lazy list, which
        // hands items an unbounded height. Taps are caught by the fill overlay
        // below; the badges (IgnorePointer) sit on top of it.
        Text.rich(
          key: _paraKey,
          TextSpan(children: spans),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          locale: const Locale('ar'),
          style: widget.arabicStyle.copyWith(fontSize: widget.fontSize),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTap,
          ),
        ),
        // The visible verse badge: a clean filled circle with the Western number,
        // matching the TOC / Detailed-view CircleAvatar (not the font's ornate
        // Mushaf rosette). Drawn over the invisible medallion anchor's box, so it
        // keeps correct RTL order + reflow + pinch-zoom (a WidgetSpan would bidi-
        // reverse). Sized off the measured box.
        for (var i = 0; i < _rects.length; i++)
          if (_rects[i] != Rect.zero)
            Positioned.fromRect(
              rect: _rects[i],
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: _rects[i].shortestSide,
                    height: _rects[i].shortestSide,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryContainer,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(_rects[i].shortestSide * 0.22),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${widget.group[i].ayahNumber}',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// A subtle "Page N" readout that fades in while scrolling and out when idle.
/// It's an estimate over flowed text, not a page-faithful boundary.
class _PagePill extends StatelessWidget {
  const _PagePill({required this.page, required this.visible});

  final int page;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: visible ? 0.85 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Page $page',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Groups a mushaf-ordered ayah list into consecutive runs of the same surah.
List<List<Ayah>> groupAyahsBySurah(List<Ayah> ayahs) {
  final groups = <List<Ayah>>[];
  for (final ayah in ayahs) {
    if (groups.isEmpty || groups.last.first.surahId != ayah.surahId) {
      groups.add([ayah]);
    } else {
      groups.last.add(ayah);
    }
  }
  return groups;
}

/// Chapter header (the "open a surah" moment): a refined number medallion, the
/// Arabic surah name in the QPC face, the English name in a display serif, and a
/// muted "<revelation> · <n> verses" meta line. Centered.
class SurahHeaderCard extends StatelessWidget {
  const SurahHeaderCard({
    required this.heading,
    required this.fallbackNumber,
    required this.fontSize,
    super.key,
  });

  final SurahHeading? heading;
  final int fallbackNumber;

  /// Current Arabic reading size (driven by pinch-zoom / ±). The header scales
  /// off this so the chapter name and meta grow and shrink with the verses.
  final double fontSize;

  /// Neutral reading size: at this value the header keeps its designed sizes.
  static const double _baseFontSize = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final number = heading?.number ?? fallbackNumber;
    final nameEnglish = heading?.nameEnglish ?? 'Surah $number';
    final nameArabic = heading?.nameArabic;
    final meta = _metaLine(heading);
    final scale = fontSize / _baseFontSize;

    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Refined medallion: a soft-tinted ring rather than a flat green disc.
          Container(
            width: 40 * scale,
            height: 40 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15 * scale,
              ),
            ),
          ),
          if (nameArabic != null) ...[
            SizedBox(height: 14 * scale),
            Text(
              nameArabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              locale: const Locale('ar'),
              style: QuranTextStyle.madani.copyWith(
                fontSize: 34 * scale,
                height: 1.4,
                color: cs.primary,
              ),
            ),
          ],
          SizedBox(height: 6 * scale),
          Text(
            nameEnglish,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              fontSize: 24 * scale,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          if (meta != null) ...[
            SizedBox(height: 6 * scale),
            Text(
              meta,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * scale,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Meccan · 7 verses" — each part included only when known.
  static String? _metaLine(SurahHeading? heading) {
    if (heading == null) return null;
    final parts = <String>[];
    final revelation = _revelationLabel(heading.revelationPlace);
    if (revelation != null) parts.add(revelation);
    if (heading.totalAyahs > 0) {
      parts.add(
        heading.totalAyahs == 1 ? '1 Verse' : '${heading.totalAyahs} Verses',
      );
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Maps the DB's revelation_place ("makkah"/"madinah") to a reader label.
  static String? _revelationLabel(String? place) {
    switch (place?.toLowerCase()) {
      case 'makkah':
      case 'mecca':
        return 'Meccan';
      case 'madinah':
      case 'medina':
        return 'Medinan';
      default:
        return null;
    }
  }
}

/// Centred Basmala header in the QPC face — the special recurring line, set
/// apart from the verses: rendered in the reserved ornament gold and flanked by
/// a small QPC star ornament (۞) on each side. Scales with the reading size.
class Bismillah extends StatelessWidget {
  const Bismillah({required this.fontSize, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).extension<MushafColors>()?.gold ??
        Theme.of(context).colorScheme.primary;
    final star = Text(
      '۞',
      style: QuranTextStyle.madani.copyWith(
        fontSize: fontSize * 0.7,
        color: gold,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        star,
        SizedBox(width: fontSize * 0.45),
        Flexible(
          child: Text(
            _bismillah,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
            style: QuranTextStyle.madani.copyWith(
              fontSize: fontSize,
              color: gold,
            ),
          ),
        ),
        SizedBox(width: fontSize * 0.45),
        star,
      ],
    );
  }
}

/// Bottom peek card shown when the reader taps a verse in Reading mode. It is
/// translation-FIRST: the Arabic is not repeated (the tapped verse is already on
/// the page and highlighted). It shows the reader's selected translation(s) —
/// the same set used by Detailed view — and offers all editions as multi-select
/// chips, so toggling here also changes Detailed. Slides up from the bottom;
/// swipe down or tap the handle to dismiss.
class _MushafPeekCard extends StatelessWidget {
  const _MushafPeekCard({
    required this.ayah,
    required this.resources,
    required this.fontSize,
    required this.selected,
    required this.onDismiss,
    this.onToggleLanguage,
  });

  final Ayah? ayah;
  final List<TranslationResource> resources;
  final double fontSize;
  final Set<String> selected;
  final VoidCallback onDismiss;

  /// Toggle a translation edition in the shared selection (the inline chips).
  /// Null hides the chips.
  final ValueChanged<String>? onToggleLanguage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final current = ayah;
    if (current == null) return const SizedBox.shrink();
    final maxH = MediaQuery.of(context).size.height * 0.6;
    final translationSize =
        (theme.textTheme.bodyLarge?.fontSize ?? 16) * (fontSize / 28.0);

    // Editions that actually have a translation for this verse, in resource order.
    final available = [
      for (final r in resources)
        if (current.translations[r.id] != null) r,
    ];
    // Show the selected editions; if none of the selected ones apply here, fall
    // back to the first available so the card is never empty.
    var shown = [
      for (final r in available)
        if (selected.contains(r.languageCode)) r,
    ];
    if (shown.isEmpty && available.isNotEmpty) shown = [available.first];

    return Material(
      key: WidgetKeys.peekCard,
      color: cs.surface,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle — tap or swipe-down to dismiss. Separate from the
            // content area so its GestureDetector wins the arena cleanly.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 300) onDismiss();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            // Content — ListView(shrinkWrap) hugs its own content height so
            // there's no blank gap at small font sizes, while still scrolling
            // when translations are long. Swallow taps to prevent bleed-through.
            GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  children: [
                    // Translation-only: the verse ref + ‹/› steppers are gone (the
                    // player bar owns navigation); the peek follows the player (or
                    // the tapped verse) and just shows the meaning + language picker.
                    if (onToggleLanguage != null && available.length > 1) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final r in available)
                              TranslationChip(
                                key: WidgetKeys.peekLangOption(r.languageCode),
                                label: nativeLanguageName(r.languageCode),
                                selected: selected.contains(r.languageCode),
                                onTap: () => onToggleLanguage!(r.languageCode),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      Text(
                        'No translation available',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      )
                    else
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(height: 18),
                        Text(
                          current.translations[shown[i].id]!,
                          textAlign: shown[i].languageCode == 'ur'
                              ? TextAlign.right
                              : TextAlign.left,
                          textDirection: shown[i].languageCode == 'ur'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          locale: Locale(shown[i].languageCode),
                          style: shown[i].languageCode.scriptStyle(
                                theme.textTheme.bodyLarge!.copyWith(
                                  height: 1.5,
                                  fontSize: translationSize,
                                ),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          shown[i].attribution,
                          textAlign: shown[i].languageCode == 'ur'
                              ? TextAlign.right
                              : TextAlign.left,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
