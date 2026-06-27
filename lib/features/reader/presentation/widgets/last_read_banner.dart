import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/navigation/route_observer.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/repositories/ayah_repository.dart';
import '../../domain/repositories/last_read_repository.dart';
import '../pages/reader_page.dart';

/// A "Last Read" card that resumes at the exact verse the reader left off on
/// (PRD §12: last-read resume). Hidden until something has been read; refreshes
/// whenever the reader is popped back to the host screen.
class LastReadBanner extends StatefulWidget {
  const LastReadBanner({super.key});

  @override
  State<LastReadBanner> createState() => _LastReadBannerState();
}

class _LastReadBannerState extends State<LastReadBanner> with RouteAware {
  LastRead? _lastRead;
  String? _surahName;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _reload(); // returned here from the reader

  Future<void> _reload() async {
    final lastRead = await GetIt.I<LastReadRepository>().load();
    String? name;
    if (lastRead != null) {
      final headings = await GetIt.I<AyahRepository>().getSurahHeadings();
      name = headings[lastRead.surahId]?.nameEnglish;
    }
    if (mounted) {
      setState(() {
        _lastRead = lastRead;
        _surahName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastRead = _lastRead;
    if (lastRead == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimaryContainer;
    final reference =
        '${_surahName ?? lastRead.target.title} · Ayah ${lastRead.ayahNumber}';

    return Padding(
      // No top padding: the app bar already provides the breathing room, so the
      // card sits snug under it instead of leaving a gap.
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: Material(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: WidgetKeys.lastReadCard,
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReaderPage(
                target: lastRead.target,
                focusAyahId: lastRead.ayahId,
                initialDetailed: lastRead.detailed,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.bookmark,
                  filled: true,
                  size: AppIconSize.label,
                  color: onColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last Read',
                  style: theme.textTheme.labelMedium?.copyWith(
                    // Full token colour (not a reduced alpha): keeps the AA
                    // contrast the M3 pair guarantees. Hierarchy vs the bold
                    // reference comes from weight, not lower opacity.
                    color: onColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppIcon(
                  AppIcons.chevronRight,
                  size: AppIconSize.label,
                  color: onColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
