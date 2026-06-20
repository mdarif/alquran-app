import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/surah.dart';

class SurahTile extends StatelessWidget {
  const SurahTile({required this.surah, required this.onTap, super.key});

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = surah.revelationPlace;
    final placeLabel =
        place == null ? '' : '${place[0].toUpperCase()}${place.substring(1)}';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          '${surah.id}',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        surah.nameEnglish,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      // Revelation place only (ayah count dropped to declutter the list).
      subtitle: placeLabel.isEmpty ? null : Text(placeLabel),
      trailing: Text(
        surah.nameArabic,
        style: const TextStyle(
          fontFamily: AppTheme.arabicFontFamily,
          fontSize: 28,
        ),
      ),
    );
  }
}
