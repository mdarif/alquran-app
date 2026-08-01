import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../about/presentation/pages/about_page.dart';
import '../../../app_update/domain/repositories/app_update_repository.dart';
import '../../../reader/presentation/pages/reader_settings_page.dart';

const String _downloadUrl = 'https://alquranreader.com/download';

List<SettingsAction> appSettingsActions(BuildContext context) => [
      const SettingsAction(
        key: WidgetKeys.shareAppButton,
        icon: AppIcons.share,
        title: 'Share Al Quran',
        onTap: _shareApp,
      ),
      if (FeatureFlags.softUpdateReminder)
        SettingsAction(
          key: WidgetKeys.appUpdateMenuButton,
          icon: AppIcons.autoSelected,
          title: 'Check for update',
          onTap: () => _checkForUpdate(context),
        ),
      SettingsAction(
        key: WidgetKeys.aboutMenuButton,
        icon: AppIcons.about,
        title: 'About',
        onTap: () => _openAbout(context),
      ),
    ];

Future<void> _checkForUpdate(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!GetIt.I.isRegistered<AppUpdateRepository>()) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Could not check for updates'),
          duration: Duration(seconds: 2),
        ),
      );
    return;
  }
  final prompt = await GetIt.I<AppUpdateRepository>().check();
  if (!context.mounted) return;
  if (prompt == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Al Quran is up to date'),
          duration: Duration(seconds: 2),
        ),
      );
    return;
  }
  await launchUrl(prompt.storeUrl, mode: LaunchMode.externalApplication);
}

void _openAbout(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AboutPage()),
  );
}

Future<void> _shareApp() async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Read. Reflect. Remember. 🌙\n\n'
            'Al Quran is a calm, distraction-free app for reading the Quran '
            'offline, with Urdu, Hindi & English translations and beautiful '
            'recitation.\n\n'
            '100% free. No ads.\n\n'
            'Download the app:\n'
            '$_downloadUrl',
      ),
    );
  } catch (_) {
    // best-effort: no share target, or the user dismissed the sheet
  }
}
