import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ayah_share.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/translation_resource.dart';
import '../cubit/ayah_audio_cubit.dart';

/// Detailed-mode row (PRD 4.3): Arabic stacked over each translation.
class AyahTile extends StatelessWidget {
  const AyahTile({
    required this.ayah,
    required this.resources,
    required this.arabicFontSize,
    this.arabicStyle = QuranTextStyle.madani,
    this.surahName,
    this.highlight = false,
    this.audioState,
    this.onTogglePlay,
    super.key,
  });

  final Ayah ayah;
  final List<TranslationResource> resources;
  final double arabicFontSize;

  /// Base Arabic style for the ayah text (Uthmani default / IndoPak Noorehuda).
  final TextStyle arabicStyle;
  final String? surahName;

  /// Briefly tints the tile when the reader resumes on this verse (Last Read).
  final bool highlight;

  /// Live recitation state (audio feature on); null when off. Drives the play
  /// button's icon and the now-playing tint for THIS verse.
  final AyahAudioState? audioState;

  /// Toggle recitation for this verse. Null hides the play control entirely
  /// (the flag-off path renders exactly as before).
  final VoidCallback? onTogglePlay;

  /// Neutral Arabic size: at this value translations keep their designed size.
  static const double _baseArabicFontSize = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Translations scale with the same font control as the Arabic (accessibility
    // — PRD 4.1), proportionally so the in-app +/- and pinch enlarge the whole
    // verse, not just the Arabic line.
    final baseTranslationSize = theme.textTheme.bodyLarge?.fontSize ?? 16;
    final translationFontSize =
        baseTranslationSize * (arabicFontSize / _baseArabicFontSize);

    // Now-playing gets a distinct (tertiary/gold) sticky tint so it reads
    // differently from the brief Last-Read flash (primary).
    final isAudioActive = audioState?.isActive(ayah.id) ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      color: isAudioActive
          ? theme.colorScheme.tertiary.withValues(alpha: 0.10)
          : highlight
              ? theme.colorScheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
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
                AppIcon(
                  AppIcons.sajda,
                  filled: true,
                  size: AppIconSize.inline,
                  color: theme.colorScheme.tertiary,
                  // The star is the only signal that this is a prostration
                  // verse — give screen readers the meaning, not just a shape.
                  semanticLabel: 'Sajda — prostration verse',
                ),
              ],
              const Spacer(),
              if (onTogglePlay != null) _playButton(theme),
              PopupMenuButton<_AyahAction>(
                tooltip: 'Copy or share',
                icon: AppIcon(
                  AppIcons.more,
                  size: AppIconSize.action,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _AyahAction.copy,
                    child: ListTile(
                      leading: AppIcon(AppIcons.copy),
                      title: Text('Copy'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _AyahAction.share,
                    child: ListTile(
                      leading: AppIcon(AppIcons.share),
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
            // Tag the script so TalkBack/VoiceOver pick the Arabic speech engine.
            locale: const Locale('ar'),
            style: arabicStyle.copyWith(fontSize: arabicFontSize),
          ),
          for (final r in resources)
            if (ayah.translations[r.id] != null)
              _Translation(
                resource: r,
                text: ayah.translations[r.id]!,
                fontSize: translationFontSize,
              ),
        ],
      ),
    );
  }

  /// The per-verse recitation control: play ▸ / pause ❚❚ / a spinner while
  /// buffering / an error glyph (tap to retry). Shown only when [onTogglePlay]
  /// is wired (audio feature on).
  Widget _playButton(ThemeData theme) {
    final cs = theme.colorScheme;
    final audio = audioState;
    final Widget icon;
    var tooltip = 'Play recitation';
    if (audio != null && audio.isLoading(ayah.id)) {
      icon = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      );
      tooltip = 'Loading…';
    } else if (audio != null && audio.isPlaying(ayah.id)) {
      icon = AppIcon(
        AppIcons.pause,
        size: AppIconSize.action,
        color: cs.primary,
      );
      tooltip = 'Pause';
    } else if (audio != null && audio.hasError(ayah.id)) {
      icon = AppIcon(
        AppIcons.audioError,
        size: AppIconSize.action,
        color: cs.error,
      );
      tooltip = 'Couldn\'t play — tap to retry';
    } else {
      icon = AppIcon(
        AppIcons.play,
        size: AppIconSize.action,
        color: cs.onSurfaceVariant,
      );
    }
    return IconButton(
      key: WidgetKeys.ayahPlayButton(ayah.id),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTogglePlay,
      icon: icon,
    );
  }

  Future<void> _onAction(BuildContext context, _AyahAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = buildAyahShareText(
      ayah: ayah,
      resources: resources,
      surahName: surahName,
    );
    try {
      switch (action) {
        case _AyahAction.copy:
          await Clipboard.setData(ClipboardData(text: text));
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Ayah copied'),
              duration: Duration(seconds: 1),
            ),
          );
        case _AyahAction.share:
          await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (_) {
      // Never let a clipboard/share failure crash the reader.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            action == _AyahAction.copy ? 'Could not copy' : 'Could not share',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

enum _AyahAction { copy, share }

/// One translation: a small left-aligned attribution label over the text, which
/// is aligned by its script (Urdu RTL → right, English LTR → left).
class _Translation extends StatelessWidget {
  const _Translation({
    required this.resource,
    required this.text,
    required this.fontSize,
  });

  final TranslationResource resource;
  final String text;

  /// Translation body size, scaled by the reader's font control.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = resource.languageCode == 'ur';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text(
          // Just the author — the script already makes the language obvious.
          resource.attribution,
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
          // Tag the translation's language for correct screen-reader pronunciation.
          locale: Locale(resource.languageCode),
          style: resource.languageCode.scriptStyle(
            theme.textTheme.bodyLarge!
                .copyWith(height: 1.5, fontSize: fontSize),
          ),
        ),
      ],
    );
  }
}
