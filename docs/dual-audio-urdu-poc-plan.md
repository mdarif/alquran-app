# Dual Audio Urdu Translation POC Plan

Goal: prove a verse-by-verse playback mode where each Arabic ayah is followed
immediately by the matching Urdu audio translation. The production
non-negotiable is that the Urdu audio must match the app's bundled
`ur-junagarhi` text source: Maulana Muhammad Junagarhi.

The POC is intentionally limited to Surah Al-Fatihah before any full Quran
integration.

## Decisions

- POC scope: Surah Al-Fatihah only, 7 ayahs.
- POC UI scope: Detailed view only. Reading mode remains Arabic-recitation only.
- Playback sequence per ayah:
  1. Arabic recitation
  2. Urdu Junagarhi translation audio
- Do not ship or expand beyond Al-Fatihah until the Urdu audio source is
  verified and license-cleared.
- Do not depend on third-party CDNs directly in production. The final app should
  consume an Al Quran owned manifest/CDN after validation.

## Track 1 - Asset Discovery And Verification

### Candidate sources

Investigate and document:

- Darussalam / publisher-authorized source for Muhammad Junagarhi Urdu audio.
- Archive.org mirrors for "Sudais Shuraim Junagarhi Urdu translation".
- EveryAyah-style ayah-split mirrors.
- Community mirrors only as discovery, not as the production source.

Known public references found during research:

- EveryAyah lists ayah-split Urdu audio as `urdu_shamshad_ali_khan_46kbps`,
  using file names like `001001.mp3`.
- myQuran.us displays `Urdu: Muhammad Junagarhi` text, but visible audio links
  are Arabic recitation paths such as `/content/ayah/audio/hudhaify/001001.mp3`;
  do not treat those as Junagarhi translation audio.
- Navedz references the desired pairing: Sudais/Shuraim recitation with
  Muhammad Junagarhi Urdu translation, Darussalam/professional Urdu host, but it
  does not provide a verified ayah-split CDN in the visible page.

### POC asset requirement

For Al-Fatihah, collect seven Urdu audio files:

```text
001001.mp3
001002.mp3
001003.mp3
001004.mp3
001005.mp3
001006.mp3
001007.mp3
```

Each file must be checked against the exact bundled `ur-junagarhi` text for the
same ayah. Manual listening is acceptable for POC. Production requires a written
source + license record.

### Verification checklist

- [ ] Source explicitly identifies Maulana Muhammad Junagarhi.
- [ ] Source terms allow use in a free mobile app, or permission is obtained.
- [ ] Al-Fatihah files are verse-split, not full-surah audio.
- [ ] Each file maps correctly to `SSSAAA.mp3`.
- [ ] Each file audibly matches the bundled Urdu text.
- [ ] Files are non-empty and playable on Android.
- [ ] Record source URL, attribution, license, and reviewer initials/date.

## Track 2 - POC Asset Hosting

Use local assets first to avoid CDN uncertainty during app-level POC:

```text
assets/audio/poc/ur-junagarhi/001001.mp3
assets/audio/poc/ur-junagarhi/001002.mp3
...
assets/audio/poc/ur-junagarhi/001007.mp3
```

Arabic can continue using the existing Arabic recitation source for the POC.

If remote testing is needed, mirror only the seven verified files to a temporary
R2 prefix:

```text
https://audio.alquranreader.com/poc/ur-junagarhi/001001.mp3
```

Do not use the temporary prefix in production code.

## Track 3 - Data Model Shape

No full database migration is needed for the Al-Fatihah POC. Use a small static
manifest in Dart or JSON:

```json
{
  "slug": "ur-junagarhi-poc",
  "textResourceSlug": "ur-junagarhi",
  "languageCode": "ur",
  "source": "POC only",
  "items": [
    {
      "surah": 1,
      "ayah": 1,
      "file": "assets/audio/poc/ur-junagarhi/001001.mp3"
    }
  ]
}
```

Production DB direction after POC:

```sql
CREATE TABLE audio_resources (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  language_code TEXT,
  text_resource_slug TEXT,
  reciter_name TEXT,
  translator_name TEXT,
  voice_name TEXT,
  base_url TEXT NOT NULL,
  local_base_path TEXT,
  naming_scheme TEXT NOT NULL DEFAULT 'SSSAAA',
  file_extension TEXT NOT NULL DEFAULT 'mp3',
  license TEXT,
  source_url TEXT,
  verified INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE ayah_audio (
  ayah_id INTEGER NOT NULL,
  surah_id INTEGER NOT NULL,
  ayah_number INTEGER NOT NULL,
  resource_slug TEXT NOT NULL,
  remote_path TEXT NOT NULL,
  local_path TEXT,
  duration_ms INTEGER,
  bytes INTEGER,
  sha256 TEXT,
  cached INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (ayah_id, resource_slug)
);
```

## Track 4 - Flutter POC Architecture

Create the POC behind a feature flag:

```dart
static const bool dualUrduAudioPoc = false;
```

Add a small POC-only queue builder:

```dart
enum DualAudioSegmentType { arabic, urduTranslation }

class DualAudioSegment {
  const DualAudioSegment({
    required this.ayahId,
    required this.surah,
    required this.ayah,
    required this.type,
    required this.uri,
  });

  final int ayahId;
  final int surah;
  final int ayah;
  final DualAudioSegmentType type;
  final Uri uri;
}
```

POC playback queue:

```text
001001 Arabic
001001 Urdu
001002 Arabic
001002 Urdu
...
001007 Arabic
001007 Urdu
```

Use `just_audio` `ConcatenatingAudioSource` for the POC queue. The current
single-ayah player can remain untouched until the POC proves the UX.

## Track 5 - POC UX

Keep the UI deliberately small:

- Only show the POC control in Surah Al-Fatihah **Detailed view**.
- Do not show dual-audio controls in Reading mode; Reading mode remains focused
  on Arabic-only recitation.
- Label: `Arabic + Urdu audio`.
- Add Play/Pause and Stop.
- Highlight the ayah currently being recited/translated.
- Show a small error state if Urdu audio is missing or fails.
- Do not add download management yet.

Acceptance behavior:

- Tapping Play starts from ayah 1.
- Each Arabic ayah is followed by its Urdu translation.
- Playback continues through all seven ayahs.
- Stop clears highlight.
- If a Urdu file fails, show "Urdu audio unavailable for this ayah" and stop.

## Track 6 - Tests

Unit tests:

- `DualAudioQueueBuilder` creates 14 segments for Al-Fatihah.
- Segment order is Arabic then Urdu for each ayah.
- File naming maps `surah=1, ayah=7` to `001007.mp3`.
- Missing Urdu asset returns a clear POC validation error.

Widget/cubit tests:

- POC control only appears for Surah Al-Fatihah Detailed view when flag is on.
- POC control does not appear in Reading mode.
- Error state is shown when the player reports failure.
- Stop returns the UI to idle.

Manual device test:

- Android release/profile build.
- Wi-Fi on: Arabic existing stream + bundled/local Urdu POC files play.
- Wi-Fi off after first Arabic cached file: expected behavior documented.
- Bluetooth/headphones basic playback check.

## Track 7 - Production Exit Criteria

Do not move from POC to production until:

- [ ] Full 6,236 Urdu Junagarhi ayah files are sourced or legally generated.
- [ ] License/permission is documented.
- [ ] 6,236-file manifest exists with sha256 and duration metadata.
- [ ] Random audit passes at least:
  - Al-Fatihah
  - Ayat al-Kursi
  - last 10 surahs
  - several long Baqarah ayahs
- [ ] Audio CDN/R2 hosting is controlled by Al Quran.
- [ ] Download/cache policy is designed.
- [ ] Background audio behavior is agreed.
- [ ] Failure UX follows `docs/error-handling-runbook.md`.

## Open Questions

- Which Arabic recitation should pair with Junagarhi in this mode:
  existing Alafasy, or the traditional Sudais/Shuraim pairing?
- Should Urdu translation audio be streamed only, downloadable, or bundled as
  optional downloadable packs?
- Should the user be able to choose Arabic-only, Urdu-only, or Arabic+Urdu?
- Should playback stop on missing Urdu audio, or continue Arabic-only with a
  warning? Recommended default: stop, because the feature promise is matching
  dual audio.
- Who signs off that the Urdu audio matches the bundled Junagarhi text?
