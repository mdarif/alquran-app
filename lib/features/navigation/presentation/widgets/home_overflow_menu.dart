import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/mushaf_palette.dart' show DayPhase;
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/theme_toggle_button.dart';
import '../../../reader/domain/repositories/ayah_bookmark_repository.dart';
import '../../../reader/domain/repositories/ayah_repository.dart';
import '../../../reader/presentation/pages/bookmarks_page.dart';
import '../../../translations/presentation/translations_sheet.dart';
import '../pages/app_settings_page.dart';

/// Phase → app-bar glyph (mirrors [ThemeToggleButton]'s private mapping); Dusk
/// is the only filled one (the golden going-down light).
IconData _phaseIcon(DayPhase phase) => switch (phase) {
      DayPhase.fajr => AppIcons.phaseFajr,
      DayPhase.duha => AppIcons.phaseDuha,
      DayPhase.asr => AppIcons.phaseAsr,
      DayPhase.maghrib => AppIcons.phaseMaghrib,
      DayPhase.isha => AppIcons.phaseIsha,
    };

bool _phaseFilled(DayPhase phase) => phase == DayPhase.maghrib;

/// The Home app-bar overflow (`⋯`) that gathers the secondary controls the bar
/// used to show as separate icons — currently the Reading-Light picker plus
/// library/app destinations — so the bar stays uncrowded next to the title +
/// prayer pill. Each item is gated by its feature flag (passed in by [HomePage])
/// and reuses the existing sheets. Cubits are read DEFENSIVELY so an isolated
/// pump won't crash.
class HomeOverflowMenu extends StatelessWidget {
  const HomeOverflowMenu({
    required this.showReadingLight,
    super.key,
  });

  final bool showReadingLight;

  static T? _cubit<T extends StateStreamableSource<Object?>>(
    BuildContext context,
  ) {
    try {
      return BlocProvider.of<T>(context);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = showReadingLight ? _cubit<ThemeCubit>(context) : null;

    // MenuAnchor (not PopupMenuButton) so the menu hugs its content — the popup
    // menu rounds its width up in fixed steps, leaving a blank strip on the right.
    return MenuAnchor(
      alignmentOffset: const Offset(-18, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        elevation: const WidgetStatePropertyAll(4),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.16),
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      builder: (context, controller, _) => IconButton(
        key: WidgetKeys.homeOverflowMenu,
        tooltip: 'More',
        icon: const AppIcon(AppIcons.overflow),
        iconSize: AppIconSize.bar,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        if (theme != null)
          _MenuItem(
            icon: _phaseIcon(theme.activePhase),
            filled: _phaseFilled(theme.activePhase),
            label: 'Reading Theme',
            onPressed: () => _openReadingLight(context, theme),
          ),
        _MenuItem(
          key: WidgetKeys.translationsMenuButton,
          icon: AppIcons.alKahf,
          label: 'Translations',
          onPressed: () => _openTranslations(context),
        ),
        _MenuItem(
          key: WidgetKeys.bookmarksMenuButton,
          icon: AppIcons.bookmark,
          label: 'Bookmarks',
          onPressed: () => _openBookmarks(context),
        ),
        _MenuItem(
          key: WidgetKeys.homeSettingsMenuButton,
          icon: AppIcons.settings,
          label: 'Settings',
          onPressed: () => _openSettings(context),
        ),
      ],
    );
  }

  void _openBookmarks(BuildContext context) {
    if (!GetIt.I.isRegistered<AyahBookmarkRepository>() ||
        !GetIt.I.isRegistered<AyahRepository>()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Restart Al Quran to finish enabling bookmarks'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookmarksPage(
          bookmarks: GetIt.I<AyahBookmarkRepository>(),
          ayahs: GetIt.I<AyahRepository>(),
        ),
      ),
    );
  }

  void _openTranslations(BuildContext context) {
    showTranslationsSheet(context);
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AppSettingsPage()),
    );
  }

  void _openReadingLight(BuildContext context, ThemeCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocProvider<ThemeCubit>.value(
        value: cubit,
        child: const ReadingLightSheet(),
      ),
    );
  }
}

/// One compact overflow entry — a [MenuItemButton] that hugs its content.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = cs.onSurface.withValues(alpha: 0.70);
    return SizedBox(
      width: 252,
      child: MenuItemButton(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(18, 8, 18, 8),
          ),
          overlayColor: WidgetStatePropertyAll(
            cs.primary.withValues(alpha: 0.08),
          ),
          foregroundColor: WidgetStatePropertyAll(cs.onSurface),
          textStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
          ),
        ),
        leadingIcon: SizedBox.square(
          dimension: 24,
          child: Center(
            child: AppIcon(
              icon,
              filled: filled,
              size: AppIconSize.action,
              color: iconColor,
            ),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
