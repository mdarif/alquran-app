import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/theme_cubit.dart';

/// Bottom sheet holding the reader's display controls — theme, viewport, and
/// text size — so the app bar can stay minimal (just a single settings icon).
///
/// View and text size hold local state and call back to the reader page so the
/// page updates live behind the sheet; theme is driven through [ThemeCubit]
/// (provided to the sheet via `BlocProvider.value`).
class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    required this.fontSize,
    required this.minFont,
    required this.maxFont,
    required this.detailed,
    required this.onFontSize,
    required this.onDetailedChanged,
    super.key,
  });

  final double fontSize;
  final double minFont;
  final double maxFont;
  final bool detailed;
  final ValueChanged<double> onFontSize;
  final ValueChanged<bool> onDetailedChanged;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late double _fontSize = widget.fontSize;
  late bool _detailed = widget.detailed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Display', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            _Section(
              label: 'Theme',
              child: BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, mode) {
                  final isDark = mode == ThemeMode.dark;
                  return SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {isDark},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => context
                        .read<ThemeCubit>()
                        .setMode(s.first ? ThemeMode.dark : ThemeMode.light),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _Section(
              label: 'View',
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Reading'),
                    icon: Icon(Icons.menu_book_rounded),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Detailed'),
                    icon: Icon(Icons.subject_rounded),
                  ),
                ],
                selected: {_detailed},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() => _detailed = s.first);
                  widget.onDetailedChanged(s.first);
                },
              ),
            ),
            const SizedBox(height: 20),
            _Section(
              label: 'Text size',
              child: Row(
                children: [
                  Text('A', style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Slider(
                      value: _fontSize.clamp(widget.minFont, widget.maxFont),
                      min: widget.minFont,
                      max: widget.maxFont,
                      divisions:
                          ((widget.maxFont - widget.minFont) / 2).round(),
                      label: '${_fontSize.round()}',
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        widget.onFontSize(v);
                      },
                    ),
                  ),
                  Text('A', style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labeled row: caption above its control.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
