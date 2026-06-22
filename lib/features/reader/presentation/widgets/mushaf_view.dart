import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah_heading.dart';
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
    this.focusAyahId,
    this.onVisibleAyah,
    super.key,
  });

  final List<Ayah> ayahs;
  final Map<int, SurahHeading> headings;
  final double arabicFontSize;

  /// Global ayah id to scroll to on open (Last Read resume); null starts at top.
  final int? focusAyahId;

  /// Reports the topmost-visible verse as the user scrolls (debounced).
  final ValueChanged<Ayah>? onVisibleAyah;

  @override
  State<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends State<MushafView> {
  final ScrollController _controller = ScrollController();
  Timer? _hideTimer;
  Timer? _highlightTimer;
  int? _highlightAyahId;

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
    super.dispose();
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
        SingleChildScrollView(
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
                Text.rich(
                  key: _groupKeyFor(group.first.surahId),
                  TextSpan(
                    children: [
                      for (final ayah in group) ...[
                        TextSpan(
                          text: ayah.textArabic,
                          style: _highlightAyahId == ayah.id
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
                const SizedBox(height: 28),
              ],
            ],
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

/// Centred Basmala header rendered in the QPC face, scaled to the reading size.
class Bismillah extends StatelessWidget {
  const Bismillah({required this.fontSize, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _bismillah,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        locale: const Locale('ar'),
        style: QuranTextStyle.madani.copyWith(fontSize: fontSize * 0.92),
      ),
    );
  }
}
