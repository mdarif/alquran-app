# Read Quick Navigation Plan

**Status:** implemented  
**Owner ask:** 2026-08-07  
**Scope:** Read tab only, no Reader redesign  
**Related plan:** [`navigation-redesign-plan.md`](navigation-redesign-plan.md)

## Problem

The Read screen is clean but too Surah-list-first. Readers who naturally read by
Juz or Mushaf page have to discover a hidden app-bar "Jump to" control behind
`FeatureFlags.advancedNavigation`. User feedback suggests navigation is still
hard to discover.

The app already has the data and implementation needed for Juz/Page navigation,
so the quick win is to promote the most important entry points into the visible
Read screen.

## Existing Data And Code

The bundled `assets/db/quran.db` already carries complete index data:

- Pages: 1-604
- Juz: 1-30
- Hizb: 1-60
- Ruku: 1-558
- No null index values in `ayahs.page_number`, `juz_number`, `hizb_number`, or
  `ruku_number`.

Existing app code already supports these paths:

- `ReaderTarget.juz(n)`
- `ReaderTarget.page(n)`
- `ReaderTarget.hizb(n)`
- `ReaderTarget.ruku(n)`
- `IndexKind` enum: `juz`, `hizb`, `page`, `ruku`
- `IndexListPage`
- `IndexListView`
- `IndexRepository`
- `IndexListCubit`

Do not create a second data/query path for this feature. Reuse the existing
navigation/index stack.

## Product Decision

Add a compact in-place reading-mode switcher below Continue Reading on the Read tab.

Initial visible choices:

1. **Surah**
2. **Juz**
3. **Page**

Do not show Hizb or Ruku in the first slice. They are valid data dimensions but
less common for everyday readers and will make the Read screen feel busy again.
They can remain hidden or be revisited later.

## Target Read Layout

```text
Al Quran                         Prayer pill  Search
23 Safar 1448 AH

Continue Reading  Al-An'am · Ayah 1

[Surah] [Juz] [Page]

Surah list by default
1 Al-Fatihah
2 Al-Baqarah
...
```

## UX Behavior

### Surah

- Surah is the default reading mode.
- Tapping **Surah** updates the current Read view to show the existing Surah
  list.
- Surah appears selected by default.
- No navigation push is needed.

### Juz

- Tapping **Juz** updates the current Read view in place to show the Juz index
  list.
- Do **not** push a new `IndexListPage` when the top-level Juz pill is tapped.
- Selecting a Juz opens the existing Reader route with:
  `ReaderTarget.juz(number)`.

### Page

- Tapping **Page** updates the current Read view in place to show the Page index
  list.
- Do **not** push a new `IndexListPage` when the top-level Page pill is tapped.
- Selecting a page opens the existing Reader route with:
  `ReaderTarget.page(number)`.

### Search

- Existing Surah search remains in the top app bar.
- This feature does not add Juz/Page search yet.
- Future improvement: index screen local search or fast number jump.

## App-Bar Jump Button Decision

Current Home/Read code has an app-bar Jump icon when
`FeatureFlags.advancedNavigation` is enabled. That button opens a bottom sheet
with Page/Juz/Hizb/Ruku.

Once the Surah/Juz/Page switcher is visible, do not keep a duplicate Jump button for the
same primary choices. The visible body row should become the discoverable entry
point.

Implementation options:

1. **Preferred for this slice:** hide/remove the app-bar Jump icon from the Read
   tab after the Surah/Juz/Page switcher is added.
2. Keep the old `_openJumpSheet` code temporarily if tests or future Hizb/Ruku
   work still reference it, but it should not be surfaced in the app bar.
3. If product later wants Hizb/Ruku, add them deliberately as a secondary
   "More reading options" affordance, not by restoring a competing top-right
   Jump icon.

This does **not** mean removing Juz/Page navigation. It means replacing a hidden
top-right shortcut with a visible Read-screen entry point.

## UI Guidance

Keep this compact. The Read screen should remain calm and reading-first.

Suggested visual treatment:

- No section label. Do not show `Start Reading`.
- Three small, compact Material 3 segmented pills or choice chips.
- Reduce pill height and horizontal padding compared with the current large
  bottom-nav selected pill style. These should feel like filters, not cards.
- Use icons where existing `AppIcons` supports them:
  - Surah: book/reading icon
  - Juz: existing `AppIcons.juz`
  - Page: existing `AppIcons.page`
- Avoid tall cards and decorative banners.
- Keep spacing tighter than the Continue Reading banner.
- Ensure labels fit on small Android screens.

Suggested row shape:

```text
[ Surah ] [ Juz ] [ Page ]
```

## Implementation Steps

1. Add a small widget for the Surah/Juz/Page switcher.
   - Suggested location:
     `lib/features/navigation/presentation/widgets/start_reading_row.dart`
   - Keep it presentation-only.
   - Constructor should accept `selectedMode`, `onSurah`, `onJuz`, and `onPage`
     callbacks if that makes tests simpler.

2. Insert the switcher in `HomePage`.
   - Position: below `LastReadBanner`, above `SurahListBody`.
   - Keep the switched content below it as the main expanded content.

3. Add local Read mode state.
   - Suggested enum: `enum ReadMode { surah, juz, page }`
   - Default: `ReadMode.surah`.
   - Switching modes should update the body in place.

4. Render the body by selected mode.
   - `ReadMode.surah` -> existing `SurahListBody`.
   - `ReadMode.juz` -> existing `IndexListView(kind: IndexKind.juz)`.
   - `ReadMode.page` -> existing `IndexListView(kind: IndexKind.page)`.
   - Reuse `IndexListView` directly rather than pushing `IndexListPage`.

5. Preserve reader navigation on list rows.
   - Tapping a Surah row opens existing `ReaderTarget.surah(...)`.
   - Tapping a Juz row opens existing `ReaderTarget.juz(number)`.
   - Tapping a Page row opens existing `ReaderTarget.page(number)`.

6. Remove the visible app-bar Jump icon from `HomePage`.
   - Do not delete index-list code.
   - Do not delete `IndexListPage`, `IndexListView`, `IndexRepository`, or tests.
   - Update affected tests that currently expect the app-bar Jump sheet.

7. Keep `FeatureFlags.advancedNavigation` behavior sane.
   - Juz and Page are now product-approved visible entry points.
   - Decide whether they should be visible regardless of `advancedNavigation`.
   - Recommended: show Surah/Juz/Page row unconditionally, because Juz is now a
     core Read requirement.
   - Keep Hizb/Ruku gated for future advanced use.

8. Update docs after implementation.
   - Product backlog should no longer say Juz/Page are only hidden behind the old
     Jump sheet once the feature ships.
   - Navigation plan should mention the Surah/Juz/Page switcher under Read.

## Test Plan

Update or add widget tests:

- Read screen shows `Surah`, `Juz`, and `Page`.
- Read screen does not show a `Start Reading` label.
- Tapping `Juz` updates the current Read body to the Juz list without pushing a
  new screen.
- Tapping `Page` updates the current Read body to the Page list without pushing a
  new screen.
- Tapping a Juz row opens `ReaderPage` with a Juz target.
- Tapping a Page row opens `ReaderPage` with a Page target.
- The old app-bar Jump button is not visible in the Read screen.
- Surah search still works.
- Continue Reading still appears above the Surah/Juz/Page switcher.

Existing tests likely needing updates:

- `test/features/navigation/home_page_test.dart`
  - Replace expectations around "Jump-to sheet offers Page/Juz/Hizb/Ruku".
  - Assert Juz/Page switch the current body in place.
- `test/features/navigation/index_list_view_test.dart`
  - Should remain valid.
- `test/features/navigation/index_repository_impl_test.dart`
  - Should remain valid.

## Acceptance Criteria

- Read screen visibly offers compact Surah/Juz/Page pills without a section label, overflow, or app-bar Jump sheet.
- Juz/Page selection updates the current Read body in place.
- Juz navigation works end-to-end using existing DB/index code.
- Page navigation works end-to-end using existing DB/index code.
- Reader remains an immersive pushed route.
- Home/Read top bar is simpler after removing the Jump icon.
- No Hizb/Ruku UI is introduced in the first slice.
- Existing tests are updated and passing.

## Non-goals

- No redesign of the Reader page.
- No Mushaf exact-page rendering.
- No Juz/Page search in this slice.
- No Hizb/Ruku visible UI in this slice.
- No changes to `quran.db`.
- No new data pipeline work.
