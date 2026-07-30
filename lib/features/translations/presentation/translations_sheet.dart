import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../reader/data/repositories/ayah_repository_impl.dart';
import '../../reader/domain/entities/translation_resource.dart';
import '../../reader/domain/repositories/ayah_repository.dart';
import '../../reader/domain/repositories/reader_settings_repository.dart';
import '../domain/repositories/edition_repository.dart';
import 'cubit/translations_cubit.dart';
import 'pages/translations_page.dart';

Future<void> showTranslationsSheet(
  BuildContext context, {
  VoidCallback? onTranslationsChanged,
}) {
  var changed = false;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      alignment: Alignment.bottomCenter,
      child: FutureBuilder(
        future: _bundledTranslations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _TranslationsSheetFrame(
              child: Center(
                child: Text('Translations could not be loaded.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const _TranslationsSheetFrame(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return BlocProvider<TranslationsCubit>(
            create: (_) => TranslationsCubit(
              GetIt.I<EditionRepository>(),
              snapshot.data!,
              settings: GetIt.I<ReaderSettingsRepository>(),
              onTranslationsChanged: () {
                changed = true;
                (GetIt.I<AyahRepository>() as AyahRepositoryImpl)
                    .invalidateTranslations();
              },
            )..load(),
            child: const TranslationsPage(),
          );
        },
      ),
    ),
  ).whenComplete(() {
    if (changed) onTranslationsChanged?.call();
  });
}

Future<List<TranslationResource>> _bundledTranslations() async {
  final rows = await GetIt.I<AppDatabase>().translationResources();
  return [
    for (final r in rows)
      TranslationResource(
        id: r.id,
        slug: r.slug,
        languageCode: r.languageCode,
        name: r.name,
        nativeName: r.nativeName,
        author: r.author,
        direction: r.direction,
        sortOrder: r.sortOrder,
        defaultOn: r.defaultOn == 1,
        license: r.license,
        sourceUrl: r.sourceUrl,
      ),
  ];
}

class _TranslationsSheetFrame extends StatelessWidget {
  const _TranslationsSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: child),
    );
  }
}
