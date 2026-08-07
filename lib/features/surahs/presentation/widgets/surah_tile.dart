import 'package:flutter/material.dart';

import '../../../../core/format/surah_meta_labels.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/surah.dart';

class SurahTile extends StatelessWidget {
  const SurahTile({
    required this.surah,
    required this.onTap,
    this.verse,
    super.key,
  });

  final Surah surah;
  final VoidCallback onTap;

  /// When set (a verse-reference search hit like "18:5"), the row signals it
  /// opens at that verse: the subtitle reads "… · Ayah N" and a jump arrow shows.
  final int? verse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final placeLabel = revelationLabel(surah.revelationPlace);
    final subtitle = [
      if (placeLabel != null) placeLabel,
      // A verse hit ("18:5") replaces the ayah count — the row is about that
      // one verse, and three segments would crowd the line.
      if (verse != null)
        'Ayah $verse'
      else if (ayahCountLabel(surah.totalAyahs) case final count?)
        count,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 3, 20, 3),
          child: Row(
            children: [
              _SurahNumberBadge(number: surah.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.nameEnglish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              verse == null ? cs.onSurfaceVariant : cs.primary,
                          fontSize: 14,
                          fontWeight:
                              verse == null ? FontWeight.w400 : FontWeight.w600,
                          height: 1.12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              verse != null
                  ? AppIcon(
                      AppIcons.chevronRight,
                      size: AppIconSize.action,
                      color: cs.primary,
                    )
                  : Flexible(
                      flex: 0,
                      child: Text(
                        surah.nameArabic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.78),
                          fontFamily: AppTheme.arabicFontFamily,
                          fontFeatures: AppTheme.arabicFontFeatures,
                          fontSize: 26,
                          height: 1.2,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahNumberBadge extends StatelessWidget {
  const _SurahNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.78),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}
