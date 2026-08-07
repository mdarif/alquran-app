import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/app_update_config.dart';
import '../../domain/entities/app_update_check_result.dart';
import '../../domain/entities/app_update_prompt.dart';
import '../../domain/repositories/app_update_repository.dart';

typedef CurrentVersionLoader = Future<String> Function();
typedef DateTimeLoader = DateTime Function();

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl({
    required SharedPreferences prefs,
    required Uri configUrl,
    http.Client? client,
    CurrentVersionLoader? currentVersion,
    DateTimeLoader? now,
  })  : _prefs = prefs,
        _configUrl = configUrl,
        _client = client ?? http.Client(),
        _currentVersion = currentVersion ?? _packageVersion,
        _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final Uri _configUrl;
  final http.Client _client;
  final CurrentVersionLoader _currentVersion;
  final DateTimeLoader _now;

  static const String _dismissedVersionKey = 'dismissed_update_version';
  static const String _dismissedAtKey = 'dismissed_update_at';
  static const int _defaultRemindAfterDays = 30;
  static const String _optionalMessage = 'A new version is available.';
  static const String _requiredMessage = 'Please update to continue.';

  @override
  Future<AppUpdateCheckResult> check({bool ignoreDismissal = false}) async {
    String current;
    try {
      current = await _currentVersion();
    } catch (e) {
      _log('current version lookup failed: $e');
      return const AppUpdateCheckResult.error('Could not read app version');
    }
    http.Response response;
    try {
      response = await _client.get(_configUrl);
    } catch (e) {
      _log('current=$current request failed: $e');
      return const AppUpdateCheckResult.error('Network request failed');
    }
    _log('current=$current httpStatus=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return AppUpdateCheckResult.error(
        'Update check failed (HTTP ${response.statusCode})',
      );
    }
    final Object? json;
    try {
      json = jsonDecode(response.body);
    } catch (e) {
      _log('malformed config body: $e');
      return const AppUpdateCheckResult.error('Malformed update config');
    }
    if (json is! Map<String, Object?>) {
      _log('config body was not a JSON object');
      return const AppUpdateCheckResult.error('Malformed update config');
    }
    final latest = json['latestVersion'];
    final storeUrl = json['storeUrl'];
    if (latest is! String) {
      _log('config missing latestVersion');
      return const AppUpdateCheckResult.error('Malformed update config');
    }
    _log('current=$current latest=$latest');
    if (!_isNewer(latest, current)) {
      return const AppUpdateCheckResult.upToDate();
    }
    final requiredVersion = json['minimumSupportedVersion'];
    final required =
        requiredVersion is String && _isNewer(requiredVersion, current);
    final remindAfterDays = _remindAfterDays(json['remindAfterDays']);
    final dismissedVersion = _prefs.getString(_dismissedVersionKey);
    if (!required &&
        !ignoreDismissal &&
        _isDismissed(latest, remindAfterDays)) {
      _log('latest=$latest suppressed: dismissed=$dismissedVersion');
      return const AppUpdateCheckResult.upToDate();
    }
    final parsedStoreUrl = storeUrl is String ? Uri.tryParse(storeUrl) : null;
    final uri = parsedStoreUrl != null && parsedStoreUrl.hasScheme
        ? parsedStoreUrl
        : Uri.parse(androidPlayStoreUrl);
    final message = json['message'];
    _log('latest=$latest required=$required dismissed=$dismissedVersion');
    return AppUpdateCheckResult.available(
      AppUpdatePrompt(
        currentVersion: current,
        latestVersion: latest,
        storeUrl: uri,
        // Required always speaks plainly regardless of the JSON's message —
        // "why should I bother" copy is the wrong tone when it's mandatory.
        message: required
            ? _requiredMessage
            : (message is String && message.trim().isNotEmpty
                ? message.trim()
                : _optionalMessage),
        required: required,
      ),
    );
  }

  void _log(String message) => developer.log(message, name: 'AppUpdate');

  @override
  Future<void> dismiss(String latestVersion) async {
    await _prefs.setString(_dismissedVersionKey, latestVersion);
    await _prefs.setString(_dismissedAtKey, _now().toUtc().toIso8601String());
  }

  static Future<String> _packageVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static bool _isNewer(String candidate, String current) {
    final a = _versionParts(candidate);
    final b = _versionParts(current);
    final max = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < max; i++) {
      final left = i < a.length ? a[i] : 0;
      final right = i < b.length ? b[i] : 0;
      if (left != right) return left > right;
    }
    return false;
  }

  static List<int> _versionParts(String version) {
    return version
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList(growable: false);
  }

  bool _isDismissed(String latestVersion, int remindAfterDays) {
    if (_prefs.getString(_dismissedVersionKey) != latestVersion) {
      return false;
    }
    final dismissedAt = DateTime.tryParse(
      _prefs.getString(_dismissedAtKey) ?? '',
    );
    if (dismissedAt == null) {
      return true;
    }
    final remindAt = dismissedAt.toUtc().add(Duration(days: remindAfterDays));
    return _now().toUtc().isBefore(remindAt);
  }

  static int _remindAfterDays(Object? value) {
    if (value is int && value > 0) return value;
    return _defaultRemindAfterDays;
  }
}
