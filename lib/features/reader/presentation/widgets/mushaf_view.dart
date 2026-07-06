import 'dart:async';
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
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

/// Reading viewport (PRD 4.3): Arabic-only, continuous Mushaf-style flow. A
/// section may span surahs (juz/hizb/page/ruku), so ayahs are grouped by surah
/// and each group gets a chapter header (and Basmala where appropriate).
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
    this.onTogglePlay,
    this.onToggleLanguage,
    this.showTranslation = true,
    this.onToggleTranslation,
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
  /// now-playing highlight and the peek card's play button.
  final AyahAudioState? audioState;

  /// Toggle recitation for the given global ayah id. Null hides the peek card's
  /// play control (the flag-off path renders exactly as before).
  final ValueChanged<int>? onTogglePlay;

  /// Toggle a translation edition in the shared selection (from the peek card's
  /// inline language chips, which also drive Detailed view). Null hides them.
  final ValueChanged<String>? onToggleLanguage;

  /// Whether the peek card shows the translation text (and its language chips).
  /// False → a slim play/stepper-only peek, so the reader can read/listen to the
  /// Arabic alone. The verse page itself is Arabic-only either way.
  final bool showTranslation;

  /// Collapse/expand the peek's translation (the in-card toggle). Null hides the
  /// toggle (e.g. on the inert off-screen pages).
  final VoidCallback? onToggleTranslation;

  @override
  State<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends State<MushafView>
    with SingleTickerProviderStateMixin {
  final ScrollController _controller = ScrollController();
  Timer? _hideTimer;
  Timer? _highlightTimer;
  int? _highlightAyahId;

  // The verse we resumed to (Last Read). While set, Last Read stays pinned here
  // so the post-scroll "topmost" report — which lands on whatever ended up at
  // the top (especially near a surah's end, where the scroll can't place the
  // verse at the usual offset) — never drifts the saved position. Cleared the
  // moment the reader actually scrolls, after which reporting tracks the top.
  int? _heldFocusId;

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

  // "Back to top" appears once the reader is roughly a screen deep into a surah.
  bool _showTop = false;
  static const double _topButtonThreshold = 800;

  // One key per surah group (on the Text widget); character offset per ayah in
  // its group paragraph — used for RenderParagraph-based scroll anchoring and
  // for anchoring the overlaid verse-number on its U+06DD rosette.
  final Map<int, GlobalKey> _groupKeys = {};
  final Map<int, int> _verseStart = {};

  GlobalKey _groupKeyFor(int surahId) =>
      _groupKeys.putIfAbsent(surahId, GlobalKey.new);

  // Derived from widget.ayahs and memoised — recomputed only when the ayah list
  // changes, so build() and the scroll listener don't re-group or re-scan O(n)
  // (and re-allocate) on every frame.
  late List<List<Ayah>> _groups;
  late List<int> _cumLen; // running total of textArabic length, per ayah index
  late int _totalLen;

  void _recomputeDerived() {
    _groups = groupAyahsBySurah(widget.ayahs);
    _cumLen = List<int>.filled(widget.ayahs.length, 0);
    var acc = 0;
    for (var i = 0; i < widget.ayahs.length; i++) {
      acc += widget.ayahs[i].textArabic.length;
      _cumLen[i] = acc;
    }
    _totalLen = acc;
    // The scroll pill only informs when the section spans Mushaf pages — on a
    // single-page section (e.g. Al-Fatihah) it would always read the same
    // number, so it stays hidden entirely.
    _multiPage = widget.ayahs.isNotEmpty &&
        widget.ayahs.first.page != null &&
        widget.ayahs.first.page != widget.ayahs.last.page;
  }

  /// The printed-Mushaf page at a vertical scroll [fraction] — O(log n) over the
  /// memoised cumulative lengths, vs the old per-call O(n) + list allocation that
  /// ran on every scroll frame. Same result: the page of the first ayah whose
  /// cumulative length reaches the target offset.
  int? _pageAt(double fraction) {
    if (widget.ayahs.isEmpty) return null;
    if (_totalLen == 0) return widget.ayahs.first.page;
    final target = fraction.clamp(0.0, 1.0) * _totalLen;
    var lo = 0;
    var hi = _cumLen.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumLen[mid] >= target) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return widget.ayahs[lo].page;
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
    _recomputeDerived();
    _buildOffsets();
    _currentPage = widget.ayahs.isNotEmpty ? widget.ayahs.first.page : null;
    _controller.addListener(_onScroll);
    final id = widget.focusAyahId;
    if (id != null && widget.ayahs.any((a) => a.id == id)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToFocus(id, resume: true));
    }
    widget.onRegisterFlush?.call(_reportTopmost);
  }

  @override
  void didUpdateWidget(MushafView old) {
    super.didUpdateWidget(old);

    // Follow the reciter: when the now-playing verse advances (continuous
    // playback), bring it into view and advance the peek card to it — the peek
    // is the now-playing control in Reading. Only on a real verse change, not a
    // play/pause status tick on the same verse. Deferred a frame so the scroll
    // measures the settled layout.
    final playing = widget.audioState?.playingAyahId;
    if (playing != null && playing != old.audioState?.playingAyahId) {
      final ayah = _ayahById(playing);
      if (ayah != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _selectVerse(ayah, scroll: true);
        });
      }
    }

    final ayahsChanged = widget.ayahs != old.ayahs;
    final fontChanged = widget.arabicFontSize != old.arabicFontSize;
    if (!ayahsChanged && !fontChanged) return;

    // Both reflow the text while the ScrollController keeps the same pixel
    // offset, so the reading position would drift to an earlier verse (and
    // corrupt "Last Read"): a font-size change reflows it, and an ayah-list
    // change is a *same-section reload* — only a script switch (Uthmani ⇄
    // IndoPak) reloads identical verses in a longer/shorter face, since section
    // navigation changes the widget key and rebuilds from scratch. Capture the
    // verse at the top NOW (the render objects still hold the old layout), then
    // re-anchor to it once the new layout is in. While a resume verse is pinned,
    // re-anchor to THAT (a zoom must not unpin or drift the resume point).
    final anchor = _heldFocusId != null ? _heldOrTopmost() : _topmostAyah();
    if (ayahsChanged) {
      _groupKeys.clear();
      _recomputeDerived();
      _buildOffsets();
    }
    if (anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _anchorTo(anchor);
      });
    }
  }

  /// Keep [ayah] at the top of the viewport after a relayout (font-size change),
  /// and refresh "Last Read" to it so the resume point doesn't drift.
  void _anchorTo(Ayah ayah) {
    final target = _offsetForAyahTop(ayah.id);
    if (target == null) return;
    _controller.jumpTo(target);
    widget.onVisibleAyah?.call(ayah);
  }

  @override
  void dispose() {
    widget.onRegisterFlush?.call(null);
    _hideTimer?.cancel();
    _highlightTimer?.cancel();
    _controller.dispose();
    _peekCtrl.dispose();
    super.dispose();
  }

  void _onGroupTap(TapUpDetails details, List<Ayah> group) {
    final key = _groupKeys[group.first.surahId];
    final ro = key?.currentContext?.findRenderObject();
    if (ro is! RenderParagraph) return;
    final localPos = ro.globalToLocal(details.globalPosition);
    final charOffset = ro.getPositionForOffset(localPos).offset;
    Ayah? tapped;
    for (final ayah in group) {
      if (charOffset >= (_verseStart[ayah.id] ?? 0)) tapped = ayah;
    }
    if (tapped == null) return;
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

  /// Select [ayah] as the peeked verse (highlight + slide the card up). When
  /// [scroll] is set (stepping with ‹/›, not a direct tap) it also animates the
  /// verse into view.
  void _selectVerse(Ayah ayah, {bool scroll = false}) {
    setState(() {
      _selectedAyah = ayah;
      _shownAyah = ayah;
    });
    _peekCtrl.forward();
    if (scroll) _scrollToFocus(ayah.id);
  }

  /// Step the peeked verse by [delta] (+1 next, -1 previous) within the loaded
  /// section. No-op at the bounds (the ‹/› buttons are disabled there anyway).
  void _step(int delta) {
    final cur = _selectedAyah;
    if (cur == null) return;
    final i = widget.ayahs.indexWhere((a) => a.id == cur.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= widget.ayahs.length) return;
    _selectVerse(widget.ayahs[j], scroll: true);
  }

  /// Index of the peeked verse in the loaded section, or -1 if none. Drives the
  /// ‹/› enable state (disabled at the first/last verse).
  int get _selIdx => _selectedAyah == null
      ? -1
      : widget.ayahs.indexWhere((a) => a.id == _selectedAyah!.id);

  /// The ‹/› stepper is disabled only while audio is actively SOUNDING (playing
  /// or buffering), so it never competes with the card auto-following the
  /// reciter. Paused, stopped/idle and finished all free it again — that's when
  /// the reader wants to step through and read individual translations.
  bool get _canStep => !(widget.audioState?.isSounding ?? false);

  void _dismissPeek() {
    setState(() => _selectedAyah = null);
    _peekCtrl.reverse();
  }

  /// Pre-computes each ayah's character offset within its surah group paragraph
  /// (for scroll anchoring). Mirrors the span layout in [build] exactly: each
  /// verse is `textArabic` + ' <arabic-indic digits> ' (a leading space, the
  /// digits, a trailing space). Must be called whenever [widget.ayahs] changes.
  void _buildOffsets() {
    _verseStart.clear();
    for (final group in _groups) {
      int offset = 0;
      for (final ayah in group) {
        _verseStart[ayah.id] = offset;
        offset += ayah.textArabic.length +
            3; // ' ۝ ' — leading space + medallion (U+06DD) + trailing space
      }
    }
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final fraction = max <= 0 ? 0.0 : _controller.offset / max;
    final page = _pageAt(fraction);
    if (page != null && page != _currentPage) {
      setState(() => _currentPage = page);
    }
    final showTop = _controller.offset > _topButtonThreshold;
    if (showTop != _showTop) setState(() => _showTop = showTop);
    if (_multiPage && !_showPage) setState(() => _showPage = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _showPage = false);
      _reportTopmost();
    });
  }

  void _scrollToTop() {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  /// Local Y of [ayahId]'s first character within its paragraph [obj].
  ///
  /// Uses `getOffsetForCaret`, NOT `getBoxesForSelection`: the latter returns an
  /// EMPTY list for most offsets in heavily-shaped Arabic text (only isolated
  /// glyphs like the medallion/spaces box cleanly), which silently broke
  /// focus-scroll, Last-Read resume, and the font-size re-anchor on real verses —
  /// the anchor functions bailed out, so the position drifted (badly on zoom-in).
  double _verseLocalTop(RenderParagraph obj, int ayahId) {
    final offset = _verseStart[ayahId] ?? 0;
    return obj.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
  }

  void _scrollToFocus(int ayahId, {bool resume = false}) {
    if (!mounted) return;
    // A resume pins Last Read to this verse and records it straight away (so it
    // holds even if the scroll can't land it at the usual offset); a deliberate
    // move (verse stepper / reciter follow) releases the pin instead.
    final focus = widget.ayahs.firstWhere(
      (a) => a.id == ayahId,
      orElse: () => widget.ayahs.first,
    );
    if (resume) {
      _heldFocusId = ayahId;
      widget.onVisibleAyah?.call(focus);
    } else {
      _heldFocusId = null;
    }
    final surahId = focus.surahId;
    final key = _groupKeys[surahId];
    if (key?.currentContext == null) return;
    final obj = key!.currentContext!.findRenderObject();
    if (obj is! RenderParagraph || !obj.attached) return;
    final verseTop = _verseLocalTop(obj, ayahId);
    final groupGlobalY = obj.localToGlobal(Offset.zero).dy;
    final viewportGlobalY = (context.findRenderObject()! as RenderBox)
        .localToGlobal(Offset.zero)
        .dy;
    final target =
        (_controller.offset + (groupGlobalY - viewportGlobalY) + verseTop - 48)
            .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    setState(() => _highlightAyahId = ayahId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightAyahId = null);
    });
  }

  /// The verse currently at the top of the viewport (the one being read), or
  /// null if it can't be determined yet. Walks the laid-out paragraphs and
  /// returns the last verse whose top has scrolled to/above the viewport top.
  Ayah? _topmostAyah() {
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return null;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    Ayah? current;
    outer:
    for (final group in _groups) {
      final key = _groupKeys[group.first.surahId];
      if (key?.currentContext == null) continue;
      final obj = key!.currentContext!.findRenderObject();
      if (obj is! RenderParagraph || !obj.attached) continue;
      final groupGlobalY = obj.localToGlobal(Offset.zero).dy;
      for (final ayah in group) {
        if (groupGlobalY + _verseLocalTop(obj, ayah.id) <= viewportTop + 12) {
          current = ayah;
        } else {
          break outer;
        }
      }
    }
    return current;
  }

  /// Reports the topmost verse (drives "Last Read") on scroll-idle — or the
  /// pinned resume verse, while one is held (before the reader has scrolled).
  void _reportTopmost() {
    final onVisible = widget.onVisibleAyah;
    if (onVisible == null) return;
    onVisible(_heldOrTopmost());
  }

  /// The pinned resume verse if one is held, else the topmost-visible verse.
  Ayah _heldOrTopmost() {
    final held = _heldFocusId;
    if (held != null) {
      return widget.ayahs.firstWhere(
        (a) => a.id == held,
        orElse: () => widget.ayahs.first,
      );
    }
    return _topmostAyah() ?? widget.ayahs.first;
  }

  /// Scroll offset that puts [ayahId]'s top just under the viewport top, using
  /// the CURRENT layout. Null if it can't be located.
  double? _offsetForAyahTop(int ayahId) {
    if (!_controller.hasClients) return null;
    final surahId = widget.ayahs
        .firstWhere((a) => a.id == ayahId, orElse: () => widget.ayahs.first)
        .surahId;
    final obj = _groupKeys[surahId]?.currentContext?.findRenderObject();
    if (obj is! RenderParagraph || !obj.attached) return null;
    final groupGlobalY = obj.localToGlobal(Offset.zero).dy;
    final viewportGlobalY = (context.findRenderObject()! as RenderBox)
        .localToGlobal(Offset.zero)
        .dy;
    return (_controller.offset +
            (groupGlobalY - viewportGlobalY) +
            _verseLocalTop(obj, ayahId) -
            16)
        .clamp(0.0, _controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.arabicFontSize;
    return Stack(
      children: [
        // Record the resume point the moment scrolling settles (finger release /
        // fling end) — reliable and immediate, so leaving right after scrolling
        // still saves where you actually are. (The 1200ms timer below only drives
        // the page pill; on its own it loses the final position when you pop the
        // route before it fires.)
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // A finger-driven scroll (dragDetails set) means the reader took
            // over — release the resume pin so reporting tracks the top again.
            // The programmatic resume/anchor scrolls carry no dragDetails.
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _heldFocusId = null;
            }
            if (n is ScrollEndNotification) _reportTopmost();
            return false;
          },
          // SizedBox.expand forces the inner Stack to fill the full Scaffold body
          // even when the surah content is shorter than the screen (e.g. Al-Fatihah).
          // Without it the Stack sizes to the ScrollView's content height, so
          // Positioned(bottom:0) would anchor to that short height instead of the
          // real screen bottom — causing the peek card to appear partially on-screen
          // after dismissal on short surahs.
          child: SizedBox.expand(
            child: SingleChildScrollView(
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in _groups) ...[
                    SurahHeaderCard(
                      heading: widget.headings[group.first.surahId],
                      fallbackNumber: group.first.surahId,
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 12),
                    if (_showBismillah(group)) ...[
                      Bismillah(fontSize: fontSize),
                      const SizedBox(height: 18),
                    ],
                    // Continuous Mushaf paragraph with each ayah's number drawn as
                    // a readable Urdu numeral centred inside the font's ornate ayah
                    // medallion (U+06DD). See [_MarkedParagraph].
                    _MarkedParagraph(
                      group: group,
                      fontSize: fontSize,
                      arabicStyle: widget.arabicStyle,
                      paragraphKey: _groupKeyFor(group.first.surahId),
                      highlightAyahId: _highlightAyahId,
                      selectedAyahId: _selectedAyah?.id,
                      // The sticky now-playing tint applies ONLY while audio is
                      // sounding. When paused/idle the highlight follows the
                      // peek selection, so stepping verses (now allowed while
                      // paused) never leaves the paused verse double-highlighted.
                      playingAyahId: (widget.audioState?.isSounding ?? false)
                          ? widget.audioState!.playingAyahId
                          : null,
                      onTap: (d) => _onGroupTap(d, group),
                    ),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ), // SizedBox.expand
        ), // NotificationListener
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
              ignoring: _selectedAyah == null,
              child: _MushafPeekCard(
                ayah: _shownAyah,
                resources: widget.resources,
                surahName: _shownAyah == null
                    ? null
                    : widget.headings[_shownAyah!.surahId]?.nameEnglish,
                fontSize: fontSize,
                selected: widget.selectedLanguages,
                onDismiss: _dismissPeek,
                audioState: widget.audioState,
                onTogglePlay: widget.onTogglePlay,
                onToggleLanguage: widget.onToggleLanguage,
                showTranslation: widget.showTranslation,
                onToggleTranslation: widget.onToggleTranslation,
                onPrev: _canStep && _selIdx > 0 ? () => _step(-1) : null,
                onNext: _canStep &&
                        _selIdx >= 0 &&
                        _selIdx < widget.ayahs.length - 1
                    ? () => _step(1)
                    : null,
              ),
            ),
          ),
        ),
      ],
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
    required this.paragraphKey,
    required this.highlightAyahId,
    required this.selectedAyahId,
    required this.playingAyahId,
    required this.onTap,
  });

  final List<Ayah> group;
  final double fontSize;
  final TextStyle arabicStyle;
  final GlobalKey paragraphKey;
  final int? highlightAyahId;
  final int? selectedAyahId;

  /// The verse currently being recited — kept tinted for the whole playback.
  final int? playingAyahId;
  final void Function(TapUpDetails) onTap;

  @override
  State<_MarkedParagraph> createState() => _MarkedParagraphState();
}

class _MarkedParagraphState extends State<_MarkedParagraph> {
  // The empty ayah medallion glyph; the Urdu numeral is overlaid on its centre.
  static const String _medallion = '۝';

  // Character offset of each ayah's medallion glyph within the paragraph.
  final List<int> _markerOffsets = [];

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
    // Force a re-measure: a new group may lay out to the same height as the old.
    _lastMeasuredSize = null;
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
    final obj = widget.paragraphKey.currentContext?.findRenderObject();
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
      final highlighted = widget.highlightAyahId == ayah.id ||
          widget.selectedAyahId == ayah.id ||
          widget.playingAyahId == ayah.id;
      spans.add(
        TextSpan(
          text: ayah.textArabic,
          style: highlighted
              ? TextStyle(backgroundColor: cs.primary.withValues(alpha: 0.16))
              : null,
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.onTap,
          child: Text.rich(
            key: widget.paragraphKey,
            TextSpan(children: spans),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
            style: widget.arabicStyle.copyWith(fontSize: widget.fontSize),
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
    required this.surahName,
    required this.fontSize,
    required this.selected,
    required this.onDismiss,
    this.audioState,
    this.onTogglePlay,
    this.onPrev,
    this.onNext,
    this.onToggleLanguage,
    this.showTranslation = true,
    this.onToggleTranslation,
  });

  final Ayah? ayah;
  final List<TranslationResource> resources;
  final String? surahName;
  final double fontSize;
  final Set<String> selected;
  final VoidCallback onDismiss;

  /// Toggle a translation edition in the shared selection (the inline chips).
  /// Null hides the chips.
  final ValueChanged<String>? onToggleLanguage;

  /// Step to the previous/next verse in the section. Null ⇒ at the edge (the
  /// ‹/› control is shown disabled).
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// Live recitation state + toggle for the tapped verse. Null when the audio
  /// feature is off → no play control (the card renders exactly as before).
  final AyahAudioState? audioState;
  final ValueChanged<int>? onTogglePlay;

  /// Whether to show the translation text + language chips. False collapses the
  /// card to just its control row (read/listen to the Arabic alone).
  final bool showTranslation;

  /// Collapse/expand the translation (the inline ⓣ toggle). Null hides it.
  final VoidCallback? onToggleTranslation;

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

    final reference = surahName == null
        ? '${current.surahId}:${current.ayahNumber}'
        : '$surahName · ${current.surahId}:${current.ayahNumber}';

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
                    // Play · ‹ reference › verse stepper (the inline language
                    // chips sit just below this row).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (onTogglePlay != null) ...[
                          _peekPlayButton(context, current.id),
                          const SizedBox(width: 2),
                        ],
                        _PeekStepButton(
                          key: WidgetKeys.peekPrevButton,
                          icon: AppIcons.chevronLeft,
                          tooltip: 'Previous verse',
                          onPressed: onPrev,
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              reference,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        _PeekStepButton(
                          key: WidgetKeys.peekNextButton,
                          icon: AppIcons.chevronRight,
                          tooltip: 'Next verse',
                          onPressed: onNext,
                        ),
                        // Collapse/expand the translation (read/listen to the
                        // Arabic alone) — only when there's a translation to hide.
                        if (onToggleTranslation != null && available.isNotEmpty)
                          _translationToggle(context),
                      ],
                    ),
                    // Translation — the text + inline language picker. Hidden
                    // when collapsed (the translate toggle) so the card is just
                    // controls over the Arabic. Same picker as the Settings sheet.
                    if (showTranslation) ...[
                      if (onToggleLanguage != null && available.length > 1) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final r in available)
                                TranslationChip(
                                  key:
                                      WidgetKeys.peekLangOption(r.languageCode),
                                  label: nativeLanguageName(r.languageCode),
                                  selected: selected.contains(r.languageCode),
                                  onTap: () =>
                                      onToggleLanguage!(r.languageCode),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recitation control for the tapped verse: play ▸ / pause ❚❚ / a spinner while
  /// buffering / an error glyph (tap to retry).
  Widget _peekPlayButton(BuildContext context, int ayahId) {
    final cs = Theme.of(context).colorScheme;
    final audio = audioState;
    final Widget icon;
    if (audio != null && audio.isLoading(ayahId)) {
      icon = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      );
    } else if (audio != null && audio.isPlaying(ayahId)) {
      icon = AppIcon(
        AppIcons.pauseCircle,
        filled: true,
        color: cs.primary,
        size: AppIconSize.prominent,
      );
    } else if (audio != null && audio.hasError(ayahId)) {
      icon = AppIcon(
        AppIcons.audioError,
        color: cs.error,
        size: AppIconSize.prominent,
      );
    } else {
      icon = AppIcon(
        AppIcons.playCircle,
        filled: true,
        color: cs.primary,
        size: AppIconSize.prominent,
      );
    }
    return IconButton(
      key: WidgetKeys.peekPlayButton,
      tooltip: 'Play recitation',
      visualDensity: VisualDensity.compact,
      onPressed: () => onTogglePlay!(ayahId),
      icon: icon,
    );
  }

  /// Collapse/expand the translation: an open eye (primary) when shown, a slashed
  /// eye (muted) when hidden — the unambiguous "hide" affordance. Lets the reader
  /// read/listen to the Arabic alone without losing the play controls.
  Widget _translationToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      key: WidgetKeys.peekTranslationToggle,
      tooltip: showTranslation ? 'Hide translation' : 'Show translation',
      visualDensity: VisualDensity.compact,
      onPressed: onToggleTranslation,
      icon: AppIcon(
        showTranslation ? AppIcons.visibility : AppIcons.visibilityOff,
        size: AppIconSize.action,
        color: showTranslation ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }
}

/// A compact ‹/› chevron that steps the peeked verse. Disabled (dimmed) at the
/// section's first/last verse — [onPressed] is null there.
class _PeekStepButton extends StatelessWidget {
  const _PeekStepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: AppIcon(icon),
      iconSize: 24,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
