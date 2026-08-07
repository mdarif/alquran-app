import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../reader/domain/repositories/ayah_bookmark_repository.dart';
import '../../../reader/domain/repositories/ayah_repository.dart';
import '../../../reader/presentation/pages/bookmarks_page.dart';
import '../../../tafsir/presentation/tafsir_sheet.dart';
import '../../../translations/presentation/translations_sheet.dart';

/// The Library tab: the content-management home for Quran resources —
/// Bookmarks (saved verses), Translations, and Tafsir. Reuses the existing
/// sheets/pages as-is; this page is discoverability only, no new business
/// logic (matches the redesign plan's Technical Notes).
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: WidgetKeys.libraryPage,
      appBar: AppBar(title: const Text('Library')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _LibraryRow(
              rowKey: WidgetKeys.libraryBookmarksRow,
              icon: AppIcons.bookmark,
              title: 'Bookmarks',
              subtitle: 'Saved verses',
              onTap: () => _openBookmarks(context),
            ),
            _LibraryRow(
              rowKey: WidgetKeys.libraryTranslationsRow,
              icon: AppIcons.alKahf,
              title: 'Translations',
              subtitle: 'Manage translations',
              onTap: () => showTranslationsSheet(context),
            ),
            _LibraryRow(
              rowKey: WidgetKeys.libraryTafsirRow,
              icon: AppIcons.alKahf,
              title: 'Tafsir',
              subtitle: 'Read Tafsir',
              onTap: () => showTafsirSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openBookmarks(BuildContext context) {
    if (!GetIt.I.isRegistered<AyahBookmarkRepository>() ||
        !GetIt.I.isRegistered<AyahRepository>()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Restart Al Quran to finish enabling bookmarks'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookmarksPage(
          bookmarks: GetIt.I<AyahBookmarkRepository>(),
          ayahs: GetIt.I<AyahRepository>(),
        ),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: rowKey,
      leading: AppIcon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const AppIcon(AppIcons.chevronRight),
      onTap: onTap,
    );
  }
}
