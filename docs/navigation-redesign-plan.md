# Mobile Navigation Redesign Plan

**Status:** proposed, next priority  
**Owner ask:** 2026-08-07  
**Roadmap:** top-level navigation clarity before larger feature expansion

## Problem

The app started as a simple offline Quran reader, but it now includes reading
modes, translations, Tafsir, audio, prayer times, reminders, bookmarks, updates,
and content downloads. Many of those features are currently discovered through
the Home overflow menu or secondary settings pages, so readers have to guess
where things live.

Feedback from real users: the application is useful, but navigation is still
hard to figure out.

## Product Goal

Make the app feel simple again by giving users clear top-level destinations:

1. Read the Quran.
2. Check prayer-related information.
3. Manage Quran content such as translations and Tafsir.
4. Find saved items, settings, and app information.

The reader itself should stay immersive. The navigation redesign is for the
top-level app shell, not for turning the reading surface into a busy dashboard.

## Recommended Model

Use a bottom navigation shell with four tabs:

1. **Read**
2. **Prayer**
3. **Library**
4. **More**

Keep the Reader screen outside the tab shell once a Surah/section is opened, so
audio controls, page swipes, immersive chrome hiding, and font controls stay
focused.

## Tab Definitions

### Read

The current Home experience becomes the Read tab.

Primary content:

- Continue reading banner.
- Surah list and Surah-name search.
- Home prayer pill may remain as a lightweight glance.
- Friday shortcut / Juma mode later.
- Advanced navigation entry only if `FeatureFlags.advancedNavigation` is on.

Do not move the full Reader into a tab body. Opening a Surah still navigates to
the existing Reader route.

### Prayer

A dedicated prayer surface, initially reusing existing prayer-time logic.

Phase 1 scope:

- Current/next prayer.
- Today's five prayer times.
- Hijri date.
- Entry point to Reminders.
- Existing location/settings affordance.

Later scope:

- Monthly prayer calendar.
- Per-prayer notification settings and lead time.
- Qibla direction if approved.
- Stronger Light of Day / prayer phase visuals.

### Library

The content-management home for Quran resources.

Phase 1 scope:

- Translations.
- Tafsir.
- Download status hints if already available cheaply.

Later scope:

- Script / Mushaf text packs.
- Audio reciters.
- Urdu translation audio packs.
- Storage/download management.

The goal is discoverability: a reader should not need to know that Tafsir or
Translations are hidden behind the Home overflow.

### More

Secondary app utilities and preferences.

Phase 1 scope:

- Bookmarks.
- Reading theme / appearance.
- Settings.
- Check for Updates.
- About, credits, privacy.

Avoid turning More into the old overflow menu. Anything that is core reading,
prayer, or content management belongs in the first three tabs.

## Current Entry Point Audit

Move or keep as follows:

| Current entry | New home |
| --- | --- |
| Surah list | Read |
| Surah search | Read |
| Continue reading | Read |
| Reader screen | Separate immersive route |
| Page/Juz/Hizb/Ruku jump | Read, behind existing flag |
| Prayer Times sheet | Prayer |
| Reminders | Prayer, with secondary access from More if useful |
| Translations | Library |
| Tafsir | Library |
| Bookmarks | More |
| Reading theme | More, and possibly Reader settings |
| Check for Updates | More / Settings |
| About / credits / privacy | More |

## Implementation Plan

### Phase 0 — Design Decisions

- Confirm final tab names: `Read`, `Prayer`, `Library`, `More`.
- Confirm whether `Bookmarks` belongs in `More` or deserves a Library row.
- Confirm whether the Home prayer pill remains on Read after Prayer tab exists.
- Confirm whether the Home overflow menu disappears or stays with only local
  contextual actions.

### Phase 1 — Shell Without Behavior Changes

- Add a top-level navigation shell.
- Keep existing Home page as the `Read` tab.
- Add placeholder or minimally reused pages for `Prayer`, `Library`, and `More`.
- Preserve all existing routes and deep links.
- Ensure Android back behavior is predictable:
  - Back from Reader returns to the originating tab.
  - Back from nested Library/More pages returns to that tab root.
  - Back from Read root exits as before.

### Phase 2 — Library Tab

- Move Translations and Tafsir discovery into Library.
- Keep existing Translations/Tafsir screens intact.
- Add simple descriptions and status hints:
  - "Manage translations"
  - "Read Tafsir"
  - "On device" / "Available" counts only if cheap and reliable.
- Remove Translations/Tafsir from the Home overflow after Library is live.

### Phase 3 — More Tab

- Move Bookmarks, Reading Theme, Settings, Updates, About/Credits/Privacy into
  More.
- Keep Settings for true configuration, not as a feature index.
- Simplify the old Home overflow.

### Phase 4 — Prayer Tab

- Promote today's Prayer Times sheet into a full page.
- Link Reminders from this tab.
- Keep existing scheduling/permission behavior unchanged.
- Do not add qibla/monthly calendar in this pass.

### Phase 5 — Polish And Usability Check

- Run a small task test with 3-5 people:
  - Find Tafsir.
  - Change translation.
  - Check prayer time.
  - Find bookmarks.
  - Check for updates.
  - Return to the last read verse.
- If people hesitate, fix labels or placement before adding more features.

## Technical Notes

- Prefer a single `Scaffold` shell for top-level tabs.
- Keep Reader as a pushed route outside the tab scaffold.
- Keep feature modules intact; do not merge feature ownership just because the
  navigation changes.
- Use existing Cubits and repositories. This is navigation/UI composition work,
  not a data-layer rewrite.
- Keep `FeatureFlags` behavior intact.
- Avoid adding new business logic to the shell.

## Test Plan

- Widget tests for tab switching.
- Widget tests that Library opens Translations and Tafsir.
- Widget tests that More opens Bookmarks, Settings, About, and update check.
- Widget tests that Prayer renders existing prayer-time content when permissions
  and location state are available.
- Navigation tests:
  - Open Surah from Read, back returns to Read tab.
  - Open Tafsir from Library, back returns to Library tab.
  - Switch tabs and preserve each tab's root state.
- Golden/screenshot check on small Android viewport to confirm labels fit.

## Acceptance Criteria

- A new user can identify where to read, pray, manage content, and find settings
  without opening an overflow menu.
- Tafsir and Translations are visible from a top-level tab.
- Reader remains immersive and unchanged in feel.
- Existing tests continue to pass.
- No shipped feature becomes harder to reach than before.

## Non-goals

- No visual redesign of the Reader page in this pass.
- No qibla/monthly prayer calendar yet.
- No background audio work in this pass.
- No new downloadable content pipeline work in this pass.
- No tablet-specific navigation redesign yet.
