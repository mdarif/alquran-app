import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/navigation/route_observer.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/repositories/last_read_repository.dart';
import '../pages/reader_page.dart';

/// A "continue reading" card showing the last opened section (PRD §12: last-read
/// resume). Hidden until something has been read; refreshes whenever the reader
/// is popped back to the host screen.
class ContinueReadingBanner extends StatefulWidget {
  const ContinueReadingBanner({super.key});

  @override
  State<ContinueReadingBanner> createState() => _ContinueReadingBannerState();
}

class _ContinueReadingBannerState extends State<ContinueReadingBanner>
    with RouteAware {
  ReaderTarget? _target;

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
    final target = await GetIt.I<LastReadRepository>().load();
    if (mounted) setState(() => _target = target);
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    if (target == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReaderPage(target: target),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.bookmark_rounded, color: onColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue reading',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: onColor.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        target.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: onColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
