import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../app_update/presentation/cubit/app_update_cubit.dart';
import '../../../app_update/presentation/cubit/app_update_state.dart';
import '../../../reader/domain/entities/translation_resource.dart';
import '../../../reader/domain/repositories/ayah_repository.dart';
import '../../../reader/domain/repositories/reader_settings_repository.dart';
import '../../../reader/presentation/pages/reader_settings_page.dart';
import '../../../prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import '../../../prayer_times/presentation/cubit/prayer_notifications_state.dart';
import '../../../translations/presentation/translations_sheet.dart';
import 'app_settings_actions.dart';

const double _minFont = 20;
const double _maxFont = 48;

/// Home opens the same Settings surface as the reader, backed by persisted
/// reading preferences instead of live reader callbacks.
class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final ReaderSettingsRepository _settings =
      GetIt.I<ReaderSettingsRepository>();
  late Future<List<TranslationResource>> _resources = _loadResources();
  AppUpdateCubit? _updateCubit;
  StreamSubscription<AppUpdateState>? _updateSub;

  Future<List<TranslationResource>> _loadResources() {
    if (!GetIt.I.isRegistered<AyahRepository>()) {
      return Future.value(const <TranslationResource>[]);
    }
    return GetIt.I<AyahRepository>().getTranslationResources();
  }

  @override
  void initState() {
    super.initState();
    if (FeatureFlags.softUpdateReminder &&
        GetIt.I.isRegistered<AppUpdateCubit>()) {
      final cubit = GetIt.I<AppUpdateCubit>();
      _updateCubit = cubit;
      // The cubit is a shared singleton (Home reads it too), so re-render
      // whenever its state changes rather than only after our own check().
      _updateSub = cubit.stream.listen((_) {
        if (mounted) setState(() {});
      });
      cubit.check();
    }
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (FeatureFlags.prayerTimes && FeatureFlags.prayerTimeNotifications) {
      return BlocBuilder<PrayerNotificationsCubit, PrayerNotificationsState>(
        builder: (context, _) => _buildSettings(context),
      );
    }
    return _buildSettings(context);
  }

  Widget _buildSettings(BuildContext context) {
    return FutureBuilder<List<TranslationResource>>(
      future: _resources,
      builder: (context, snapshot) {
        final resources = snapshot.data ?? const <TranslationResource>[];
        final updateCubit = _updateCubit;
        return ReaderSettingsPage(
          key: WidgetKeys.appSettingsPage,
          fontSize: _settings.fontSize,
          minFont: _minFont,
          maxFont: _maxFont,
          onFontChanged: (v) => _settings.setFontSize(v),
          script: _settings.script,
          onScriptChanged: (v) => _settings.setScript(v),
          resources: resources,
          activeTranslationSummary: _translationSummary(resources),
          showTranslations: false,
          onOpenTranslations: () => showTranslationsSheet(
            context,
            onTranslationsChanged: () {
              setState(() => _resources = _loadResources());
            },
          ),
          isReading: !_settings.detailed,
          showTranslationPeek: FeatureFlags.readingTranslationPeek &&
              _settings.showTranslationPeek,
          onToggleTranslationPeek: (v) => _settings.setShowTranslationPeek(v),
          showArabicMatn: _settings.showArabicMatn,
          onToggleShowArabic: (v) => _settings.setShowArabicMatn(v),
          onReset: _resetReadingPreferences,
          appActions: appSettingsActions(
            context,
            updateCubit: updateCubit,
            updateState: updateCubit?.state,
          ),
        );
      },
    );
  }

  String _translationSummary(List<TranslationResource> resources) {
    if (resources.isEmpty) return 'None';
    final active = _settings.selectedTranslations?.toSet() ??
        {
          for (final r in resources)
            if (r.defaultOn) r.slug,
        };
    final names = [
      for (final r in resources)
        if (active.contains(r.slug)) _languageName(r),
    ];
    if (names.isEmpty) return 'None';
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String _languageName(TranslationResource r) {
    if (r.languageCode == 'ur') return 'Urdu';
    if (r.languageCode == 'hi') return 'Hindi';
    if (r.languageCode == 'en') return 'English';
    return r.languageLabel;
  }

  Future<void> _resetReadingPreferences() async {
    final confirmed = await confirmAction(
      context,
      title: 'Reset reading preferences?',
      message: 'Font size, script, translations shown, and the reading '
          'aids below all return to their defaults.',
      confirmLabel: 'Reset',
    );
    if (!confirmed) return;
    await _settings.resetToDefaults();
    if (mounted) setState(() {});
  }
}
