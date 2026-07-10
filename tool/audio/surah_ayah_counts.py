"""Per-surah ayah counts for the standard Hafs mushaf — 114 surahs, 6236 ayahs.

Exported from the Al Quran app's bundled `assets/db/quran.db` so the audio index
lines up 1:1 with the **global ayah id** the app requests. The app addresses each
verse by a running 1..6236 index where Al-Fatihah 1:1 = 1 and Al-Baqarah 2:1 = 8
(the 7 verses of Al-Fatihah precede it; Bismillah is NOT counted separately).

This module is the single source of truth for the `SSSAAA -> globalId` rename that
turns everyayah.com's per-surah numbering into the app's global numbering.
"""

# Index 0 = surah 1. Sum == 6236 (asserted below).
AYAH_COUNTS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,   # 1..10
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,     # 11..20
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,        # 21..30
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,          # 31..40
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,           # 41..50
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,           # 51..60
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,           # 61..70
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,           # 71..80
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,           # 81..90
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,                # 91..100
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,                    # 101..110
    5, 4, 5, 6,                                       # 111..114
]

assert len(AYAH_COUNTS) == 114, f"expected 114 surahs, got {len(AYAH_COUNTS)}"
assert sum(AYAH_COUNTS) == 6236, f"expected 6236 ayahs, got {sum(AYAH_COUNTS)}"

# 0-based running offset: _OFFSET[s-1] == (global id of surah s, ayah 1) - 1.
_OFFSET = []
_acc = 0
for _c in AYAH_COUNTS:
    _OFFSET.append(_acc)
    _acc += _c


def global_id(surah: int, ayah: int) -> int:
    """1-based global ayah id (1..6236) for `surah` (1..114) and `ayah`."""
    if not 1 <= surah <= 114:
        raise ValueError(f"surah out of range: {surah}")
    count = AYAH_COUNTS[surah - 1]
    if not 1 <= ayah <= count:
        raise ValueError(f"ayah {ayah} out of range for surah {surah} (1..{count})")
    return _OFFSET[surah - 1] + ayah


def surah_ayah(gid: int) -> tuple[int, int]:
    """Inverse of `global_id`: (surah, ayah) for a global id 1..6236."""
    if not 1 <= gid <= 6236:
        raise ValueError(f"global id out of range: {gid}")
    for s in range(114, 0, -1):
        start = _OFFSET[s - 1]
        if start < gid <= start + AYAH_COUNTS[s - 1]:
            return s, gid - start
    raise AssertionError("unreachable")  # pragma: no cover


def all_pairs():
    """Yield (surah, ayah, global_id) for every verse, in order."""
    for s in range(1, 115):
        for a in range(1, AYAH_COUNTS[s - 1] + 1):
            yield s, a, global_id(s, a)


if __name__ == "__main__":
    # Numbering canary — must match the app's DB (see test/core/audio in the app).
    assert global_id(1, 1) == 1, "Fatiha 1:1 must be global id 1"
    assert global_id(2, 1) == 8, "Baqarah 2:1 must be global id 8"
    assert global_id(114, 6) == 6236, "An-Nas 114:6 must be global id 6236"
    assert surah_ayah(8) == (2, 1)
    assert surah_ayah(6236) == (114, 6)
    assert len(list(all_pairs())) == 6236
    print("surah_ayah_counts OK — 114 surahs, 6236 ayahs, canary 2:1 -> 8")
