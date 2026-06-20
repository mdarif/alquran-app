import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/ayah_share.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/translation_resource.dart';

/// Detailed-mode row (PRD 4.3): Arabic stacked over each translation.
class AyahTile extends StatelessWidget {
  const AyahTile({
    required this.ayah,
    required this.resources,
    required this.arabicFontSize,
    this.surahName,
    super.key,
  });

  final Ayah ayah;
  final List<TranslationResource> resources;
  final double arabicFontSize;
  final String? surahName;

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
              if (ayah.isSajda) ...[
                const SizedBox(width: 8),
                Icon(Icons.star, size: 16, color: theme.colorScheme.tertiary),
              ],
              const Spacer(),
              PopupMenuButton<_AyahAction>(
                tooltip: 'Copy or share',
                icon: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _AyahAction.copy,
                    child: ListTile(
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Copy'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _AyahAction.share,
                    child: ListTile(
                      leading: Icon(Icons.share_rounded),
                      title: Text('Share'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
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

  Future<void> _onAction(BuildContext context, _AyahAction action) async {
    final text = buildAyahShareText(
      ayah: ayah,
      resources: resources,
      surahName: surahName,
    );
    switch (action) {
      case _AyahAction.copy:
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ayah copied'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      case _AyahAction.share:
        await SharePlus.instance.share(ShareParams(text: text));
    }
  }
}

enum _AyahAction { copy, share }

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
          '${languageName(resource.languageCode)} · ${resource.name}',
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
