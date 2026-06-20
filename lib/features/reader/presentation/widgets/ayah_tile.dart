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
        // Stretch so the Arabic and each translation fill the row width and can
        // be aligned by script (Arabic/Urdu → right, English → left).
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Icon(Icons.star, size: 16, color: theme.colorScheme.tertiary),
            ],
          ),
          const SizedBox(height: 10),
          // Arabic (RTL, scalable for low-vision accessibility — PRD 4.1)
          Text(
            ayah.textArabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: QuranTextStyle.madani.copyWith(fontSize: arabicFontSize),
          ),
          for (final r in resources)
            if (ayah.translations[r.id] != null)
              _Translation(resource: r, text: ayah.translations[r.id]!),
        ],
      ),
    );
  }
}

/// One translation: a small left-aligned attribution label over the text, which
/// is aligned by its script (Urdu RTL → right, English LTR → left).
class _Translation extends StatelessWidget {
  const _Translation({required this.resource, required this.text});

  final TranslationResource resource;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = resource.languageCode == 'ur';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text(
          '${_languageName(resource.languageCode)} · ${resource.name}',
          textAlign: TextAlign.left,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: resource.languageCode.scriptStyle(
            theme.textTheme.bodyLarge!.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

String _languageName(String code) => switch (code) {
      'ur' => 'Urdu',
      'en' => 'English',
      'hi' => 'Hindi',
      _ => code.toUpperCase(),
    };
