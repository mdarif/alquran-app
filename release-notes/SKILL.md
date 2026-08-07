---
name: release-notes
description: Draft Al Quran release notes from the app repo and companion alquran-data repo. Use when preparing a release cycle, writing App Store / Play Store notes, counting exact changes since the last release, or summarizing combined app and data-pipeline changes in the required locale wrapper format.
---

# Release Notes

## Overview

Prepare short, user-facing release notes for Al Quran by inspecting both repositories:
the current app repo and `/Users/mohammadarif/code/alquran-data`.
The release pipeline automates this with `tool/generate_reader_release_notes.py`.

## Workflow

1. Check both worktrees before doing anything else:
   - App repo: `git status --short`
   - Data repo: `git -C /Users/mohammadarif/code/alquran-data status --short`
   - Never overwrite or revert unrelated local changes.

2. Find the last release anchor in the app repo:
   - For App Store / Play Store notes, prefer the newest semantic version tag reachable from `HEAD`; this is the public release baseline.
   - If there is no release tag, use the newest `chore: release vX.Y.Z` commit on the current branch.
   - Record the anchor commit, version, timestamp, and subject.
   - If tags and release commits disagree, state the discrepancy. Use the newest tag for public release notes unless the user asks for internal/unreleased-only deltas.

3. Count exact app changes:
   - Run `git rev-list --count <release-anchor>..HEAD`.
   - Read `git log --oneline --reverse <release-anchor>..HEAD`.
   - Group the commits into user-facing themes and keep internal-only chores out of the final notes unless they affect release quality.

4. Count exact data repo changes:
   - If `/Users/mohammadarif/code/alquran-data` has release tags or release commits, use its newest release anchor.
   - If it has no release anchor, use the app release anchor timestamp and count data commits after that moment with `git log --since='<timestamp>'`.
   - Read the data commit list and include only user-visible data, catalogue, content, or reliability changes in the final notes.

5. Write the release notes:
   - Prefer running `python3 tool/generate_reader_release_notes.py` when the user wants the pipeline-compatible output.
   - Always include the required wrapper:

```text
<en-US>
...
</en-US>
```

   - Keep the copy concise, polished, and suitable for users.
   - Avoid commit hashes in the notes block unless the user explicitly asks.
   - Mention exact change counts outside the notes block or in a short lead-in when the user asks to verify them.

## Current Product Voice

Use calm, clear release language. Prefer plain verbs such as:
`Added`, `Improved`, `Fixed`, `Polished`, `Updated`.

For Al Quran, emphasize reading reliability, offline content, translations, Tafsir,
prayer-time notifications, and release readiness. Do not overstate features that are
flagged off or only present in pipeline tooling.

## Useful Commands

```bash
git log --oneline --decorate -n 30
git log --format='%h %ci %s' --reverse <anchor>..HEAD
git rev-list --count <anchor>..HEAD

git -C /Users/mohammadarif/code/alquran-data log --format='%h %ci %s' --reverse --since='<release timestamp>'
git -C /Users/mohammadarif/code/alquran-data rev-list --count --since='<release timestamp>' HEAD
```
