import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/scroll/quran_scroll_behavior.dart';
import '../../../reader/domain/entities/reader_target.dart';
import '../../../reader/presentation/pages/reader_page.dart';
import '../../domain/entities/index_entry.dart';
import '../../domain/entities/index_kind.dart';
import '../cubit/index_list_cubit.dart';

/// A flat index list (Juz / Hizb / Page / Ruku). Each row jumps to the reader
/// for that section. [label] is the singular noun shown per row.
class IndexListView extends StatelessWidget {
  const IndexListView({
    required this.kind,
    required this.label,
    this.onTargetSelected,
    super.key,
  });

  final IndexKind kind;
  final String label;
  final ValueChanged<ReaderTarget>? onTargetSelected;

  ReaderTarget _targetFor(int number) => switch (kind) {
        IndexKind.juz => ReaderTarget.juz(number),
        IndexKind.hizb => ReaderTarget.hizb(number),
        IndexKind.page => ReaderTarget.page(number),
        IndexKind.ruku => ReaderTarget.ruku(number),
      };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<IndexListCubit>()..load(kind),
      child: BlocBuilder<IndexListCubit, IndexListState>(
        builder: (context, state) {
          switch (state.status) {
            case IndexListStatus.initial:
            case IndexListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case IndexListStatus.error:
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.error ?? 'Something went wrong'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<IndexListCubit>().load(kind),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            case IndexListStatus.loaded:
              return ListView.separated(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                physics: const QuranClampEdgesPhysics(),
                itemCount: state.entries.length,
                separatorBuilder: (context, _) {
                  final cs = Theme.of(context).colorScheme;
                  return Padding(
                    padding:
                        const EdgeInsetsDirectional.only(start: 68, end: 20),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                  );
                },
                itemBuilder: (context, i) {
                  final target = _targetFor(state.entries[i].number);
                  return _IndexTile(
                    entry: state.entries[i],
                    label: label,
                    onTap: () {
                      final handler = onTargetSelected;
                      if (handler != null) {
                        handler(target);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReaderPage(target: target),
                        ),
                      );
                    },
                  );
                },
              );
          }
        },
      ),
    );
  }
}

class _IndexTile extends StatelessWidget {
  const _IndexTile({
    required this.entry,
    required this.label,
    required this.onTap,
  });

  final IndexEntry entry;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 3, 20, 3),
          child: Row(
            children: [
              _IndexNumberBadge(number: entry.number),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label ${entry.number}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${entry.startSurahName} '
                      '${entry.startSurahId}:${entry.startAyah}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexNumberBadge extends StatelessWidget {
  const _IndexNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.78),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}
