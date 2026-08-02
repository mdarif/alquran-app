import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/translations/translation_metadata_overrides.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../cubit/translations_cubit.dart';

class TranslationsPage extends StatefulWidget {
  const TranslationsPage({super.key});

  @override
  State<TranslationsPage> createState() => _TranslationsPageState();
}

class _TranslationsPageState extends State<TranslationsPage> {
  final TextEditingController _search = TextEditingController();
  String _languageFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Clear the Home overflow's "new edition" dot the moment this screen is
    // actually opened — not merely because a silent background load ran.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TranslationsCubit>().markCatalogueSeen(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranslationsCubit, TranslationsState>(
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        return Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: state.loading
                ? const _Loading()
                : Column(
                    children: [
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
                            onRefresh: () =>
                                context.read<TranslationsCubit>().load(),
                            child: _List(
                              state: state,
                              query: value.text.trim().toLowerCase(),
                              languageFilter: _languageFilter,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
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

String _languageDisplayLabel(String code, {String? nativeLabel}) {
  final native = nativeLabel?.trim() ?? '';
  if (native == 'اردو') return 'Urdu';
  if (native == 'हिन्दी' || native == 'हिंदी') return 'Hindi';
  if (native == 'বাংলা') return 'Bangla';
  if (native.isNotEmpty && native.toLowerCase() != code.toLowerCase()) {
    return native;
  }
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

class _Header extends StatelessWidget {
  const _Header({
    required this.search,
    required this.items,
    required this.languageFilter,
    required this.onLanguageFilterChanged,
  });

  final TextEditingController search;
  final List<EditionItem> items;
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
                  'Translations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: WidgetKeys.translationsSearchField,
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
                    key: WidgetKeys.translationsSearchClear,
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

  final List<EditionItem> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final codes = <String>{
      for (final item in items) item.languageCode.toLowerCase(),
    }.toList()
      ..sort(
        (a, b) => _languageDisplayLabel(a).compareTo(_languageDisplayLabel(b)),
      );
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
              label: _languageFilterLabel(code),
              selected: selected == code,
              onSelected: onSelected,
            ),
          ],
          // Keeps the final chip from kissing the sheet edge on narrow phones.
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

String _languageFilterLabel(String code) {
  return switch (code.toLowerCase()) {
    'id' => 'Indonesian',
    _ => _languageDisplayLabel(code),
  };
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
      key: WidgetKeys.translationsLanguageFilter(code),
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
  });

  final TranslationsState state;
  final String query;
  final String languageFilter;

  @override
  Widget build(BuildContext context) {
    final shown = _filter([
      for (final item in state.downloaded)
        if (item.selected) item,
    ]);
    final downloaded = _filter([
      for (final item in state.downloaded)
        if (!item.selected) item,
    ]);
    final available = _filter(state.available);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
      children: [
        if (state.catalogueUnavailable)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _Notice('New downloads are unavailable offline.'),
          ),
        _Section(title: 'Shown in reader', items: shown),
        if (shown.isNotEmpty && downloaded.isNotEmpty)
          const SizedBox(height: 14),
        _Section(title: 'Downloaded', items: downloaded),
        if ((shown.isNotEmpty || downloaded.isNotEmpty) &&
            available.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
        ],
        _Section(title: 'Available for download', items: available),
        if (shown.isEmpty && downloaded.isEmpty && available.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: _EmptyLine('No translations found'),
          ),
      ],
    );
  }

  List<EditionItem> _filter(List<EditionItem> items) {
    return [
      for (final i in items)
        if (_matchesLanguage(i) &&
            (query.isEmpty || _translationSearchText(i).contains(query)))
          i,
    ];
  }

  bool _matchesLanguage(EditionItem item) =>
      languageFilter == 'all' ||
      item.languageCode.toLowerCase() == languageFilter;

  String _translationSearchText(EditionItem item) {
    return [
      item.languageLabel,
      item.languageCode,
      _languageSearchAlias(item.languageCode),
      item.name,
      item.author ?? '',
    ].join(' ').toLowerCase();
  }

  String _languageSearchAlias(String code) {
    return switch (code.toLowerCase()) {
      'ar' => 'arabic',
      'bn' => 'bangla bengali',
      'en' => 'english',
      'hi' => 'hindi',
      'id' => 'bahasa indonesia indonesian',
      'ur' => 'urdu',
      _ => '',
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<EditionItem> items;

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
        for (final item in items) _TranslationRow(item: item),
      ],
    );
  }
}

class _TranslationRow extends StatelessWidget {
  const _TranslationRow({required this.item});

  final EditionItem item;

  static String _size(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );
    final sizeStyle = theme.textTheme.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return InkWell(
      key: WidgetKeys.editionRow(item.slug),
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
                          style: titleStyle,
                        ),
                      ),
                      if (_sizeLabel.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(_sizeLabel, style: sizeStyle),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (_subtitleLabel.isNotEmpty)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _subtitleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (_isExperimental) ...[
                          const SizedBox(width: 6),
                          const _ExperimentalPill(),
                        ],
                      ],
                    )
                  else if (_isExperimental)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: _ExperimentalPill(),
                    ),
                  if (item.error != null)
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

  String get _languageLabel {
    return _languageDisplayLabel(
      item.languageCode,
      nativeLabel: item.languageLabel,
    );
  }

  String get _titleLabel {
    final name = item.name.trim();
    if (name.isEmpty || name.toLowerCase() == _languageLabel.toLowerCase()) {
      return _languageLabel;
    }
    return '$_languageLabel · $name';
  }

  String get _sizeLabel {
    if (item.bytes <= 0) return '';
    final size = _size(item.bytes);
    return '($size)';
  }

  String get _subtitleLabel {
    final author = item.author?.trim() ?? '';
    if (author.isNotEmpty) return author;
    return '';
  }

  bool get _isExperimental =>
      TranslationMetadataOverrides.isExperimental(item.slug);

  VoidCallback? _onTap(BuildContext context) {
    final cubit = context.read<TranslationsCubit>();
    return switch (item.state) {
      EditionState.available || EditionState.failed => () =>
          cubit.install(item.slug),
      EditionState.bundled ||
      EditionState.installed ||
      EditionState.updateAvailable =>
        () => cubit.toggleSelected(item.slug),
      EditionState.downloading => null,
    };
  }
}

class _ExperimentalPill extends StatelessWidget {
  const _ExperimentalPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          'Experimental',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onTertiaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.item});

  final EditionItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (item.state == EditionState.bundled ||
        item.state == EditionState.installed ||
        item.state == EditionState.updateAvailable) {
      return Icon(
        key: WidgetKeys.editionSelected(item.slug),
        item.selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded,
        color: item.selected ? cs.primary : cs.onSurfaceVariant,
        size: 22,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Confirms before actually uninstalling — removing a downloaded edition
/// deletes its text outright, and a stray tap on the small delete icon
/// shouldn't be able to do that silently.
Future<void> _confirmRemove(BuildContext context, EditionItem item) async {
  final confirmed = await confirmAction(
    context,
    title: 'Remove ${item.name}?',
    message: 'This deletes the downloaded text. You can download it again '
        'later from this screen.',
    confirmLabel: 'Remove',
  );
  if (!confirmed || !context.mounted) return;
  unawaited(context.read<TranslationsCubit>().remove(item.slug));
}

class _Action extends StatelessWidget {
  const _Action({required this.item});

  final EditionItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (item.state) {
      EditionState.bundled => const SizedBox(width: 34),
      EditionState.installed => IconButton(
          key: WidgetKeys.editionRemove(item.slug),
          tooltip: 'Remove ${item.name}',
          iconSize: 22,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: Icon(Icons.delete_outline_rounded, color: cs.onSurfaceVariant),
          onPressed: () => _confirmRemove(context, item),
        ),
      EditionState.updateAvailable => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: WidgetKeys.editionDownload(item.slug),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                foregroundColor: cs.onPrimary,
                backgroundColor: cs.primary,
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              onPressed: () =>
                  context.read<TranslationsCubit>().install(item.slug),
              child: const Text('Update'),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: WidgetKeys.editionRemove(item.slug),
              tooltip: 'Remove ${item.name}',
              iconSize: 22,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: cs.onSurfaceVariant,
              ),
              onPressed: () => _confirmRemove(context, item),
            ),
          ],
        ),
      EditionState.available => IconButton(
          key: WidgetKeys.editionDownload(item.slug),
          tooltip: 'Download ${item.name}',
          iconSize: 22,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: Icon(Icons.file_download_outlined, color: cs.onSurfaceVariant),
          onPressed: () => context.read<TranslationsCubit>().install(item.slug),
        ),
      EditionState.failed => IconButton(
          key: WidgetKeys.editionDownload(item.slug),
          tooltip: 'Retry ${item.name}',
          iconSize: 22,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: Icon(Icons.refresh_rounded, color: cs.error),
          onPressed: () => context.read<TranslationsCubit>().install(item.slug),
        ),
      EditionState.downloading => SizedBox(
          width: 40,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: item.progress,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
    };
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
    );
  }
}
