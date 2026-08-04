import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../app_update/domain/entities/app_update_prompt.dart';
import '../../../app_update/domain/repositories/app_update_repository.dart';
import '../../../prayer_times/presentation/widgets/hijri_date_line.dart';
import '../../../prayer_times/presentation/widgets/next_prayer_pill.dart';
import '../../../reader/presentation/widgets/last_read_banner.dart';
import '../../../surahs/presentation/cubit/surah_list_cubit.dart';
import '../../../surahs/presentation/pages/surah_list_page.dart';
import '../../domain/entities/index_kind.dart';
import '../widgets/home_overflow_menu.dart';
import 'index_list_page.dart';

/// App home: an immersive, full-width Surah list with the "continue reading"
/// resume card. Page/Juz/Hizb/Ruku stay out of the way behind a single "Jump to"
/// sheet (gated by [FeatureFlags.advancedNavigation]) so the reader keeps focus.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.advancedNavigation = FeatureFlags.advancedNavigation,
    this.prayerTimes = FeatureFlags.prayerTimes,
    this.hijriDate = FeatureFlags.hijriDate,
    this.sunnahReminders = FeatureFlags.sunnahReminders,
    this.lastReadBanner = FeatureFlags.lastReadBanner,
    this.lightOfDay = FeatureFlags.lightOfDay,
    this.softUpdateReminder = FeatureFlags.softUpdateReminder,
  });

  /// Whether to surface Page/Juz/Hizb/Ruku navigation. Injectable for tests.
  final bool advancedNavigation;

  /// Whether to surface the next-prayer pill (and, through it, the times sheet
  /// and location request). Injectable for tests.
  final bool prayerTimes;

  /// Whether to show the Hijri dateline under the title. Injectable for tests.
  final bool hijriDate;

  /// Whether to show the Sunnah-reminders button. Injectable for tests.
  final bool sunnahReminders;

  /// Whether to show the "continue reading" resume banner. Injectable for tests.
  final bool lastReadBanner;

  /// Whether to show the reading-light (Light of Day) toggle. Injectable for tests.
  final bool lightOfDay;

  /// Whether Home checks for and shows a soft app-update reminder.
  final bool softUpdateReminder;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // The surah-list cubit is provided at this level (not inside the body) so the
  // app-bar search can drive it: SurahListBody reads it ambiently below.
  late final SurahListCubit _surahs = GetIt.I<SurahListCubit>()..load();

  // Search mode: the app bar becomes a back-arrow + search field; every other
  // control (prayer pill, overflow) tucks away until it's closed.
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  AppUpdateRepository? _updates;
  AppUpdatePrompt? _updatePrompt;

  @override
  void initState() {
    super.initState();
    if (widget.softUpdateReminder &&
        GetIt.I.isRegistered<AppUpdateRepository>()) {
      _updates = GetIt.I<AppUpdateRepository>();
      _loadUpdatePrompt();
    }
  }

  Future<void> _loadUpdatePrompt() async {
    final prompt = await _updates?.check();
    if (!mounted || prompt == null) return;
    setState(() => _updatePrompt = prompt);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _surahs.close();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    // Focus after the field is in the tree so the keyboard opens immediately.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    _searchCtrl.clear();
    _surahs.search('');
    _searchFocus.unfocus();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SurahListCubit>.value(
      value: _surahs,
      child: PopScope(
        // A system back closes search first (rather than leaving the screen).
        canPop: !_searching,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _searching) _closeSearch();
        },
        child: Scaffold(
          appBar: _searching ? _searchAppBar(context) : _defaultAppBar(context),
          body: Column(
            children: [
              if (_updatePrompt != null)
                _AppUpdateBanner(
                  prompt: _updatePrompt!,
                  onUpdate: () => _openUpdate(_updatePrompt!),
                  onLater: () => _dismissUpdate(_updatePrompt!),
                ),
              if (widget.lastReadBanner) const LastReadBanner(),
              const Expanded(child: SurahListBody()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUpdate(AppUpdatePrompt prompt) async {
    await launchUrl(prompt.storeUrl, mode: LaunchMode.externalApplication);
  }

  Future<void> _dismissUpdate(AppUpdatePrompt prompt) async {
    await _updates?.dismiss(prompt.latestVersion);
    if (mounted) setState(() => _updatePrompt = null);
  }

  /// The default bar: the title, the prayer pill, a search icon, and the
  /// reading-light/library/settings overflow.
  AppBar _defaultAppBar(BuildContext context) {
    return AppBar(
      centerTitle: false,
      // Plain title — About now lives as a visible entry in the ⋯ overflow (it
      // used to be a discreet tap here).
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Al Quran'),
          if (widget.hijriDate) const HijriDateLine(),
        ],
      ),
      actions: [
        if (widget.advancedNavigation)
          IconButton(
            key: WidgetKeys.jumpButton,
            tooltip: 'Jump to (Page · Juz · Hizb · Ruku)',
            icon: const AppIcon(AppIcons.jumpMenu),
            onPressed: () => _openJumpSheet(context),
          ),
        if (widget.prayerTimes) const NextPrayerPill(),
        IconButton(
          key: WidgetKeys.surahSearchButton,
          tooltip: 'Search surah',
          icon: const AppIcon(AppIcons.search),
          onPressed: _openSearch,
        ),
        // Secondary sections and settings fold into one overflow so the bar
        // stays uncrowded next to the title, prayer pill and search.
        HomeOverflowMenu(
          showReadingLight: widget.lightOfDay,
        ),
      ],
    );
  }

  /// Search mode: a back arrow (left) + the search field. Back exits and clears;
  /// everything else is hidden while searching.
  AppBar _searchAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      leading: IconButton(
        key: WidgetKeys.surahSearchBack,
        tooltip: 'Back',
        icon: const AppIcon(AppIcons.back),
        onPressed: _closeSearch,
      ),
      titleSpacing: 0,
      title: TextField(
        key: WidgetKeys.surahSearchField,
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _surahs.search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: 'Search surah — name or number',
          hintStyle: TextStyle(color: cs.onSurfaceVariant),
        ),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      actions: [
        // Clear the text without leaving search (only when there's something).
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchCtrl,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const AppIcon(AppIcons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    _surahs.search('');
                    _searchFocus.requestFocus();
                  },
                ),
        ),
      ],
    );
  }

  void _openJumpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Jump to',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.page,
              label: 'Page',
              icon: AppIcons.page,
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.juz,
              label: 'Juz',
              icon: AppIcons.juz,
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.hizb,
              label: 'Hizb',
              icon: AppIcons.hizb,
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.ruku,
              label: 'Ruku',
              icon: AppIcons.ruku,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppUpdateBanner extends StatelessWidget {
  const _AppUpdateBanner({
    required this.prompt,
    required this.onUpdate,
    required this.onLater,
  });

  final AppUpdatePrompt prompt;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      key: WidgetKeys.appUpdateBanner,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIcon(
                AppIcons.autoSelected,
                filled: true,
                size: AppIconSize.label,
                color: cs.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Update available',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      prompt.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: WidgetKeys.appUpdateNowButton,
                onPressed: onUpdate,
                child: const Text('Update'),
              ),
              IconButton(
                key: WidgetKeys.appUpdateLaterButton,
                tooltip: 'Later',
                visualDensity: VisualDensity.compact,
                onPressed: onLater,
                icon: const AppIcon(AppIcons.close, size: AppIconSize.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpTile extends StatelessWidget {
  const _JumpTile({
    required this.parentContext,
    required this.kind,
    required this.label,
    required this.icon,
  });

  /// The page context (not the sheet's) — used to push after the sheet closes.
  final BuildContext parentContext;
  final IndexKind kind;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AppIcon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop(); // close the sheet
        Navigator.of(parentContext).push(
          MaterialPageRoute<void>(
            builder: (_) => IndexListPage(kind: kind, label: label),
          ),
        );
      },
    );
  }
}
