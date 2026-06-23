import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MushafPalette — the five lights', () {
    test('every DayPhase has a palette (of() never throws)', () {
      for (final phase in DayPhase.values) {
        final palette = MushafPalette.of(phase);
        expect(palette.phase, phase);
      }
    });

    test('ordered returns all five in day order', () {
      expect(
        MushafPalette.ordered.map((p) => p.phase).toList(),
        DayPhase.values,
      );
    });

    test('Isha is the only dark surface; the rest are light', () {
      for (final p in MushafPalette.ordered) {
        expect(
          p.brightness,
          p.phase == DayPhase.isha ? Brightness.dark : Brightness.light,
          reason: '${p.phase} brightness',
        );
      }
    });

    test('every palette has readable ink (distinct from its surface)', () {
      for (final p in MushafPalette.ordered) {
        expect(p.ink, isNot(p.background), reason: '${p.phase} ink==bg');
      }
    });
  });

  group('MushafPalette.toTheme — maps colours onto the ThemeData', () {
    test('each palette wires surface, ink, accent, badge, gold + brightness',
        () {
      for (final p in MushafPalette.ordered) {
        final theme = p.toTheme();
        final cs = theme.colorScheme;
        final reason = '${p.phase}';
        expect(theme.scaffoldBackgroundColor, p.background, reason: reason);
        expect(cs.surface, p.background, reason: reason);
        expect(cs.onSurface, p.ink, reason: reason);
        expect(cs.primary, p.accent, reason: reason);
        expect(cs.primaryContainer, p.accentContainer, reason: reason);
        expect(cs.onPrimaryContainer, p.onAccentContainer, reason: reason);
        expect(cs.brightness, p.brightness, reason: reason);
        expect(theme.appBarTheme.backgroundColor, p.background, reason: reason);
        // The ornament gold rides a ThemeExtension (no ColorScheme slot).
        expect(theme.extension<MushafColors>()?.gold, p.gold, reason: reason);
      }
    });
  });

  group('MushafPalette.phaseForHour — the day → its light', () {
    test('maps the boundaries', () {
      expect(MushafPalette.phaseForHour(0), DayPhase.isha);
      expect(MushafPalette.phaseForHour(4), DayPhase.isha); // pre-dawn
      expect(MushafPalette.phaseForHour(5), DayPhase.fajr); // first light
      expect(MushafPalette.phaseForHour(7), DayPhase.fajr);
      expect(MushafPalette.phaseForHour(8), DayPhase.duha);
      expect(MushafPalette.phaseForHour(13), DayPhase.duha);
      expect(MushafPalette.phaseForHour(14), DayPhase.asr);
      expect(MushafPalette.phaseForHour(16), DayPhase.asr);
      expect(MushafPalette.phaseForHour(17), DayPhase.maghrib);
      expect(MushafPalette.phaseForHour(19), DayPhase.maghrib);
      expect(MushafPalette.phaseForHour(20), DayPhase.isha);
      expect(MushafPalette.phaseForHour(23), DayPhase.isha);
    });

    test('covers all 24 hours with a valid phase', () {
      for (var h = 0; h < 24; h++) {
        expect(DayPhase.values, contains(MushafPalette.phaseForHour(h)));
      }
    });
  });

  group('MushafColors extension', () {
    const a = MushafColors(gold: Color(0xFF000000));
    const b = MushafColors(gold: Color(0xFFFFFFFF));

    test('lerp interpolates the gold (and clamps at the ends)', () {
      expect(a.lerp(b, 0).gold, a.gold);
      expect(a.lerp(b, 1).gold, b.gold);
      expect(a.lerp(b, 0.5).gold, Color.lerp(a.gold, b.gold, 0.5));
    });

    test('lerp against a non-MushafColors returns itself', () {
      expect(a.lerp(null, 0.5).gold, a.gold);
    });

    test('copyWith replaces or keeps the gold', () {
      expect(a.copyWith(gold: b.gold).gold, b.gold);
      expect(a.copyWith().gold, a.gold);
    });
  });
}
