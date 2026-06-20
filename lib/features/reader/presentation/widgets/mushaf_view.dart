import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah_heading.dart';

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
class MushafView extends StatelessWidget {
  const MushafView({
    required this.ayahs,
    required this.headings,
    required this.arabicFontSize,
    super.key,
  });

  final List<Ayah> ayahs;
  final Map<int, SurahHeading> headings;
  final double arabicFontSize;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in groupAyahsBySurah(ayahs)) ...[
            SurahHeaderCard(
              heading: headings[group.first.surahId],
              fallbackNumber: group.first.surahId,
            ),
            const SizedBox(height: 20),
            if (_showBismillah(group)) ...[
              Bismillah(fontSize: arabicFontSize),
              const SizedBox(height: 18),
            ],
            Text.rich(
              TextSpan(
                children: [
                  for (final ayah in group) ...[
                    TextSpan(text: ayah.textArabic),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: SelectionContainer.disabled(
                        child: AyahMedallion(
                          number: ayah.ayahNumber,
                          fontSize: arabicFontSize,
                        ),
                      ),
                    ),
                    const TextSpan(text: ' '),
                  ],
                ],
              ),
              // Centered (not justify): Flutter has no kashida justification, so
              // justifying Arabic stretches glyph advances and breaks ligatures.
              // Centering keeps shaping intact and balances the short last line.
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: QuranTextStyle.madani.copyWith(
                fontSize: arabicFontSize,
                height: 2.1,
              ),
            ),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  bool _showBismillah(List<Ayah> group) =>
      group.first.surahId != _surahAlFatiha &&
      group.first.surahId != _surahAtTawbah &&
      group.first.ayahNumber == 1;
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

/// Chapter header: a small number medallion above the English name (centered).
class SurahHeaderCard extends StatelessWidget {
  const SurahHeaderCard({
    required this.heading,
    required this.fallbackNumber,
    super.key,
  });

  final SurahHeading? heading;
  final int fallbackNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = heading?.number ?? fallbackNumber;
    final name = heading?.nameEnglish ?? 'Surah $number';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              '$number',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
