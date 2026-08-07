import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../about/presentation/pages/about_page.dart';
import '../../../app_update/domain/entities/app_update_prompt.dart';
import '../../../app_update/presentation/cubit/app_update_cubit.dart';
import '../../../app_update/presentation/cubit/app_update_state.dart';
import '../../../reader/presentation/pages/reader_settings_page.dart';

const String _downloadUrl = 'https://alquranreader.com/download';

List<SettingsAction> appSettingsActions(
  BuildContext context, {
  AppUpdateCubit? updateCubit,
  AppUpdateState? updateState,
}) =>
    [
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
          title: updateState?.phase == AppUpdatePhase.available
              ? 'Update available'
              : 'Check for Updates',
          onTap: () => _checkForUpdate(context, updateCubit),
        ),
      SettingsAction(
        key: WidgetKeys.aboutMenuButton,
        icon: AppIcons.about,
        title: 'About',
        showsChevron: true,
        onTap: () => _openAbout(context),
      ),
    ];

Future<void> _checkForUpdate(
  BuildContext context,
  AppUpdateCubit? updateCubit,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (updateCubit == null) {
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
  await updateCubit.check();
  if (!context.mounted) return;
  final state = updateCubit.state;
  messenger.hideCurrentSnackBar();
  switch (state.phase) {
    case AppUpdatePhase.available:
      await _showUpdateAvailableDialog(context, updateCubit, state.prompt!);
    case AppUpdatePhase.upToDate:
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Al Quran is up to date'),
          content: const Text('You are already using the latest version.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    case AppUpdatePhase.error:
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Couldn\'t check for updates'),
          content: Text(
            state.error ??
                'Check your connection and try again in a moment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    case AppUpdatePhase.idle:
    case AppUpdatePhase.checking:
      // check() always resolves to one of the three terminal phases above.
      break;
  }
}

Future<void> _showUpdateAvailableDialog(
  BuildContext context,
  AppUpdateCubit updateCubit,
  AppUpdatePrompt prompt,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !prompt.required,
    builder: (dialogContext) => PopScope(
      canPop: !prompt.required,
      child: AlertDialog(
        title: Text(prompt.required ? 'Update required' : 'Update available'),
        content: Text(
          '${prompt.required ? 'This version of Al Quran is no longer supported. ' : 'A newer version of Al Quran is available.\n\n'}'
          'Installed: ${prompt.currentVersion}\n'
          'Latest: ${prompt.latestVersion}',
        ),
        actions: [
          if (!prompt.required)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await launchUrl(
                prompt.storeUrl,
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
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
