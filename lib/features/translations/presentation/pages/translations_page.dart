import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../cubit/translations_cubit.dart';

/// The Translations section: what is on the device, and what can be added.
///
/// Deliberately shows the translator and the licence **before** a reader
/// commits to a download, not after. A translation is someone's work and is
/// reproduced under terms; a bare language name hides both.
class TranslationsPage extends StatelessWidget {
  const TranslationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranslationsCubit, TranslationsState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Translations')),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => context.read<TranslationsCubit>().load(),
                  child: _List(state: state),
                ),
        );
      },
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state});

  final TranslationsState state;

  static const _langNames = {
    'ar': 'Arabic',
    'ur': 'Urdu',
    'hi': 'Hindi',
    'en': 'English',
  };

  @override
  Widget build(BuildContext context) {
    final groups = state.byLanguage.entries.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (state.catalogueUnavailable)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _Notice(
              // Offline is a normal state for this app, so this is information,
              // not an error: everything already on the device still works.
              'You’re offline, so new translations can’t be listed right now. '
              'The ones on your device are unaffected.',
            ),
          ),
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
            child: Text(
              _langNames[g.key] ?? g.key.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final item in g.value) _EditionTile(item: item),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _EditionTile extends StatelessWidget {
  const _EditionTile({required this.item});

  final EditionItem item;

  static String _size(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<TranslationsCubit>();
    final subtitle = <String>[
      if (item.author?.trim().isNotEmpty ?? false) item.author!.trim(),
      if (item.bytes > 0) _size(item.bytes),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleSmall),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // Licence, shown up front: this text is reproduced under
                  // terms and the reader is entitled to see them.
                  if (item.license?.trim().isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.license!.trim(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (item.state == EditionState.downloading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(value: item.progress),
                    ),
                  if (item.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        item.error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _action(context, cubit),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, TranslationsCubit cubit) {
    switch (item.state) {
      case EditionState.bundled:
        // No action: it ships with the app, so there is nothing to download and
        // nothing that could be removed.
        return const Padding(
          padding: EdgeInsets.only(right: 8, top: 4),
          child: Text('Included'),
        );
      case EditionState.installed:
        return IconButton(
          key: WidgetKeys.editionRemove(item.slug),
          tooltip: 'Remove ${item.name}',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => cubit.remove(item.slug),
        );
      case EditionState.available:
      case EditionState.failed:
        return IconButton(
          key: WidgetKeys.editionDownload(item.slug),
          tooltip: item.state == EditionState.failed
              ? 'Retry ${item.name}'
              : 'Download ${item.name}',
          icon: Icon(
            item.state == EditionState.failed
                ? Icons.refresh
                : Icons.download_outlined,
          ),
          onPressed: () => cubit.install(item.slug),
        );
      case EditionState.downloading:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
    }
  }
}
