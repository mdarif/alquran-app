import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mushaf_palette.dart';
import 'credits_page.dart';

/// Open an external site in the browser, with a snackbar fallback if no
/// handler is available.
Future<void> _openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text('Couldn’t open ${uri.host}')),
    );
  }
}

/// About / Credits. Surfaces the attributions our content licenses require —
/// the Qur'an text + page layout (KFGQPC), the translations (Tanzil / King Fahd),
/// the bundled fonts (KFGQPC / CC-BY-NC / OFL), and the recitation source — plus
/// a link to the bundled open-source package licenses. Static content.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  // Read from the platform so it always matches pubspec.yaml — no manual sync.
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

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
          _BrandHeader(version: _version),
          const SizedBox(height: 20),
          Text(
            'Built for Reading',
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
              onTap: () => _openExternal(context, 'https://almarfa.co'),
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
            'Building simple, beautiful apps that benefit Muslims.',
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
                  builder: (_) => CreditsPage(version: _version ?? ''),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                textStyle: theme.textTheme.bodySmall,
              ),
              child: const Text('Credits & Licenses'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.version});

  /// Null while the platform lookup is in flight — the version pill is hidden
  /// rather than showing an empty "Version ".
  final String? version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    final version = this.version;
    return Semantics(
      container: true,
      label: 'Al Quran. Read. Reflect. Remember.'
          '${version == null ? '' : ' Version $version'}'
          ' Also on the web at alquranreader.com.',
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
              'Read. Reflect. Remember.',
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
                if (version != null) _MetaPill(label: 'Version $version'),
                // The reader lives on the web too — the header links it; the
                // company credit stays below, next to Credits & Licenses.
                _MetaPill(
                  label: 'alquranreader.com',
                  onTap: () =>
                      _openExternal(context, 'https://alquranreader.com'),
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
          title: 'Fully Offline',
          detail: 'No internet. No sign-up. Just read.',
        ),
        SizedBox(height: 8),
        _Promise(
          icon: Icons.translate_rounded,
          title: 'Arabic, Urdu, Hindi & English',
          detail: 'Beautiful Arabic text with carefully selected translations.',
        ),
        SizedBox(height: 8),
        _Promise(
          icon: Icons.visibility_rounded,
          title: 'Designed for Comfort',
          detail: 'Designed for long, comfortable reading sessions.',
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
