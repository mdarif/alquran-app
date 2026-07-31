import 'dart:convert';

const String defaultStoreUrl =
    'https://play.google.com/store/apps/details?id=com.almarfa.alquran';
const String defaultMessage = 'A newer version is available.';
const int defaultRemindAfterDays = 30;

String buildAppUpdateConfigJson({
  required String latestVersion,
  String minimumSupportedVersion = '1.0.0',
  String storeUrl = defaultStoreUrl,
  String message = defaultMessage,
  int remindAfterDays = defaultRemindAfterDays,
}) {
  if (!_isSemver(latestVersion)) {
    throw ArgumentError.value(latestVersion, 'latestVersion', 'Use X.Y.Z');
  }
  if (!_isSemver(minimumSupportedVersion)) {
    throw ArgumentError.value(
      minimumSupportedVersion,
      'minimumSupportedVersion',
      'Use X.Y.Z',
    );
  }
  if (Uri.tryParse(storeUrl)?.hasScheme != true) {
    throw ArgumentError.value(storeUrl, 'storeUrl', 'Use an absolute URL');
  }
  if (remindAfterDays <= 0) {
    throw ArgumentError.value(
      remindAfterDays,
      'remindAfterDays',
      'Use a positive number of days',
    );
  }

  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert({
        'latestVersion': latestVersion,
        'minimumSupportedVersion': minimumSupportedVersion,
        'storeUrl': storeUrl,
        'message': message,
        'remindAfterDays': remindAfterDays,
      })}\n';
}

bool _isSemver(String value) => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value);
