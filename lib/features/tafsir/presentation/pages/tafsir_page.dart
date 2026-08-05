import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../cubit/tafsir_cubit.dart';

class TafsirPage extends StatelessWidget {
  const TafsirPage({this.showHeader = true, super.key});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      key: WidgetKeys.tafsirPage,
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (showHeader)
              Padding(
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
                  ],
                ),
              ),
            Expanded(
              child: BlocBuilder<TafsirCubit, TafsirState>(
                builder: (context, state) {
                  if (state.status == TafsirStatus.loading &&
                      state.items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return RefreshIndicator(
                    onRefresh: () => context.read<TafsirCubit>().load(),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        showHeader ? 8 : 0,
                        20,
                        24,
                      ),
                      children: [
                        if (state.catalogueUnavailable)
                          const _InlineNotice(
                            text: 'Tafsir catalogue unavailable.',
                          ),
                        for (final item in state.items)
                          _TafsirResourceCard(item: item),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TafsirResourceCard extends StatelessWidget {
  const _TafsirResourceCard({required this.item});

  final TafsirItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final installed = item.status == TafsirItemStatus.installed;
    final installing = item.status == TafsirItemStatus.installing;
    return Padding(
      key: WidgetKeys.tafsirResourceRow(item.slug),
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.70)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.18,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.22,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(status: item.status),
                ],
              ),
              if (item.status == TafsirItemStatus.unavailable) ...[
                const SizedBox(height: 8),
                Text(
                  'This edition appears here when a Tafsir catalogue is available.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.32,
                  ),
                ),
              ],
              if (installing) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: item.progress == 0 ? null : item.progress,
                ),
              ],
              if (item.status != TafsirItemStatus.unavailable) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonalIcon(
                    key: WidgetKeys.tafsirDownload(item.slug),
                    onPressed: item.status == TafsirItemStatus.available ||
                            item.status == TafsirItemStatus.failed
                        ? () => context.read<TafsirCubit>().install(item.slug)
                        : null,
                    icon: AppIcon(
                      installed ? AppIcons.statusPass : AppIcons.alKahf,
                      filled: installed,
                    ),
                    label: Text(_buttonLabel(item)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buttonLabel(TafsirItem item) {
    return switch (item.status) {
      TafsirItemStatus.installed => 'Ready',
      TafsirItemStatus.installing => 'Downloading',
      TafsirItemStatus.failed => 'Retry Download',
      TafsirItemStatus.unavailable => 'Preparing Download',
      TafsirItemStatus.available => item.downloadBytes > 0
          ? 'Download ${_formatBytes(item.downloadBytes)}'
          : 'Download',
    };
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
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
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TafsirItemStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final installed = status == TafsirItemStatus.installed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: installed
            ? cs.primaryContainer.withValues(alpha: 0.82)
            : cs.secondaryContainer.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          switch (status) {
            TafsirItemStatus.installed => 'On Device',
            TafsirItemStatus.installing => 'Installing',
            TafsirItemStatus.failed => 'Retry',
            TafsirItemStatus.available => 'Available',
            TafsirItemStatus.unavailable => 'Planned',
          },
          style: theme.textTheme.labelSmall?.copyWith(
            color: installed ? cs.onPrimaryContainer : cs.onSecondaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
