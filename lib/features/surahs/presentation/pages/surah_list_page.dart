import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../reader/domain/entities/reader_target.dart';
import '../../../reader/presentation/pages/reader_page.dart';
import '../../domain/entities/surah.dart';
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

/// The surah list body (no Scaffold), embeddable as a navigation tab.
class SurahListView extends StatelessWidget {
  const SurahListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<SurahListCubit>()..load(),
      child: const _SurahListBody(),
    );
  }
}

class _SurahListBody extends StatelessWidget {
  const _SurahListBody();

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
            return ListView.separated(
              itemCount: state.surahs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final Surah surah = state.surahs[i];
                return SurahTile(
                  key: WidgetKeys.surahTile(surah.id),
                  surah: surah,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReaderPage(
                        target: ReaderTarget.surah(
                          surah.id,
                          surah.nameEnglish,
                        ),
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
