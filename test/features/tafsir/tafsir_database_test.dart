import 'dart:io';

import 'package:al_quran/core/database/tafsir_database.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grouped Tafsir pointers resolve to the leading commentary row',
      () async {
    final dir = await Directory.systemTemp.createTemp('tafsir-db-test-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final db = TafsirDatabase(File('${dir.path}/tafsir.db'));
    await db.replaceResource(
      resource: TafsirResource(
        slug: 'en-ibn-kathir-abridged',
        languageCode: 'en',
        name: 'Tafsir Ibn Kathir',
        ayahCount: 2,
        bytes: 512,
        installedAt: DateTime.utc(2026, 8, 5),
      ),
      entries: const [
        TafsirEntry(
          resource: 'en-ibn-kathir-abridged',
          ayahKey: '1:1',
          groupAyahKey: '1:1',
          fromAyah: '1:1',
          toAyah: '1:2',
          ayahKeys: ['1:1', '1:2'],
          text: 'Grouped commentary.',
        ),
        TafsirEntry(
          resource: 'en-ibn-kathir-abridged',
          ayahKey: '1:2',
          groupAyahKey: '1:1',
          fromAyah: '1:1',
          toAyah: '1:2',
          ayahKeys: ['1:1', '1:2'],
          text: '',
        ),
      ],
    );

    final installed = await db.installed();
    expect(installed.single.slug, 'en-ibn-kathir-abridged');

    final entry = await db.entryForAyah(
      slug: 'en-ibn-kathir-abridged',
      surah: 1,
      ayah: 2,
    );

    expect(entry, isNotNull);
    expect(entry!.ayahKey, '1:2');
    expect(entry.groupAyahKey, '1:1');
    expect(entry.text, 'Grouped commentary.');

    await db.removeResource('en-ibn-kathir-abridged');

    expect(await db.installed(), isEmpty);
    expect(
      await db.entryForAyah(
        slug: 'en-ibn-kathir-abridged',
        surah: 1,
        ayah: 1,
      ),
      isNull,
    );
  });
}
