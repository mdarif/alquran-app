import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sahih = TranslationResource(
  id: 1,
  slug: 'en-sahih-international',
  languageCode: 'en',
  name: 'Sahih International',
);
const _urdu = TranslationResource(
  id: 2,
  slug: 'ur-junagarhi',
  languageCode: 'ur',
  name: 'Urdu',
  direction: 'rtl',
);

Widget _settingsPage({
  required bool isReading,
  required List<TranslationResource> resources,
  bool translationAudioDuringContinuousPlayback = true,
  ValueChanged<bool>? onToggleTranslationAudioDuringContinuousPlayback,
}) {
  return MaterialApp(
    home: ReaderSettingsPage(
      fontSize: 28,
      minFont: 20,
      maxFont: 48,
      onFontChanged: (_) {},
      script: ArabicScript.uthmani,
      onScriptChanged: (_) {},
      resources: resources,
      activeTranslationSummary: 'None',
      onOpenTranslations: () {},
      isReading: isReading,
      showTranslationPeek: false,
      onToggleTranslationPeek: (_) {},
      showArabicMatn: true,
      onToggleShowArabic: (_) {},
      translationAudioDuringContinuousPlayback:
          translationAudioDuringContinuousPlayback,
      onToggleTranslationAudioDuringContinuousPlayback:
          onToggleTranslationAudioDuringContinuousPlayback ?? (_) {},
      onReset: () {},
    ),
  );
}

void main() {
  group('translation-audio continuous-playback toggle', () {
    testWidgets('shown in Detailed when an audio-backed translation exists',
        (tester) async {
      await tester.pumpWidget(
        _settingsPage(isReading: false, resources: const [_sahih, _urdu]),
      );
      expect(
        find.byKey(WidgetKeys.translationAudioContinuousToggle),
        findsOneWidget,
      );
    });

    testWidgets('hidden in Reading (translation audio is Detailed-only)',
        (tester) async {
      await tester.pumpWidget(
        _settingsPage(isReading: true, resources: const [_sahih, _urdu]),
      );
      expect(
        find.byKey(WidgetKeys.translationAudioContinuousToggle),
        findsNothing,
      );
    });

    testWidgets('hidden when no available translation has an audio track',
        (tester) async {
      await tester.pumpWidget(
        _settingsPage(isReading: false, resources: const [_urdu]),
      );
      expect(
        find.byKey(WidgetKeys.translationAudioContinuousToggle),
        findsNothing,
      );
    });

    testWidgets('reflects the persisted value and reports changes',
        (tester) async {
      bool? reported;
      await tester.pumpWidget(
        _settingsPage(
          isReading: false,
          resources: const [_sahih],
          translationAudioDuringContinuousPlayback: true,
          onToggleTranslationAudioDuringContinuousPlayback: (v) => reported = v,
        ),
      );
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(WidgetKeys.translationAudioContinuousToggle),
      );
      expect(toggle.value, isTrue);

      await tester.tap(
        find.byKey(WidgetKeys.translationAudioContinuousToggle),
      );
      await tester.pump();
      expect(reported, isFalse);
    });
  });
}
