import 'package:flutter/material.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Al Quran', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(
            'Version $_version · Al Marfa Technologies',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'An offline Quran reader with optional audio recitation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
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
          ListTile(
            key: WidgetKeys.aboutLicenses,
            contentPadding: EdgeInsets.zero,
            title: const Text('Open-source licenses'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Al Quran',
              applicationVersion: _version,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 20),
      ],
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
