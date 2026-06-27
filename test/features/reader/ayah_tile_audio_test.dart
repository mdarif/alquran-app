import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/presentation/widgets/ayah_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ayah = Ayah(
  id: 8,
  surahId: 2,
  ayahNumber: 1,
  textArabic: 'الٓمٓ',
  isSajda: false,
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Finder _iconIn(Finder button, IconData icon) =>
    find.descendant(of: button, matching: find.byIcon(icon));

void main() {
  // The feature flag is a compile-time const, so we exercise the widget params
  // directly (the reader passes a non-null onTogglePlay only under the flag).
  testWidgets('no play control when onTogglePlay is null (flag-off shape)',
      (tester) async {
    await tester.pumpWidget(
      _host(const AyahTile(ayah: _ayah, resources: [], arabicFontSize: 28)),
    );
    expect(find.byKey(WidgetKeys.ayahPlayButton(8)), findsNothing);
  });

  testWidgets('renders a play button that fires the toggle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        AyahTile(
          ayah: _ayah,
          resources: const [],
          arabicFontSize: 28,
          audioState: const AyahAudioState(),
          onTogglePlay: () => taps++,
        ),
      ),
    );
    final btn = find.byKey(WidgetKeys.ayahPlayButton(8));
    expect(btn, findsOneWidget);
    expect(_iconIn(btn, AppIcons.play), findsOneWidget);

    await tester.tap(btn);
    expect(taps, 1);
  });

  testWidgets('shows the pause icon while THIS verse is playing',
      (tester) async {
    await tester.pumpWidget(
      _host(
        AyahTile(
          ayah: _ayah,
          resources: const [],
          arabicFontSize: 28,
          audioState: const AyahAudioState(
            playingAyahId: 8,
            status: RecitationStatus.playing,
          ),
          onTogglePlay: () {},
        ),
      ),
    );
    final btn = find.byKey(WidgetKeys.ayahPlayButton(8));
    expect(_iconIn(btn, AppIcons.pause), findsOneWidget);
    expect(_iconIn(btn, AppIcons.play), findsNothing);
  });

  testWidgets('a DIFFERENT verse playing leaves this tile showing play',
      (tester) async {
    await tester.pumpWidget(
      _host(
        AyahTile(
          ayah: _ayah,
          resources: const [],
          arabicFontSize: 28,
          audioState: const AyahAudioState(
            playingAyahId: 9,
            status: RecitationStatus.playing,
          ),
          onTogglePlay: () {},
        ),
      ),
    );
    final btn = find.byKey(WidgetKeys.ayahPlayButton(8));
    expect(_iconIn(btn, AppIcons.play), findsOneWidget);
  });

  testWidgets('an errored verse shows the retry/error glyph', (tester) async {
    await tester.pumpWidget(
      _host(
        AyahTile(
          ayah: _ayah,
          resources: const [],
          arabicFontSize: 28,
          audioState: const AyahAudioState(errorAyahId: 8),
          onTogglePlay: () {},
        ),
      ),
    );
    final btn = find.byKey(WidgetKeys.ayahPlayButton(8));
    expect(_iconIn(btn, AppIcons.audioError), findsOneWidget);
  });
}
