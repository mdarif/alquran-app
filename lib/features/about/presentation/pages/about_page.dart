import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mushaf_palette.dart';
import 'credits_page.dart';

/// Open the developer site (almarfa.co) in the browser, with a snackbar fallback
/// if no handler is available.
Future<void> _openAlMarfa(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(
    Uri.parse('https://almarfa.co'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Couldn’t open almarfa.co')),
    );
  }
}

/// About / Credits. Surfaces the attributions our content licenses require —
/// the Qur'an text + page layout (KFGQPC), the translations (Tanzil / King Fahd),
/// the bundled fonts (KFGQPC / CC-BY-NC / OFL), and the recitation source — plus
/// a link to the bundled open-source package licenses. Static content.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // Keep in sync with pubspec.yaml `version` (shown to users; rarely changes).
  static const String _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      key: WidgetKeys.aboutPage,
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _BrandHeader(version: _version),
          const SizedBox(height: 20),
          Text(
            'Made for reading',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const _PromiseGrid(),
          const SizedBox(height: 28),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openAlMarfa(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Al Marfa Technologies',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Read simply. Stay connected.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          // One discreet door to the legally-required attributions + the bundled
          // open-source licenses, kept off the main, brand-forward About screen.
          Center(
            child: TextButton(
              key: WidgetKeys.aboutCredits,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreditsPage(version: _version),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                textStyle: theme.textTheme.bodySmall,
              ),
              child: const Text('Licenses & credits'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    return Semantics(
      container: true,
      label:
          'Al Quran. The Qur’an, beautifully simple. Version $version by Al Marfa Technologies.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Al Quran',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: AppTheme.displayFontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'The Qur’an, beautifully simple.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaPill(label: 'Version $version'),
                _MetaPill(
                  label: 'Al Marfa Technologies',
                  onTap: () => _openAlMarfa(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: 28,
              height: 2,
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.onTap});

  final String label;

  /// When set, the pill is tappable and shows an external-link affordance.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(99);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSecondaryContainer,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new_rounded,
              size: 13,
              color: cs.onSecondaryContainer,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return Container(
        decoration:
            BoxDecoration(color: cs.secondaryContainer, borderRadius: radius),
        child: content,
      );
    }
    return Material(
      color: cs.secondaryContainer,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

class _PromiseGrid extends StatelessWidget {
  const _PromiseGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Promise(
          icon: Icons.offline_bolt_rounded,
          title: 'Fully offline',
          detail: 'Read wherever you are, without an account or connection.',
        ),
        SizedBox(height: 8),
        _Promise(
          icon: Icons.translate_rounded,
          title: 'Arabic, Urdu & Hindi',
          detail: 'Clear Quran text with translations for South Asian readers.',
        ),
        SizedBox(height: 8),
        _Promise(
          icon: Icons.visibility_rounded,
          title: 'Comfortable by design',
          detail:
              'Pinch to zoom, calm surfaces, and no complicated navigation.',
        ),
      ],
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
