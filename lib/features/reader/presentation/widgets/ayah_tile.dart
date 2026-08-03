import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/experimental_pill.dart';
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
    this.showArabic = true,
    this.highlight = false,
    this.audioState,
    this.onTogglePlay,
    this.isBookmarked = false,
    this.onToggleBookmark,
    this.onOpenTranslations,
    this.onScreenshotPage,
    super.key,
  });

  final Ayah ayah;
  final List<TranslationResource> resources;
  final double arabicFontSize;

  /// Base Arabic style for the ayah text (Uthmani default / IndoPak Noorehuda).
  final TextStyle arabicStyle;
  final String? surahName;

  /// Whether to render the Arabic matn above the translations. Off = a
  /// translations-only reading (Detailed "Show Arabic" turned off).
  final bool showArabic;

  /// Briefly tints the tile when the reader resumes on this verse (Last Read).
  final bool highlight;

  /// Live recitation state (audio feature on); null when off. Drives the play
  /// button's icon and the now-playing tint for THIS verse.
  final AyahAudioState? audioState;

  /// Toggle recitation for this verse. Null hides the play control entirely
  /// (the flag-off path renders exactly as before).
  final VoidCallback? onTogglePlay;

  /// Whether this verse is saved as an ayah bookmark. The storage layer owns the
  /// truth; this tile only renders the affordance.
  final bool isBookmarked;

  /// Toggle this verse's bookmark. Null hides the visible bookmark affordance
  /// until bookmark persistence is wired.
  final VoidCallback? onToggleBookmark;

  /// Opens the reader-wide translation picker from this ayah's menu.
  final VoidCallback? onOpenTranslations;

  /// Capture the whole visible page as an image and share it — wired from the
  /// Detailed list (which owns the RepaintBoundary). Null hides the ⋯ menu's
  /// Screenshot item.
  final VoidCallback? onScreenshotPage;

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
                  semanticsLabel: 'Verse ${ayah.ayahNumber}',
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
              if (onToggleBookmark != null)
                IconButton(
                  key: WidgetKeys.ayahBookmarkButton(ayah.id),
                  tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark ayah',
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleBookmark,
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isBookmarked
                          ? theme.colorScheme.primaryContainer
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.bookmark,
                        filled: isBookmarked,
                        size: AppIconSize.action,
                        color: isBookmarked
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              PopupMenuButton<_AyahAction>(
                tooltip: 'Ayah options',
                icon: AppIcon(
                  AppIcons.more,
                  size: AppIconSize.action,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _AyahAction.copy,
                    height: _CompactMenuItem.height,
                    padding: EdgeInsets.zero,
                    child: _CompactMenuItem(
                      icon: AppIcons.copy,
                      label: 'Copy',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _AyahAction.share,
                    height: _CompactMenuItem.height,
                    padding: EdgeInsets.zero,
                    child: _CompactMenuItem(
                      icon: AppIcons.share,
                      label: 'Share',
                    ),
                  ),
                  if (onToggleBookmark != null)
                    PopupMenuItem(
                      value: _AyahAction.bookmark,
                      height: _CompactMenuItem.height,
                      padding: EdgeInsets.zero,
                      child: _CompactMenuItem(
                        icon: AppIcons.bookmark,
                        filled: isBookmarked,
                        label: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                      ),
                    ),
                  if (onOpenTranslations != null)
                    const PopupMenuItem(
                      value: _AyahAction.translations,
                      height: _CompactMenuItem.height,
                      padding: EdgeInsets.zero,
                      child: _CompactMenuItem(
                        icon: AppIcons.viewReading,
                        label: 'Translations',
                      ),
                    ),
                  // Whole-page image, not just this verse — captures every verse
                  // currently on screen (see [onScreenshotPage]).
                  if (onScreenshotPage != null)
                    const PopupMenuItem(
                      value: _AyahAction.screenshot,
                      height: _CompactMenuItem.height,
                      padding: EdgeInsets.zero,
                      child: _CompactMenuItem(
                        icon: AppIcons.screenshot,
                        label: 'Screenshot page',
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (showArabic) ...[
            const SizedBox(height: 10),
            // Arabic (RTL, scalable for low-vision accessibility — PRD 4.1)
            Text(
              ayah.textArabic,
              key: WidgetKeys.ayahArabicText,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              // Tag the script so TalkBack/VoiceOver pick the Arabic speech engine.
              locale: const Locale('ar'),
              style: arabicStyle.copyWith(fontSize: arabicFontSize),
            ),
          ],
          for (final r in resources)
            if (ayah.translations[r.slug] != null)
              _Translation(
                resource: r,
                text: ayah.translations[r.slug]!,
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
    // Screenshot captures the whole visible page, not this verse's text, so it's
    // owned by the Detailed list (which holds the RepaintBoundary) — delegate and
    // return; it does its own error handling.
    if (action == _AyahAction.screenshot) {
      onScreenshotPage?.call();
      return;
    }
    if (action == _AyahAction.translations) {
      onOpenTranslations?.call();
      return;
    }
    if (action == _AyahAction.bookmark) {
      onToggleBookmark?.call();
      return;
    }
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
        case _AyahAction.bookmark:
        case _AyahAction.translations:
          break; // handled above
        case _AyahAction.screenshot:
          break; // handled above
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

enum _AyahAction { copy, share, bookmark, translations, screenshot }

class _CompactMenuItem extends StatelessWidget {
  const _CompactMenuItem({
    required this.icon,
    required this.label,
    this.filled = false,
  });

  static const double height = 44;

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: AppIcon(
              icon,
              filled: filled,
              size: AppIconSize.label,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final isRtl = resource.isRtl;
    final isExperimental = resource.experimental;
    final credit = resource.displayCredit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Flexible(
              child: Text(
                // Just the author — the script already makes the language obvious.
                credit,
                textAlign: TextAlign.left,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isExperimental) ...[
              const SizedBox(width: 6),
              const ExperimentalPill(),
            ],
          ],
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
            isRtl: isRtl,
          ),
        ),
      ],
    );
  }
}
