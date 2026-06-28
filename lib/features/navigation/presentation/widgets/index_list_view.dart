import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../reader/domain/entities/reader_target.dart';
import '../../../reader/presentation/pages/reader_page.dart';
import '../../domain/entities/index_entry.dart';
import '../../domain/entities/index_kind.dart';
import '../cubit/index_list_cubit.dart';

/// A flat index list (Juz / Hizb / Page / Ruku). Each row jumps to the reader
/// for that section. [label] is the singular noun shown per row.
class IndexListView extends StatelessWidget {
  const IndexListView({required this.kind, required this.label, super.key});

  final IndexKind kind;
  final String label;

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
                itemCount: state.entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _IndexTile(
                  entry: state.entries[i],
                  label: label,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReaderPage(
                        target: _targetFor(state.entries[i].number),
                      ),
                    ),
                  ),
                ),
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
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          '${entry.number}',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        '$label ${entry.number}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${entry.startSurahName} ${entry.startSurahId}:${entry.startAyah}',
      ),
    );
  }
}
