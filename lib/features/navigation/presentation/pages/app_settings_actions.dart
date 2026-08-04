import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../about/presentation/pages/about_page.dart';
import '../../../app_update/domain/entities/app_update_prompt.dart';
import '../../../app_update/domain/repositories/app_update_repository.dart';
import '../../../prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import '../../../reader/presentation/pages/reader_settings_page.dart';
import '../../../reminders/presentation/cubit/reminders_cubit.dart';
import '../../../reminders/presentation/widgets/reminders_sheet.dart';

const String _downloadUrl = 'https://alquranreader.com/download';

List<SettingsAction> appSettingsActions(
  BuildContext context, {
  AppUpdatePrompt? updatePrompt,
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
          title:
              updatePrompt == null ? 'Check for Updates' : 'Update available',
          onTap: () => _checkForUpdate(context),
        ),
      if (FeatureFlags.sunnahReminders)
        SettingsAction(
          key: WidgetKeys.remindersButton,
          icon: AppIcons.reminders,
          title: 'Sunnah reminders',
          section: SettingsActionSection.reminders,
          showsChevron: true,
          onTap: () => _openSunnahReminders(context),
        ),
      if (FeatureFlags.prayerTimes && FeatureFlags.prayerTimeNotifications)
        SettingsAction(
          key: WidgetKeys.prayerNotificationsToggle,
          icon: AppIcons.reminders,
          title: 'Salat notifications',
          section: SettingsActionSection.reminders,
          switchValue: _prayerNotifications(context)?.state.enabled ?? false,
          onSwitchChanged: (enabled) =>
              _setPrayerNotifications(context, enabled),
          onTap: () {
            final cubit = _prayerNotifications(context);
            if (cubit == null) return;
            _setPrayerNotifications(context, !cubit.state.enabled);
          },
        ),
      if (FeatureFlags.prayerTimes &&
          FeatureFlags.prayerTimeNotifications &&
          kDebugMode)
        SettingsAction(
          key: WidgetKeys.prayerNotificationsTestButton,
          icon: AppIcons.scheduleTest,
          title: 'Schedule salat test',
          section: SettingsActionSection.debug,
          onTap: () => _schedulePrayerNotificationTest(context),
        ),
      SettingsAction(
        key: WidgetKeys.aboutMenuButton,
        icon: AppIcons.about,
        title: 'About',
        showsChevron: true,
        onTap: () => _openAbout(context),
      ),
    ];

void _openSunnahReminders(BuildContext context) {
  final cubit = _sunnahReminders(context);
  if (cubit == null) return;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BlocProvider<RemindersCubit>.value(
      value: cubit,
      child: const RemindersSheet(),
    ),
  );
}

Future<void> _schedulePrayerNotificationTest(BuildContext context) async {
  final cubit = _prayerNotifications(context);
  if (cubit == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final report = await cubit.scheduleDeliveryTest();
  debugPrint('[prayer-notifications] delivery test: $report');
  if (!context.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(report),
        duration: const Duration(seconds: 4),
      ),
    );
}

RemindersCubit? _sunnahReminders(BuildContext context) {
  try {
    return BlocProvider.of<RemindersCubit>(context);
  } catch (_) {
    return null;
  }
}

PrayerNotificationsCubit? _prayerNotifications(BuildContext context) {
  try {
    return BlocProvider.of<PrayerNotificationsCubit>(context);
  } catch (_) {
    return null;
  }
}

Future<void> _setPrayerNotifications(
  BuildContext context,
  bool enabled,
) async {
  final cubit = _prayerNotifications(context);
  if (cubit == null) return;
  if (enabled) {
    await cubit.enable();
  } else {
    await cubit.disable();
  }
}

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
