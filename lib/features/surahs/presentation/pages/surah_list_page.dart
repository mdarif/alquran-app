import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../reader/domain/entities/reader_target.dart';
import '../../../reader/presentation/pages/reader_page.dart';
import '../../domain/surah_search.dart';
import '../cubit/surah_list_cubit.dart';
import '../widgets/surah_tile.dart';

class SurahListPage extends StatelessWidget {
  const SurahListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SurahListView(),
    );
  }
}

/// The surah list, self-contained with its own cubit — embeddable standalone
/// (e.g. [SurahListPage]). The Home screen instead provides the cubit itself
/// (so its app-bar search can drive it) and renders [SurahListBody] directly.
class SurahListView extends StatelessWidget {
  const SurahListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<SurahListCubit>()..load(),
      child: const SurahListBody(),
    );
  }
}

/// Just the list body — consumes an ambient [SurahListCubit]. Search lives in the
/// host's app bar (see the Home screen); this renders `state.visibleHits`.
class SurahListBody extends StatelessWidget {
  const SurahListBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SurahListCubit, SurahListState>(
      builder: (context, state) {
        switch (state.status) {
          case SurahListStatus.initial:
          case SurahListStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case SurahListStatus.error:
            return _ErrorView(
              message: state.error ?? 'Something went wrong',
              onRetry: () => context.read<SurahListCubit>().load(),
            );
          case SurahListStatus.loaded:
            final hits = state.visibleHits;
            if (hits.isEmpty) return _NoMatch(query: state.query);
            return ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: hits.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final hit = hits[i];
                final surah = hit.surah;
                return SurahTile(
                  key: WidgetKeys.surahTile(surah.id),
                  surah: surah,
                  verse: hit.verse,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReaderPage(
                        target: ReaderTarget.surah(surah.id, surah.nameEnglish),
                        // For a verse-ref hit ("18:5"), open the reader scrolled
                        // to that verse (its global ayah id — the same focus
                        // Last Read uses).
                        focusAyahId: hit.verse == null
                            ? null
                            : globalAyahId(state.surahs, surah.id, hit.verse!),
                      ),
                    ),
                  ),
                );
              },
            );
        }
      },
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No surah matches “$query”',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
