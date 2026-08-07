import 'dart:async';

import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_catalogue_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:al_quran/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:al_quran/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:al_quran/features/tafsir/presentation/pages/tafsir_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('uses short labels and remove action for installed Tafsir',
      (tester) async {
    final cubit = TafsirCubit(
      _FakeTafsirRepository(
        installedResources: const [
          TafsirResource(
            slug: 'en-ibn-kathir-abridged',
            languageCode: 'en',
            name: 'Tafsir Ibn Kathir',
            author: 'Hafiz Ibn Kathir; abridged English edition',
            abridged: true,
            ayahCount: 6236,
            bytes: 512,
          ),
          TafsirResource(
            slug: 'ur-ibn-kathir',
            languageCode: 'ur',
            name: 'Tafsir Ibn Kathir',
            nativeName: 'اردو',
            author: 'Tafsir Ibn Kathir Urdu edition',
            direction: 'rtl',
            ayahCount: 6236,
            bytes: 512,
          ),
        ],
      ),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TafsirPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('English'), findsWidgets);
    expect(find.text('Urdu'), findsWidgets);
    expect(find.text('Tafsir Ibn Kathir (Abridged)'), findsOneWidget);
    expect(find.text('Tafsir Ibn Kathir'), findsOneWidget);
    expect(find.textContaining('Hafiz Ibn Kathir'), findsNothing);
    expect(find.textContaining('Urdu edition'), findsNothing);
    expect(
      find.byKey(WidgetKeys.tafsirRemove('en-ibn-kathir-abridged')),
      findsOneWidget,
    );
    expect(
      find.byKey(WidgetKeys.tafsirRemove('ur-ibn-kathir')),
      findsOneWidget,
    );
  });

  testWidgets('installing Tafsir uses a compact circular action spinner',
      (tester) async {
    final repository = _FakeTafsirRepository();
    final cubit = TafsirCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TafsirPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(WidgetKeys.tafsirDownload('en-ibn-kathir-abridged')),
    );
    await tester.pump();

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.strokeWidth, 2);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    repository.completeInstall();
    await tester.pumpAndSettle();
  });

  testWidgets('a failed download shows calm retry copy and can be retried',
      (tester) async {
    final repository = _FakeTafsirRepository()..failNext = true;
    final cubit = TafsirCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TafsirPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(WidgetKeys.tafsirDownload('en-ibn-kathir-abridged')),
    );
    await tester.pump();
    repository.completeInstall();
    await tester.pumpAndSettle();

    expect(
      find.text('Download failed. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(
      cubit.state.item('en-ibn-kathir-abridged')?.status,
      TafsirItemStatus.failed,
    );

    // Retry taps the same download affordance, now shown in the failed color.
    await tester.tap(
      find.byKey(WidgetKeys.tafsirDownload('en-ibn-kathir-abridged')),
    );
    await tester.pump();
    repository.completeInstall();
    await tester.pumpAndSettle();

    expect(
      cubit.state.item('en-ibn-kathir-abridged')?.status,
      TafsirItemStatus.installed,
    );
    expect(
      find.text('Download failed. Check your connection and try again.'),
      findsNothing,
    );
  });

  testWidgets('installed Tafsir can be checked and unchecked in the manager',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'tafsir_selected_slugs': ['en-ibn-kathir-abridged'],
    });
    final prefs = await SharedPreferences.getInstance();
    final cubit = TafsirCubit(
      _FakeTafsirRepository(
        installedResources: const [
          TafsirResource(
            slug: 'en-ibn-kathir-abridged',
            languageCode: 'en',
            name: 'Tafsir Ibn Kathir',
            abridged: true,
            ayahCount: 6236,
            bytes: 512,
          ),
          TafsirResource(
            slug: 'ur-ibn-kathir',
            languageCode: 'ur',
            name: 'Tafsir Ibn Kathir',
            nativeName: 'اردو',
            direction: 'rtl',
            ayahCount: 6236,
            bytes: 512,
          ),
        ],
      ),
      prefs: prefs,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TafsirPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shown in reader'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(cubit.state.item('ur-ibn-kathir')?.selected, isFalse);

    await tester.tap(find.byKey(WidgetKeys.tafsirResourceRow('ur-ibn-kathir')));
    await tester.pumpAndSettle();

    expect(cubit.state.item('ur-ibn-kathir')?.selected, isTrue);
    expect(
      prefs.getStringList('tafsir_selected_slugs'),
      contains('ur-ibn-kathir'),
    );
  });
}

class _FakeTafsirRepository implements TafsirRepository {
  _FakeTafsirRepository({List<TafsirResource> installedResources = const []})
      : _installedResources = List<TafsirResource>.of(installedResources);

  final List<TafsirResource> _installedResources;
  Completer<void>? _installCompleter;

  /// When true, the next [install] call fails instead of succeeding — used
  /// to exercise the failed/retry row state.
  bool failNext = false;

  @override
  Future<TafsirCatalogue> catalogue() async => const TafsirCatalogue(
        resources: [
          TafsirCatalogueEntry(
            slug: 'en-ibn-kathir-abridged',
            languageCode: 'en',
            name: 'Tafsir Ibn Kathir',
            file: 'en.db.gz',
            bytes: 512,
            sha256: 'sha',
            uncompressedBytes: 1024,
            uncompressedSha256: 'raw-sha',
            ayahCount: 6236,
            textGroupCount: 1902,
            abridged: true,
          ),
        ],
      );

  @override
  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  }) async =>
      null;

  @override
  Future<void> install(
    TafsirCatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {
    _installCompleter = Completer<void>();
    onProgress?.call(0.4);
    await _installCompleter!.future;
    if (failNext) {
      failNext = false;
      throw const TafsirDownloadException('offline');
    }
    _installedResources.add(entry.toResource());
  }

  void completeInstall() {
    _installCompleter?.complete();
  }

  @override
  Future<List<TafsirResource>> installed() async => _installedResources;

  @override
  Future<void> remove(String slug) async {
    _installedResources.removeWhere((resource) => resource.slug == slug);
  }
}
