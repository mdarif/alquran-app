import 'package:al_quran/core/audio/recitation_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alafasyUrl', () {
    test('builds the islamic.network 128kbps Alafasy URL from a global id', () {
      expect(
        alafasyUrl(1),
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3',
      );
    });

    // Numbering canary. The global 1..6236 id must line up with the CDN's index,
    // which counts Bismillah as Al-Fatihah 1:1 (id 1) and NOT as a separate ayah
    // for the other surahs. So Al-Baqarah 2:1 ("Alif-Lam-Meem") is global id 8 —
    // the 7 verses of Al-Fatihah precede it. If our DB ever renumbers (e.g. starts
    // counting Bismillah per surah), every verse would play the WRONG recitation;
    // this pins the mapping so that regression trips here, and the on-device check
    // (hear "Alif-Lam-Meem" on 2:1) confirms the audio content itself.
    test('global id 8 -> the 2:1 audio file (Bismillah-alignment canary)', () {
      expect(
        alafasyUrl(8),
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/8.mp3',
      );
    });
  });

  test('recitationCacheRelativePath namespaces by reciter + bitrate', () {
    expect(recitationCacheRelativePath(1), 'recitation/alafasy_128/1.mp3');
    expect(recitationCacheRelativePath(8), 'recitation/alafasy_128/8.mp3');
  });
}
