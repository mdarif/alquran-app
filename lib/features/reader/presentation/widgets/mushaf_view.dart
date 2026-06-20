import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ayah.dart';

/// Reading viewport (PRD 4.3): Arabic-only, continuous Mushaf-style flow with
/// no translations. Ayahs run together into one justified RTL block — each
/// closed by an English verse number set in a light medallion — beneath a
/// surah header carrying the chapter number and English name.
class MushafView extends StatelessWidget {
  const MushafView({
    required this.ayahs,
    required this.arabicFontSize,
    required this.surahNumber,
    required this.surahName,
    super.key,
  });

  final List<Ayah> ayahs;
  final double arabicFontSize;
  final int surahNumber;
  final String surahName;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SurahHeader(
            number: surahNumber,
            name: surahName,
            ayahCount: ayahs.length,
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              children: [
                for (final ayah in ayahs) ...[
                  TextSpan(text: ayah.textArabic),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _AyahMedallion(
                      number: ayah.ayahNumber,
                      fontSize: arabicFontSize,
                    ),
                  ),
                  const TextSpan(text: ' '),
                ],
              ],
            ),
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.arabicFontFamily,
              fontSize: arabicFontSize,
              height: 2.1,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative chapter header: number, English name, ayah count.
class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
    required this.number,
    required this.name,
    required this.ayahCount,
  });

  final int number;
  final String name;
  final int ayahCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              '$number',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Surah $number · $ayahCount ayahs',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline end-of-ayah marker: the verse number (Western numerals) inside a
/// soft tinted medallion, sized to sit with the surrounding Arabic line.
class _AyahMedallion extends StatelessWidget {
  const _AyahMedallion({required this.number, required this.fontSize});

  final int number;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diameter = fontSize * 1.35;
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
          fontFamily: null, // platform sans — Western numerals, not the QPC face
          fontSize: fontSize * 0.42,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
