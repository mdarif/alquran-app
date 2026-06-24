// Dev-only Arabic-rendering diagnostic. Run with:
//   flutter run -t lib/main_arabic_diag.dart       (or `make diag-arabic`)
//
// Renders a labelled MARK test-matrix in BOTH shipped Quran faces (UthmanicHafs
// + Noorehuda) so we can see exactly what FLUTTER on-device does with each
// harakat / hamza / dagger-alef / the flagged Fatiha words — because HarfBuzz
// (`hb-view`) can render a mark correctly while Flutter drops/mis-anchors it
// (LEARNINGS §1). Screenshot this; compare each mark between the two columns and
// against a reference Mushaf. Toggle the background (top-right) to reproduce the
// light vs dark observation. Not part of the shipped app.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

void main() => runApp(const ArabicDiagApp());

class ArabicDiagApp extends StatelessWidget {
  const ArabicDiagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Arabic diag',
      debugShowCheckedModeBanner: false,
      home: _DiagPage(),
    );
  }
}

/// (label, text rendered in BOTH fonts) — synthetic, isolates one mark.
const _harakat = <(String, String)>[
  ('fatha · 064E', 'بَ'),
  ('kasra · 0650', 'بِ'),
  ('damma · 064F', 'بُ'),
  ('sukun · 0652', 'بْ'),
  ('shadda · 0651', 'بّ'),
  ('shadda+fatha', 'بَّ'),
  ('tanwin fath · 064B', 'بً'),
  ('tanwin kasr · 064D', 'بٍ'),
  ('tanwin damm · 064C', 'بٌ'),
  ('dagger-alef · 0670', 'بٰ'),
  ('alef-madda · 0622', 'آ'),
  ('dagger+maddah · 0670 0653', 'بٰٓ'),
  ('indopak sukun · 06E1', 'بۡ'),
  ('alef-wasla · 0671', 'ٱل'),
];

const _hamza = <(String, String)>[
  ('hamza · 0621', 'ءَ'),
  ('alef+hamza above · 0623', 'أَ'),
  ('alef+hamza below · 0625', 'إِ'),
  ('waw+hamza · 0624', 'ؤُ'),
  ('yeh+hamza · 0626', 'ئِ'),
];

/// (label, Uthmani encoding, IndoPak encoding) — the EXACT shipping DB strings
/// for the words the owner flagged on Surah al-Fatiha.
const _words = <(String, String, String)>[
  ('1:2  al-hamdu — fatha on the alef', 'ٱلۡحَمۡدُ', 'اَلۡحَمۡدُ'),
  ('1:4  maalik — dagger-alef', 'مَٰلِكِ', 'مٰلِكِ'),
  ('1:5  iyyaka — no spurious hamza in IndoPak', 'إِيَّاكَ', 'اِيَّاكَ'),
  ('1:6  ihdina — kasra under the alef', 'ٱهۡدِنَا', 'اِهۡدِنَا'),
];

class _DiagPage extends StatefulWidget {
  const _DiagPage();
  @override
  State<_DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<_DiagPage> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final fg = _dark ? Colors.white : Colors.black;
    final bg = _dark ? const Color(0xFF1B1B1B) : const Color(0xFFFBF7EE);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Arabic diag'),
        actions: [
          Row(
            children: [
              const Text('dark'),
              Switch(value: _dark, onChanged: (v) => setState(() => _dark = v)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _header('Harakat (same text, both fonts)', fg),
          for (final (label, text) in _harakat) _compare(label, text, text, fg),
          _header('Hamza forms', fg),
          for (final (label, text) in _hamza) _compare(label, text, text, fg),
          _header('Flagged Fatiha words (real shipping text)', fg),
          for (final (label, uth, ind) in _words) _compare(label, uth, ind, fg),
        ],
      ),
    );
  }

  Widget _header(String t, Color fg) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
        child: Text(
          t,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: fg,
            fontSize: 13,
          ),
        ),
      );

  Widget _compare(String label, String uthText, String indText, Color fg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cell(
                'UthmanicHafs',
                uthText,
                AppTheme.arabicFontFamily,
                AppTheme.arabicFontFeatures,
                fg,
              ),
              _cell(
                'Noorehuda',
                indText,
                AppTheme.indopakFontFamily,
                AppTheme.indopakFontFeatures,
                fg,
              ),
            ],
          ),
          Divider(height: 18, color: fg.withValues(alpha: 0.12)),
        ],
      ),
    );
  }

  Widget _cell(
    String font,
    String text,
    String family,
    List<FontFeature> features,
    Color fg,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            font,
            style: TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
            style: TextStyle(
              fontFamily: family,
              fontFeatures: features,
              fontSize: 46,
              height: 1.7,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
