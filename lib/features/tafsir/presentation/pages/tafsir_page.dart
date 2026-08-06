import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../cubit/tafsir_cubit.dart';

class TafsirPage extends StatefulWidget {
  const TafsirPage({this.showHeader = true, super.key});

  final bool showHeader;

  @override
  State<TafsirPage> createState() => _TafsirPageState();
}

class _TafsirPageState extends State<TafsirPage> {
  final TextEditingController _search = TextEditingController();
  String _languageFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: WidgetKeys.tafsirPage,
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: BlocBuilder<TafsirCubit, TafsirState>(
          builder: (context, state) {
            if (state.status == TafsirStatus.loading && state.items.isEmpty) {
              return const _Loading();
            }
            return Column(
              children: [
                if (widget.showHeader)
                  _Header(
                    search: _search,
                    items: state.items,
                    languageFilter: _languageFilter,
                    onLanguageFilterChanged: (value) =>
                        setState(() => _languageFilter = value),
                  ),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _search,
                    builder: (context, value, _) => RefreshIndicator(
                      onRefresh: () => context.read<TafsirCubit>().load(),
                      child: _List(
                        state: state,
                        query: value.text.trim().toLowerCase(),
                        languageFilter: _languageFilter,
                        compact: !widget.showHeader,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 360,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.search,
    required this.items,
    required this.languageFilter,
    required this.onLanguageFilterChanged,
  });

  final TextEditingController search;
  final List<TafsirItem> items;
  final String languageFilter;
  final ValueChanged<String> onLanguageFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
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
                Text(
                  'Tafsir',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: WidgetKeys.tafsirSearchField,
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const AppIcon(AppIcons.search),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: search,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    key: WidgetKeys.tafsirSearchClear,
                    tooltip: 'Clear search',
                    icon: const AppIcon(AppIcons.close),
                    onPressed: search.clear,
                  );
                },
              ),
              filled: true,
              fillColor: cs.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _LanguageFilters(
            items: items,
            selected: languageFilter,
            onSelected: onLanguageFilterChanged,
          ),
        ],
      ),
    );
  }
}

class _LanguageFilters extends StatelessWidget {
  const _LanguageFilters({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<TafsirItem> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final codes = {
      for (final item in items) item.languageCode.toLowerCase(),
    }.where((code) => code.isNotEmpty).toList()
      ..sort(_compareLanguages);
    if (codes.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChipButton(
            code: 'all',
            label: 'All',
            selected: selected == 'all',
            onSelected: onSelected,
          ),
          for (final code in codes) ...[
            const SizedBox(width: 8),
            _FilterChipButton(
              code: code,
              label: _languageLabel(code),
              selected: selected == code,
              onSelected: onSelected,
            ),
          ],
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  int _compareLanguages(String a, String b) {
    int rank(String code) {
      return switch (code) {
        'ur' => 0,
        'en' => 1,
        'ar' => 2,
        _ => 10,
      };
    }

    final cmp = rank(a).compareTo(rank(b));
    return cmp == 0 ? a.compareTo(b) : cmp;
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.code,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String code;
  final String label;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: WidgetKeys.tafsirLanguageFilter(code),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(code),
      showCheckmark: false,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.state,
    required this.query,
    required this.languageFilter,
    required this.compact,
  });

  final TafsirState state;
  final String query;
  final String languageFilter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shown = _filter([
      for (final item in state.items)
        if (item.status == TafsirItemStatus.installed && item.selected) item,
    ]);
    final downloaded = _filter([
      for (final item in state.items)
        if (item.status == TafsirItemStatus.installed && !item.selected) item,
    ]);
    final available = _filter([
      for (final item in state.items)
        if (item.status == TafsirItemStatus.available ||
            item.status == TafsirItemStatus.installing ||
            item.status == TafsirItemStatus.failed)
          item,
    ]);
    final planned = _filter([
      for (final item in state.items)
        if (item.status == TafsirItemStatus.unavailable) item,
    ]);

    return ListView(
      padding: EdgeInsets.fromLTRB(24, compact ? 0 : 6, 24, 18),
      children: [
        if (state.catalogueUnavailable)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _Notice('New Tafsir downloads are unavailable offline.'),
          ),
        _Section(title: 'Shown in reader', items: shown),
        if (shown.isNotEmpty && downloaded.isNotEmpty)
          const SizedBox(height: 14),
        _Section(title: 'Downloaded', items: downloaded),
        if ((shown.isNotEmpty || downloaded.isNotEmpty) && available.isNotEmpty)
          const SizedBox(height: 14),
        _Section(title: 'Available for download', items: available),
        if ((shown.isNotEmpty ||
                downloaded.isNotEmpty ||
                available.isNotEmpty) &&
            planned.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
        ],
        _Section(title: 'Planned', items: planned),
        if (shown.isEmpty &&
            downloaded.isEmpty &&
            available.isEmpty &&
            planned.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: _EmptyLine('No Tafsir found'),
          ),
      ],
    );
  }

  List<TafsirItem> _filter(List<TafsirItem> items) {
    final filtered = [
      for (final item in items)
        if (_matchesLanguage(item) &&
            (query.isEmpty || _searchText(item).contains(query)))
          item,
    ];
    return filtered..sort(_compareItems);
  }

  bool _matchesLanguage(TafsirItem item) =>
      languageFilter == 'all' ||
      item.languageCode.toLowerCase() == languageFilter;

  String _searchText(TafsirItem item) {
    return [
      item.name,
      item.languageCode,
      _languageLabel(item.languageCode),
      item.author ?? '',
      item.nativeName ?? '',
    ].join(' ').toLowerCase();
  }

  int _compareItems(TafsirItem a, TafsirItem b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    final lang = _languageRank(a.languageCode).compareTo(
      _languageRank(b.languageCode),
    );
    if (lang != 0) return lang;
    return a.name.compareTo(b.name);
  }

  int _languageRank(String code) {
    return switch (code.toLowerCase()) {
      'ur' => 0,
      'en' => 1,
      'ar' => 2,
      _ => 10,
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<TafsirItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        for (final item in items) _TafsirRow(item: item),
      ],
    );
  }
}

class _TafsirRow extends StatelessWidget {
  const _TafsirRow({required this.item});

  final TafsirItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      key: WidgetKeys.tafsirResourceRow(item.slug),
      onTap: _onTap(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(width: 26, child: _Leading(item: item)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _titleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_sizeLabel.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          _sizeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (item.status == TafsirItemStatus.failed &&
                      item.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Action(item: item),
          ],
        ),
      ),
    );
  }

  String get _titleLabel => _languageLabel(item.languageCode);

  String get _subtitleLabel {
    final suffix = item.abridged ? ' (Abridged)' : '';
    return '${item.name}$suffix';
  }

  String get _sizeLabel {
    if (item.downloadBytes <= 0 ||
        item.status == TafsirItemStatus.installed ||
        item.status == TafsirItemStatus.unavailable) {
      return '';
    }
    return '(${_formatBytes(item.downloadBytes)})';
  }

  VoidCallback? _onTap(BuildContext context) {
    if (item.status == TafsirItemStatus.available ||
        item.status == TafsirItemStatus.failed) {
      return () => context.read<TafsirCubit>().install(item.slug);
    }
    if (item.status == TafsirItemStatus.installed) {
      return () => context.read<TafsirCubit>().toggleSelected(item.slug);
    }
    return null;
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.item});

  final TafsirItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (item.status) {
      TafsirItemStatus.installed => Icon(
          key: WidgetKeys.tafsirInstalled(item.slug),
          item.selected
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          color: item.selected ? cs.primary : cs.onSurfaceVariant,
          size: 22,
        ),
      TafsirItemStatus.failed => Icon(
          Icons.error_outline_rounded,
          color: cs.error,
          size: 22,
        ),
      TafsirItemStatus.installing => const SizedBox.shrink(),
      TafsirItemStatus.available ||
      TafsirItemStatus.unavailable =>
        const SizedBox.shrink(),
    };
  }
}

Future<void> _confirmRemove(BuildContext context, TafsirItem item) async {
  final confirmed = await confirmAction(
    context,
    title: 'Remove ${item.name}?',
    message: 'This deletes the downloaded Tafsir text. You can download it '
        'again later from this screen.',
    confirmLabel: 'Remove',
  );
  if (!confirmed || !context.mounted) return;
  await context.read<TafsirCubit>().remove(item.slug);
}

class _Action extends StatelessWidget {
  const _Action({required this.item});

  final TafsirItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (item.status) {
      TafsirItemStatus.installed => IconButton(
          key: WidgetKeys.tafsirRemove(item.slug),
          tooltip: 'Remove ${item.name}',
          iconSize: 22,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: Icon(Icons.delete_outline_rounded, color: cs.onSurfaceVariant),
          onPressed: () => _confirmRemove(context, item),
        ),
      TafsirItemStatus.available || TafsirItemStatus.failed => IconButton(
          key: WidgetKeys.tafsirDownload(item.slug),
          tooltip: 'Download ${item.name}',
          iconSize: 22,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: Icon(
            item.status == TafsirItemStatus.failed
                ? Icons.refresh_rounded
                : Icons.file_download_outlined,
            color: item.status == TafsirItemStatus.failed
                ? cs.error
                : cs.onSurfaceVariant,
          ),
          onPressed: () => context.read<TafsirCubit>().install(item.slug),
        ),
      TafsirItemStatus.installing => SizedBox(
          width: 40,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: item.progress == 0 ? null : item.progress,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      TafsirItemStatus.unavailable => SizedBox(
          width: 34,
          child: Icon(
            Icons.lock_clock_rounded,
            color: cs.onSurfaceVariant.withValues(alpha: 0.62),
            size: 21,
          ),
        ),
    };
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSecondaryContainer,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

String _languageLabel(String code) {
  return switch (code.toLowerCase()) {
    'ar' => 'Arabic',
    'bn' => 'Bangla',
    'en' => 'English',
    'hi' => 'Hindi',
    'id' => 'Bahasa Indonesia',
    'ur' => 'Urdu',
    _ => code.toUpperCase(),
  };
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1) return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  final kb = bytes / 1024;
  return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
}
