import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

class SheetManagerHeader extends StatelessWidget {
  const SheetManagerHeader({
    required this.title,
    required this.search,
    required this.searchFieldKey,
    required this.searchClearKey,
    required this.filters,
    this.titleMeta,
    super.key,
  });

  final String title;
  final TextEditingController search;
  final Key searchFieldKey;
  final Key searchClearKey;
  final Widget filters;
  final Widget? titleMeta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: titleMeta == null ? 38 : 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const AppIcon(AppIcons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        height: 1.05,
                      ),
                    ),
                    if (titleMeta != null) ...[
                      const SizedBox(height: 3),
                      titleMeta!,
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: TextField(
              key: searchFieldKey,
              controller: search,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.1,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search',
                prefixIcon: const AppIcon(AppIcons.search, size: 20),
                prefixIconConstraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 42,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: search,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      key: searchClearKey,
                      tooltip: 'Clear search',
                      icon: const AppIcon(AppIcons.close, size: 18),
                      onPressed: search.clear,
                    );
                  },
                ),
                suffixIconConstraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 42,
                ),
                filled: true,
                fillColor: cs.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: cs.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          filters,
        ],
      ),
    );
  }
}
