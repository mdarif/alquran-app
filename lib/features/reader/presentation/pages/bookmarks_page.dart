import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/ayah_share.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/ayah_bookmark_repository.dart';
import '../../domain/repositories/ayah_repository.dart';
import 'reader_page.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({
    required this.bookmarks,
    required this.ayahs,
    super.key,
  });

  final AyahBookmarkRepository bookmarks;
  final AyahRepository ayahs;

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  late Future<_BookmarksData> _bookmarksData = _load();

  Future<_BookmarksData> _load() async {
    final bookmarked = await widget.bookmarks.bookmarkedAyahs();
    final headings = await widget.ayahs.getSurahHeadings();
    final resources = await widget.ayahs.getTranslationResources();
    return _BookmarksData(
      ayahs: bookmarked,
      headings: headings,
      resources: {for (final resource in resources) resource.slug: resource},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: WidgetKeys.bookmarksPage,
      appBar: AppBar(title: const Text('Bookmarks')),
      body: FutureBuilder<_BookmarksData>(
        future: _bookmarksData,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.ayahs.isEmpty) {
            return const _EmptyBookmarks();
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 10),
            children: [
              const _SectionHeader('Ayah Bookmarks'),
              for (final ayah in data.ayahs)
                _BookmarkRow(
                  ayah: ayah,
                  heading: data.headings[ayah.surahId],
                  resources: data.resources,
                  onTap: () {
                    _openAyah(context, ayah, data.headings[ayah.surahId]);
                  },
                  onRemove: () => _removeBookmark(ayah),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeBookmark(Ayah ayah) async {
    await widget.bookmarks.setBookmarked(ayah.id, false);
    if (!mounted) return;
    setState(() => _bookmarksData = _load());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Bookmark removed'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  void _openAyah(BuildContext context, Ayah ayah, SurahHeading? heading) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          target: ReaderTarget.surah(
            ayah.surahId,
            heading?.nameEnglish ?? 'Surah ${ayah.surahId}',
          ),
          focusAyahId: ayah.id,
          initialDetailed: true,
        ),
      ),
    );
  }
}

class _BookmarksData {
  const _BookmarksData({
    required this.ayahs,
    required this.headings,
    required this.resources,
  });

  final List<Ayah> ayahs;
  final Map<int, SurahHeading> headings;
  final Map<String, TranslationResource> resources;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 11, 18, 10),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.ayah,
    required this.heading,
    required this.resources,
    required this.onTap,
    required this.onRemove,
  });

  final Ayah ayah;
  final SurahHeading? heading;
  final Map<String, TranslationResource> resources;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 11, 20, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppIcon(
              AppIcons.bookmark,
              filled: true,
              size: AppIconSize.bar,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Surah ${heading?.nameEnglish ?? ayah.surahId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${ayah.surahId}:${ayah.ayahNumber}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _metadata {
    final parts = <String>['Ayah ${ayah.surahId}:${ayah.ayahNumber}'];
    if (ayah.page != null) parts.add('Page ${ayah.page}');
    if (ayah.juz != null) parts.add('Juz ${ayah.juz}');
    return parts.join(' · ');
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const AppIcon(AppIcons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(context).pop();
                  _share();
                },
              ),
              ListTile(
                leading: AppIcon(
                  AppIcons.bookmark,
                  filled: true,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Remove bookmark'),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemove();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buildAyahShareText(
            ayah: ayah,
            resources: resources.values.toList(growable: false),
            surahName: heading?.nameEnglish,
          ),
        ),
      );
    } catch (_) {
      // Best-effort: no share target, cancelled sheet, or platform failure.
    }
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.bookmark,
              filled: true,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('No bookmarks yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Bookmark an ayah from Detailed mode.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
