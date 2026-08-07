import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/launch_url_with_fallback.dart';
import '../../../app_update/domain/entities/app_update_prompt.dart';
import '../../../app_update/presentation/cubit/app_update_cubit.dart';
import '../../../app_update/presentation/cubit/app_update_state.dart';
import '../../../prayer_times/presentation/widgets/hijri_date_line.dart';
import '../../../prayer_times/presentation/widgets/next_prayer_pill.dart';
import '../../../reader/presentation/widgets/last_read_banner.dart';
import '../../../reader/domain/entities/reader_target.dart';
import '../../../reader/presentation/pages/reader_page.dart';
import '../../../surahs/presentation/cubit/surah_list_cubit.dart';
import '../../../surahs/presentation/pages/surah_list_page.dart';
import '../../domain/entities/index_kind.dart';
import '../widgets/index_list_view.dart';
import '../widgets/start_reading_row.dart';

/// App home: an immersive, full-width Surah list with the "continue reading"
/// resume card and a visible Surah/Juz/Page switcher so Juz and
/// Page navigation don't hide behind a discoverability-poor app-bar icon.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.prayerTimes = FeatureFlags.prayerTimes,
    this.hijriDate = FeatureFlags.hijriDate,
    this.sunnahReminders = FeatureFlags.sunnahReminders,
    this.lastReadBanner = FeatureFlags.lastReadBanner,
    this.softUpdateReminder = FeatureFlags.softUpdateReminder,
    this.onOpenPrayerTab,
    this.onChromeCollapsedChanged,
  });

  /// Whether to surface the next-prayer pill (and, through it, the times sheet
  /// and location request). Injectable for tests.
  final bool prayerTimes;

  /// Whether to show the Hijri dateline under the title. Injectable for tests.
  final bool hijriDate;

  /// Whether to show the Sunnah-reminders button. Injectable for tests.
  final bool sunnahReminders;

  /// Whether to show the "continue reading" resume banner. Injectable for tests.
  final bool lastReadBanner;

  /// Whether Home checks for and shows a soft app-update reminder.
  final bool softUpdateReminder;

  /// When set (the shell wires this), tapping the prayer pill switches to
  /// the Prayer tab instead of opening the old bottom sheet.
  final VoidCallback? onOpenPrayerTab;

  /// Reports Home's scroll-immersion state to the shell so the bottom nav can
  /// collapse while readers browse Surah/Juz/Page lists.
  final ValueChanged<bool>? onChromeCollapsedChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const double _chromeScrollThreshold = 36;

  // The surah-list cubit is provided at this level (not inside the body) so the
  // app-bar search can drive it: SurahListBody reads it ambiently below.
  late final SurahListCubit _surahs = GetIt.I<SurahListCubit>()..load();

  // Search mode: the app bar becomes a back-arrow + search field; every other
  // control (prayer pill, overflow) tucks away until it's closed.
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  AppUpdateCubit? _updateCubit;
  ReadMode _readMode = ReadMode.surah;
  bool _chromeCollapsed = false;
  double _chromeScrollIntent = 0;

  @override
  void initState() {
    super.initState();
    if (widget.softUpdateReminder && GetIt.I.isRegistered<AppUpdateCubit>()) {
      _updateCubit = GetIt.I<AppUpdateCubit>()..check();
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.onChromeCollapsedChanged?.call(false);
    if (_updateCubit != null) WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _surahs.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A newer version may have been published while the app sat backgrounded
    // — re-check on resume so the banner doesn't need a full app restart to
    // catch up.
    if (state == AppLifecycleState.resumed) {
      _updateCubit?.check();
    }
  }

  void _openSearch() {
    _setChromeCollapsed(false);
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

  void _setChromeCollapsed(bool collapsed) {
    if (_chromeCollapsed == collapsed) return;
    _chromeScrollIntent = 0;
    setState(() => _chromeCollapsed = collapsed);
    widget.onChromeCollapsedChanged?.call(collapsed);
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (_searching) return false;
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.pixels <= 0) {
      _chromeScrollIntent = 0;
      _setChromeCollapsed(false);
      return false;
    }
    if (n case ScrollUpdateNotification(:final scrollDelta?)) {
      if (scrollDelta == 0) return false;
      final directionMatchesState = (_chromeCollapsed && scrollDelta < 0) ||
          (!_chromeCollapsed && scrollDelta > 0);
      _chromeScrollIntent =
          directionMatchesState ? _chromeScrollIntent + scrollDelta.abs() : 0;
      if (_chromeScrollIntent < _chromeScrollThreshold) return false;
      if (scrollDelta > 0 && !_chromeCollapsed) {
        _setChromeCollapsed(true);
      } else if (scrollDelta < 0 && _chromeCollapsed) {
        _setChromeCollapsed(false);
      }
    }
    return false;
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
          body: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: Column(
              children: [
                _HomeContextChrome(
                  collapsed: _chromeCollapsed,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_updateCubit != null)
                        BlocBuilder<AppUpdateCubit, AppUpdateState>(
                          bloc: _updateCubit,
                          buildWhen: (a, b) => a.phase != b.phase,
                          builder: (context, state) {
                            if (state.phase != AppUpdatePhase.available) {
                              return const SizedBox.shrink();
                            }
                            final prompt = state.prompt!;
                            return _AppUpdateBanner(
                              prompt: prompt,
                              onUpdate: () => _openUpdate(prompt),
                              onLater: prompt.required
                                  ? null
                                  : () => _updateCubit?.dismiss(),
                            );
                          },
                        ),
                      if (widget.lastReadBanner) const LastReadBanner(),
                      StartReadingRow(
                        selectedMode: _readMode,
                        onSurah: () =>
                            setState(() => _readMode = ReadMode.surah),
                        onJuz: () => setState(() => _readMode = ReadMode.juz),
                        onPage: () => setState(() => _readMode = ReadMode.page),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _readBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUpdate(AppUpdatePrompt prompt) async {
    await launchUrlWithFallback(
      context,
      prompt.storeUrl,
      failureMessage: 'Couldn’t open the Play Store',
    );
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
        if (widget.prayerTimes)
          NextPrayerPill(onOpenPrayerTab: widget.onOpenPrayerTab),
        IconButton(
          key: WidgetKeys.surahSearchButton,
          tooltip: 'Search surah',
          icon: const AppIcon(AppIcons.search),
          onPressed: _openSearch,
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

  Widget _readBody() {
    return switch (_readMode) {
      ReadMode.surah => const SurahListBody(),
      ReadMode.juz => IndexListView(
          key: const ValueKey('read-index-juz'),
          kind: IndexKind.juz,
          label: 'Juz',
          onTargetSelected: _openReader,
        ),
      ReadMode.page => IndexListView(
          key: const ValueKey('read-index-page'),
          kind: IndexKind.page,
          label: 'Page',
          onTargetSelected: _openReader,
        ),
    };
  }

  void _openReader(ReaderTarget target) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(target: target),
      ),
    );
  }
}

class _HomeContextChrome extends StatelessWidget {
  const _HomeContextChrome({
    required this.collapsed,
    required this.child,
  });

  final bool collapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: collapsed ? 0 : 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: FractionalTranslation(
              translation: Offset(0, -(1 - t)),
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: IgnorePointer(
                  ignoring: collapsed,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: child,
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

  /// Null for a required update — "Later" isn't offered.
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      key: WidgetKeys.appUpdateBanner,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
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
                      prompt.required ? 'Update required' : 'Update available',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: prompt.required ? cs.error : cs.onSurface,
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
              if (onLater != null)
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
