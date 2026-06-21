import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/reader_navigation.dart';

/// The Basmala, in the exact QPC Uthmanic encoding (matches the bundled font and
/// quran.db). Shown before every surah except Al-Fatihah (where it is ayah 1)
/// and At-Tawbah (which has none) — and only when a surah is shown from ayah 1.
const String _bismillah = 'بِسۡمِ ٱللَّهِ'
    ' ٱلرَّحۡمَٰنِ'
    ' ٱلرَّحِيمِ';

const int _surahAlFatiha = 1;
const int _surahAtTawbah = 9;

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

  // One zero-size anchor per ayah, so we can scroll to a verse and detect which
  // verse sits at the top of the viewport (the flowed text has no per-ayah
  // widgets otherwise).
  final Map<int, GlobalKey> _anchors = {};
  Timer? _highlightTimer;
  int? _highlightAyahId;

  int? _currentPage;
  bool _showPage = false; // pill is shown briefly while scrolling

  GlobalKey _anchorFor(int ayahId) =>
      _anchors.putIfAbsent(ayahId, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _currentPage = widget.ayahs.isNotEmpty ? widget.ayahs.first.page : null;
    _controller.addListener(_onScroll);
    final id = widget.focusAyahId;
    if (id != null && widget.ayahs.any((a) => a.id == id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus(id));
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _highlightTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final fraction = max <= 0 ? 0.0 : _controller.offset / max;
    final page = pageAtFraction(widget.ayahs, fraction);
    if (page != null && page != _currentPage) {
      setState(() => _currentPage = page);
    }
    // Reveal the pill, then fade it out — and record the resume point — after
    // the scroll settles.
    if (!_showPage) setState(() => _showPage = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _showPage = false);
      _reportTopmost();
    });
  }

  void _scrollToFocus(int ayahId) {
    if (!mounted) return;
    final ctx = _anchorFor(ayahId).currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.08,
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
    for (final ayah in widget.ayahs) {
      final ctx = _anchors[ayah.id]?.currentContext;
      final box = ctx?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= viewportTop + 12) {
        current = ayah; // still above the fold
      } else {
        break; // anchors are in document order
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
                Text.rich(
                  TextSpan(
                    children: [
                      for (final ayah in group) ...[
                        // Zero-size anchor at the verse start: lets us scroll to
                        // this verse and detect when it's at the viewport top.
                        WidgetSpan(
                          alignment: PlaceholderAlignment.top,
                          child: SelectionContainer.disabled(
                            child: SizedBox.shrink(key: _anchorFor(ayah.id)),
                          ),
                        ),
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
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: SelectionContainer.disabled(
                            child: AyahMedallion(
                              number: ayah.ayahNumber,
                              fontSize: fontSize,
                            ),
                          ),
                        ),
                        const TextSpan(text: ' '),
                      ],
                    ],
                  ),
                  // Centered (not justify): Flutter has no kashida
                  // justification, so justifying Arabic stretches glyph advances
                  // and breaks ligatures. Centering keeps shaping intact.
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: QuranTextStyle.madani.copyWith(
                    fontSize: fontSize,
                    height: 2.1,
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
        style: QuranTextStyle.madani.copyWith(fontSize: fontSize * 0.92),
      ),
    );
  }
}

/// Inline end-of-ayah marker: the verse number (Western numerals) inside a soft
/// tinted medallion, sized to sit with the surrounding Arabic line.
class AyahMedallion extends StatelessWidget {
  const AyahMedallion({
    required this.number,
    required this.fontSize,
    super.key,
  });

  final int number;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diameter = fontSize * 1.15;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: fontSize * 0.18),
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        '$number',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: fontSize * 0.42,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
