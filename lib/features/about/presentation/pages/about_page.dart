import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mushaf_palette.dart';

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
          Text(
            'Sources & acknowledgements',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The Qur’an deserves clarity about where its text and translations come from.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const _Section(
            title: 'Qur’an text',
            children: [
              _Credit(
                name: 'Arabic text & 604-page layout',
                detail:
                    '© King Fahd Glorious Qur’an Printing Complex (KFGQPC).',
              ),
              if (FeatureFlags.indopakScript)
                _Credit(
                  name: 'IndoPak text',
                  detail: 'Quran.com.',
                ),
            ],
          ),
          const _Section(
            title: 'Translations',
            children: [
              _Credit(
                name: 'Urdu — Maulana Muhammad Junagarhi',
                detail: 'Tanzil Project · tanzil.net',
              ),
              _Credit(
                name: 'Hindi — Suhel Farooq Khan & Saifur Rahman Nadwi',
                detail: 'Tanzil Project · tanzil.net',
              ),
              _Credit(
                name: 'English — Dr. Hilali & Dr. Muhsin Khan',
                detail: 'King Fahd Complex, Madinah.',
              ),
            ],
          ),
          const _Section(
            title: 'Fonts',
            children: [
              _Credit(
                name: 'KFGQPC Uthmanic Hafs',
                detail: 'King Fahd Complex (KFGQPC).',
              ),
              _Credit(
                name: 'Noorehuda (IndoPak)',
                detail: 'Abu Saad · CC BY-NC.',
              ),
              _Credit(
                name: 'Noto Nastaliq Urdu',
                detail: 'Google · SIL Open Font License 1.1.',
              ),
              _Credit(
                name: 'Noto Sans Devanagari',
                detail: 'Google · SIL Open Font License 1.1.',
              ),
              _Credit(
                name: 'Playfair Display',
                detail: 'Claus Eggers Sørensen · SIL Open Font License 1.1.',
              ),
            ],
          ),
          if (FeatureFlags.audioRecitation)
            const _Section(
              title: 'Recitation',
              children: [
                _Credit(
                  name: 'Mishary Rashid Alafasy',
                  detail: 'Audio via islamic.network.',
                ),
              ],
            ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              key: WidgetKeys.aboutLicenses,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Icon(Icons.code_rounded, color: cs.primary),
              title: const Text('Open-source licenses'),
              subtitle:
                  const Text('Libraries that help make Al Quran possible'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Al Quran',
                applicationVersion: _version,
              ),
            ),
          ),
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

/// A titled credits group.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// One attribution line: a name over a muted detail/source.
class _Credit extends StatelessWidget {
  const _Credit({required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.bodyLarge),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
