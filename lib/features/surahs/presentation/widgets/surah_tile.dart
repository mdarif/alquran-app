import 'package:flutter/material.dart';

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
    final place = surah.revelationPlace;
    final placeLabel =
        place == null ? '' : '${place[0].toUpperCase()}${place.substring(1)}';
    final subtitle = [
      if (placeLabel.isNotEmpty) placeLabel,
      if (verse != null) 'Ayah $verse',
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: cs.primaryContainer,
        child: Text(
          '${surah.id}',
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        surah.nameEnglish,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: verse == null
                  ? null
                  : TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
            ),
      trailing: verse != null
          ? AppIcon(
              AppIcons.chevronRight,
              size: AppIconSize.action,
              color: cs.primary,
            )
          : Text(
              surah.nameArabic,
              style: const TextStyle(
                fontFamily: AppTheme.arabicFontFamily,
                fontSize: 28,
              ),
            ),
    );
  }
}
