import 'package:flutter/material.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';

enum ReadMode { surah, juz, page }

/// Compact Surah / Juz / Page switcher on the Read screen.
class StartReadingRow extends StatelessWidget {
  const StartReadingRow({
    required this.selectedMode,
    required this.onSurah,
    required this.onJuz,
    required this.onPage,
    super.key,
  });

  final ReadMode selectedMode;
  final VoidCallback onSurah;
  final VoidCallback onJuz;
  final VoidCallback onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          _StartReadingPill(
            widgetKey: WidgetKeys.startReadingSurah,
            icon: AppIcons.viewReading,
            label: 'Surah',
            selected: selectedMode == ReadMode.surah,
            onTap: onSurah,
          ),
          const SizedBox(width: 6),
          _StartReadingPill(
            widgetKey: WidgetKeys.startReadingJuz,
            icon: AppIcons.juz,
            label: 'Juz',
            selected: selectedMode == ReadMode.juz,
            onTap: onJuz,
          ),
          const SizedBox(width: 6),
          _StartReadingPill(
            widgetKey: WidgetKeys.startReadingPage,
            icon: AppIcons.page,
            label: 'Page',
            selected: selectedMode == ReadMode.page,
            onTap: onPage,
          ),
        ],
      ),
    );
  }
}

class _StartReadingPill extends StatelessWidget {
  const _StartReadingPill({
    required this.widgetKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key widgetKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          key: widgetKey,
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon,
                    size: AppIconSize.label,
                    color:
                        selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
