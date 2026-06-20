import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _assetDb = 'assets/db/quran.db';
const String _assetVersion = 'assets/db/quran.db.version';
const String _prefKey = 'seeded_db_version';

/// Marker used when no version asset is bundled — degrades to copy-once so we
/// never re-seed on every launch.
const String _unversioned = 'unversioned';

/// Whether the bundled seed DB must be (re)written to writable storage: when it
/// has never been copied, or when the bundled version differs from the installed
/// one (i.e. `quran.db` was updated in a new app build).
bool shouldReseed({
  required bool fileExists,
  required String bundledVersion,
  required String? installedVersion,
}) =>
    !fileExists || bundledVersion != installedVersion;

/// Ensures the writable copy of the bundled DB is present and up to date, then
/// returns its file. Call once at startup before opening [AppDatabase].
///
/// The bundled DB is copied only on first launch or when its version marker
/// changes — so shipping an updated `quran.db` (corrections, new translations)
/// refreshes the on-device copy instead of being ignored forever.
Future<File> ensureSeedDatabase(SharedPreferences prefs) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'quran.db'));

  final bundledVersion = await _bundledVersion();
  final installedVersion = prefs.getString(_prefKey);

  if (shouldReseed(
    fileExists: await file.exists(),
    bundledVersion: bundledVersion,
    installedVersion: installedVersion,
  )) {
    final blob = await rootBundle.load(_assetDb);
    final bytes =
        blob.buffer.asUint8List(blob.offsetInBytes, blob.lengthInBytes);
    await file.writeAsBytes(bytes, flush: true);
    await prefs.setString(_prefKey, bundledVersion);
  }

  return file;
}

Future<String> _bundledVersion() async {
  try {
    return (await rootBundle.loadString(_assetVersion)).trim();
  } catch (_) {
    return _unversioned;
  }
}
