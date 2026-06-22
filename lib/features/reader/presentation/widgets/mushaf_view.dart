import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/ayah_share.dart' show nativeLanguageName;
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/reader_navigation.dart';
import 'scroll_to_top_button.dart';

/// The Basmala, in the exact QPC Uthmanic encoding (matches the bundled font and
/// quran.db). Shown before every surah except Al-Fatihah (where it is ayah 1)
/// and At-Tawbah (which has none) — and only when a surah is shown from ayah 1.
const String _bismillah = 'بِسۡمِ ٱللَّهِ'
    ' ٱلرَّحۡمَٰنِ'
    ' ٱلرَّحِيمِ';

const int _surahAlFatiha = 1;
const int _surahAtTawbah = 9;

/// The verse number as Arabic-Indic digits (٠١٢…). In KFGQPC UthmanicHafs1B the
/// digits of an ayah number compose — via the font's GSUB — into the ornate
/// end-of-ayah rosette *with the number inside it* (e.g. ٢٨٦ → one medallion
/// glyph). So we DON'T add U+06DD (that would draw a second, empty circle) and
/// we keep the digits in one text run with the surrounding Arabic style, which
/// is what lets the substitution fire (it won't across separate TextSpans).
String _toArabicIndic(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + (d.codeUnitAt(0) - 0x30)))
    .join();

/// Reading viewport (PRD 4.3): Arabic-only, continuous Mushaf-style flow. A
/// section may span surahs (juz/hizb/page/ruku), so ayahs are grouped by surah
/// and each group gets a chapter header (and Basmala where appropriate).
class MushafView extends StatefulWidget {
  const MushafView({
    required this.ayahs,
    required this.headings,
    required this.arabicFontSize,
    required this.resources,
    this.focusAyahId,
    this.onVisibleAyah,
    this.selectedLanguages = const {},
    this.onToggleLanguage,
    super.key,
  });

  final List<Ayah> ayahs;
  final Map<int, SurahHeading> headings;
  final double arabicFontSize;
  final List<TranslationResource> resources;

  /// Global ayah id to scroll to on open (Last Read resume); null starts at top.
  final int? focusAyahId;

  /// Reports the topmost-visible verse as the user scrolls (debounced).
  final ValueChanged<Ayah>? onVisibleAyah;

  /// The reader's selected translation editions (shared with Detailed view).
  /// The peek card shows these and offers them as multi-select chips.
  final Set<String> selectedLanguages;

  /// Toggle a language in the shared selection (from the peek card's chips).
  final ValueChanged<String>? onToggleLanguage;

  @override
  State<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends State<MushafView>
    with SingleTickerProviderStateMixin {
  final ScrollController _controller = ScrollController();
  Timer? _hideTimer;
  Timer? _highlightTimer;
  int? _highlightAyahId;

  // Tap-to-peek translation card.
  Ayah? _selectedAyah; // highlighted verse (null = none)
  Ayah? _shownAyah; // kept during slide-out so card doesn't blink
  late final AnimationController _peekCtrl;
  late final Animation<Offset> _peekSlide;

  int? _currentPage;
  bool _showPage = false;

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
    _buildOffsets();
    _currentPage = widget.ayahs.isNotEmpty ? widget.ayahs.first.page : null;
    _controller.addListener(_onScroll);
    final id = widget.focusAyahId;
    if (id != null && widget.ayahs.any((a) => a.id == id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus(id));
    }
  }

  @override
  void didUpdateWidget(MushafView old) {
    super.didUpdateWidget(old);
    if (widget.ayahs != old.ayahs) {
      _groupKeys.clear();
      _buildOffsets();
    }
  }

  @override
  void dispose() {
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
    setState(() {
      _selectedAyah = tapped;
      _shownAyah = tapped;
    });
    _peekCtrl.forward();
  }

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
    for (final group in groupAyahsBySurah(widget.ayahs)) {
      int offset = 0;
      for (final ayah in group) {
        _verseStart[ayah.id] = offset;
        offset += ayah.textArabic.length +
            2 // leading + trailing space around the number
            +
            _toArabicIndic(ayah.ayahNumber).length;
      }
    }
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final fraction = max <= 0 ? 0.0 : _controller.offset / max;
    final page = pageAtFraction(widget.ayahs, fraction);
    if (page != null && page != _currentPage) {
      setState(() => _currentPage = page);
    }
    final showTop = _controller.offset > _topButtonThreshold;
    if (showTop != _showTop) setState(() => _showTop = showTop);
    if (!_showPage) setState(() => _showPage = true);
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

  void _scrollToFocus(int ayahId) {
    if (!mounted) return;
    final surahId = widget.ayahs
        .firstWhere(
          (a) => a.id == ayahId,
          orElse: () => widget.ayahs.first,
        )
        .surahId;
    final key = _groupKeys[surahId];
    if (key?.currentContext == null) return;
    final obj = key!.currentContext!.findRenderObject();
    if (obj is! RenderParagraph || !obj.attached) return;
    final offset = _verseStart[ayahId] ?? 0;
    final boxes = obj.getBoxesForSelection(
      TextSelection(
        baseOffset: offset,
        extentOffset: offset + 1,
      ),
    );
    if (boxes.isEmpty) return;
    final groupGlobalY = obj.localToGlobal(Offset.zero).dy;
    final viewportGlobalY = (context.findRenderObject()! as RenderBox)
        .localToGlobal(Offset.zero)
        .dy;
    final target = (_controller.offset +
            (groupGlobalY - viewportGlobalY) +
            boxes.first.top -
            48)
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

  /// Finds the verse whose start sits at/above the viewport top and reports it.
  void _reportTopmost() {
    final onVisible = widget.onVisibleAyah;
    if (onVisible == null) return;
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    Ayah? current;
    outer:
    for (final group in groupAyahsBySurah(widget.ayahs)) {
      final key = _groupKeys[group.first.surahId];
      if (key?.currentContext == null) continue;
      final obj = key!.currentContext!.findRenderObject();
      if (obj is! RenderParagraph || !obj.attached) continue;
      final groupGlobalY = obj.localToGlobal(Offset.zero).dy;
      for (final ayah in group) {
        final offset = _verseStart[ayah.id] ?? 0;
        final boxes = obj.getBoxesForSelection(
          TextSelection(
            baseOffset: offset,
            extentOffset: offset + 1,
          ),
        );
        if (boxes.isEmpty) continue;
        if (groupGlobalY + boxes.first.top <= viewportTop + 12) {
          current = ayah;
        } else {
          break outer;
        }
      }
    }
    onVisible(current ?? widget.ayahs.first);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.arabicFontSize;
    return Stack(
      children: [
        // SizedBox.expand forces the inner Stack to fill the full Scaffold body
        // even when the surah content is shorter than the screen (e.g. Al-Fatihah).
        // Without it the Stack sizes to the ScrollView's content height, so
        // Positioned(bottom:0) would anchor to that short height instead of the
        // real screen bottom — causing the peek card to appear partially on-screen
        // after dismissal on short surahs.
        SizedBox.expand(
          child: SingleChildScrollView(
            controller: _controller,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in groupAyahsBySurah(widget.ayahs)) ...[
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
                  // One Text.rich per surah group → continuous inline flow. After
                  // each verse we append its number as Arabic-Indic digits: in
                  // KFGQPC UthmanicHafs1B the font's GSUB composes those digits into
                  // the ornate end-of-ayah rosette with the NUMBER INSIDE it. It is
                  // all real text, so it orders correctly in RTL and reflows/zooms
                  // natively — no U+06DD (that adds a second empty circle), no
                  // WidgetSpan/placeholder (those bidi-reverse) and no overlay
                  // (invisible on-device). The number span keeps the surah text's
                  // font (only the colour differs) so the substitution still fires.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onGroupTap(d, group),
                    child: Text.rich(
                      key: _groupKeyFor(group.first.surahId),
                      TextSpan(
                        children: [
                          for (final ayah in group) ...[
                            TextSpan(
                              text: ayah.textArabic,
                              style: (_highlightAyahId == ayah.id ||
                                      _selectedAyah?.id == ayah.id)
                                  ? TextStyle(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.16),
                                    )
                                  : null,
                            ),
                            TextSpan(
                              text: ' ${_toArabicIndic(ayah.ayahNumber)} ',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      locale: const Locale('ar'),
                      style: QuranTextStyle.madani.copyWith(
                        fontSize: fontSize,
                        height: 1.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ],
            ),
          ),
        ), // SizedBox.expand
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
                onToggleLanguage: widget.onToggleLanguage,
                onDismiss: _dismissPeek,
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
    final gold = AppTheme.ornamentGold(Theme.of(context).brightness);
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
    required this.onToggleLanguage,
    required this.onDismiss,
  });

  final Ayah? ayah;
  final List<TranslationResource> resources;
  final String? surahName;
  final double fontSize;
  final Set<String> selected;
  final ValueChanged<String>? onToggleLanguage;
  final VoidCallback onDismiss;

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
                    // Reference + multi-select language chips (the shared
                    // selection, also reflected in Detailed view).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
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
                        if (available.length > 1)
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final r in available)
                                _PeekLangChip(
                                  label: nativeLanguageName(r.languageCode),
                                  selected: selected.contains(r.languageCode),
                                  onTap: () =>
                                      onToggleLanguage?.call(r.languageCode),
                                ),
                            ],
                          ),
                      ],
                    ),
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

/// A small selectable language pill in the peek card's chip row.
class _PeekLangChip extends StatelessWidget {
  const _PeekLangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
