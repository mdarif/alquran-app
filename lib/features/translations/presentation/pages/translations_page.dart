import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/translations/translation_metadata_overrides.dart';
import '../cubit/translations_cubit.dart';

class TranslationsPage extends StatefulWidget {
  const TranslationsPage({super.key});

  @override
  State<TranslationsPage> createState() => _TranslationsPageState();
}

class _TranslationsPageState extends State<TranslationsPage> {
  final TextEditingController _search = TextEditingController();

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
                      _Header(search: _search),
                      Expanded(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _search,
                          builder: (context, value, _) => RefreshIndicator(
                            onRefresh: () =>
                                context.read<TranslationsCubit>().load(),
                            child: _List(
                              state: state,
                              query: value.text.trim().toLowerCase(),
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

class _Header extends StatelessWidget {
  const _Header({required this.search});

  final TextEditingController search;

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
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const AppIcon(AppIcons.search),
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
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state, required this.query});

  final TranslationsState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final downloaded = _filter(state.downloaded);
    final available = _filter(state.available);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
      children: [
        if (state.catalogueUnavailable)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _Notice('New downloads are unavailable offline.'),
          ),
        _Section(title: 'Downloaded', items: downloaded),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        _Section(title: 'Available for download', items: available),
        if (downloaded.isEmpty && available.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: _EmptyLine('No translations found'),
          ),
      ],
    );
  }

  List<EditionItem> _filter(List<EditionItem> items) {
    if (query.isEmpty) return items;
    return [
      for (final i in items)
        if ('${i.languageLabel} ${i.languageCode} ${i.name} ${i.author ?? ''}'
            .toLowerCase()
            .contains(query))
          i,
    ];
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
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _languageLabel,
                                style: titleStyle,
                              ),
                              if (_sizeLabel.isNotEmpty) ...[
                                TextSpan(text: ' ', style: titleStyle),
                                TextSpan(
                                  text: _sizeLabel,
                                  style: sizeStyle,
                                ),
                              ],
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _authorLabel,
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
    final native = item.languageLabel.trim();
    if (native == 'اردو') return 'Urdu';
    if (native == 'हिन्दी' || native == 'हिंदी') return 'Hindi';
    return native.isNotEmpty ? native : item.languageCode.toUpperCase();
  }

  String get _sizeLabel {
    if (item.bytes <= 0) return '';
    final size = _size(item.bytes);
    return '($size)';
  }

  String get _authorLabel {
    final author = item.author?.trim() ?? '';
    if (author.isNotEmpty) return author;
    return item.name.trim();
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
          onPressed: () => context.read<TranslationsCubit>().remove(item.slug),
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
              onPressed: () =>
                  context.read<TranslationsCubit>().remove(item.slug),
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
