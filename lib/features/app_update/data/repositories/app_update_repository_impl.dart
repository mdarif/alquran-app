import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/app_update_config.dart';
import '../../domain/entities/app_update_prompt.dart';
import '../../domain/repositories/app_update_repository.dart';

typedef CurrentVersionLoader = Future<String> Function();

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl({
    required SharedPreferences prefs,
    required Uri configUrl,
    http.Client? client,
    CurrentVersionLoader? currentVersion,
  })  : _prefs = prefs,
        _configUrl = configUrl,
        _client = client ?? http.Client(),
        _currentVersion = currentVersion ?? _packageVersion;

  final SharedPreferences _prefs;
  final Uri _configUrl;
  final http.Client _client;
  final CurrentVersionLoader _currentVersion;

  static const String _dismissedVersionKey = 'dismissed_update_version';
  static const String _fallbackMessage = 'A newer version is available.';

  @override
  Future<AppUpdatePrompt?> check() async {
    try {
      final current = await _currentVersion();
      final response = await _client.get(_configUrl);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, Object?>) return null;
      final latest = json['latestVersion'];
      final storeUrl = json['storeUrl'];
      if (latest is! String) return null;
      if (!_isNewer(latest, current)) return null;
      final requiredVersion = json['minimumSupportedVersion'];
      final required =
          requiredVersion is String && _isNewer(requiredVersion, current);
      if (!required && _prefs.getString(_dismissedVersionKey) == latest) {
        return null;
      }
      final parsedStoreUrl = storeUrl is String ? Uri.tryParse(storeUrl) : null;
      final uri = parsedStoreUrl != null && parsedStoreUrl.hasScheme
          ? parsedStoreUrl
          : Uri.parse(androidPlayStoreUrl);
      final message = json['message'];
      return AppUpdatePrompt(
        currentVersion: current,
        latestVersion: latest,
        storeUrl: uri,
        message: message is String && message.trim().isNotEmpty
            ? message.trim()
            : _fallbackMessage,
        required: required,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dismiss(String latestVersion) async {
    await _prefs.setString(_dismissedVersionKey, latestVersion);
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
}
