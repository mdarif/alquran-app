import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'cubit/translations_cubit.dart';
import 'pages/translations_page.dart';

/// Opens the Translations screen. [onTranslationsChanged] fires once per real
/// mutation (install/remove/toggle a selection) made while the sheet is open
/// — e.g. the reader re-syncs its active editions from within itself. It is
/// distinct from the [TranslationsCubit] singleton's own, permanent
/// cache-invalidation callback (wired once at DI construction, fires for
/// every opener) — this one is per-open and only for whoever asked for it.
Future<void> showTranslationsSheet(
  BuildContext context, {
  VoidCallback? onTranslationsChanged,
}) {
  final cubit = GetIt.I<TranslationsCubit>();
  final sub = onTranslationsChanged == null
      ? null
      : cubit.mutations.listen((_) => onTranslationsChanged());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      alignment: Alignment.bottomCenter,
      child: BlocProvider<TranslationsCubit>.value(
        value: cubit..load(),
        child: const TranslationsPage(),
      ),
    ),
  ).whenComplete(() => sub?.cancel());
}
