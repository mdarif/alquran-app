import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/translation_resource.dart';

/// Detailed-mode row (PRD 4.3): Arabic stacked over each translation.
class AyahTile extends StatelessWidget {
  const AyahTile({
    required this.ayah,
    required this.resources,
    required this.arabicFontSize,
    super.key,
  });

  final Ayah ayah;
  final List<TranslationResource> resources;
  final double arabicFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  '${ayah.ayahNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              if (ayah.isSajda)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.star,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              if (ayah.page != null)
                Text('p. ${ayah.page}', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          // Arabic (RTL, scalable for low-vision accessibility — PRD 4.1)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              ayah.textArabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: QuranTextStyle.madani.copyWith(fontSize: arabicFontSize),
            ),
          ),
          for (final r in resources)
            if (ayah.translations[r.id] != null) ...[
              const SizedBox(height: 10),
              Text(
                ayah.translations[r.id]!,
                textDirection: r.languageCode == 'ur'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: r.languageCode.scriptStyle(
                  theme.textTheme.bodyLarge!.copyWith(height: 1.5),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
