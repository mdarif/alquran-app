import 'dart:io';

import 'app_update_config_builder.dart';

void main(List<String> args) {
  final values = _parseArgs(args);
  final latestVersion = values['latest-version'];
  if (latestVersion == null) {
    stderr.writeln('Usage: dart run tool/generate_app_update_config.dart '
        '--latest-version=X.Y.Z [--minimum-supported-version=X.Y.Z] '
        '[--output=app-update.json]');
    exitCode = 64;
    return;
  }

  final output = values['output'] ?? 'app-update.json';
  final json = buildAppUpdateConfigJson(
    latestVersion: latestVersion,
    minimumSupportedVersion: values['minimum-supported-version'] ?? '1.0.0',
    storeUrl: values['store-url'] ?? defaultStoreUrl,
    message: values['message'] ?? defaultMessage,
    remindAfterDays: int.tryParse(values['remind-after-days'] ?? '') ??
        defaultRemindAfterDays,
  );
  File(output).writeAsStringSync(json);
}

Map<String, String> _parseArgs(List<String> args) {
  final values = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) continue;
    final separator = arg.indexOf('=');
    if (separator <= 2) continue;
    values[arg.substring(2, separator)] = arg.substring(separator + 1);
  }
  return values;
}
