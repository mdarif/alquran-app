#!/usr/bin/env python3
"""Generate reader-friendly Play Store notes from app + data git history."""

from __future__ import annotations

import argparse
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


MAX_PLAY_CHARS = 500


@dataclass(frozen=True)
class Commit:
    subject: str


@dataclass(frozen=True)
class Theme:
    key: str
    text: str
    patterns: tuple[str, ...]


THEMES: tuple[Theme, ...] = (
    Theme(
        "tafsir",
        "New: Read Tafsir in the app, starting with Urdu Ibn Kathir.",
        ("tafsir", "ibn kathir"),
    ),
    Theme(
        "prayer",
        "Prayer Times are easier to follow with a clearer countdown, better reminders, and notification sound check.",
        ("prayer", "salat", "notification", "reminder", "forbidden-window", "nafl"),
    ),
    Theme(
        "translations",
        "Translations are easier to manage, with improved language choices and clearer sharing text.",
        ("translation", "translations", "roman urdu", "locale", "credit", "translator", "edition", "licensing"),
    ),
    Theme(
        "reader",
        "Reading feels smoother, with faster performance and helpful Surah meanings in the reader.",
        ("reader", "surah", "fullscreen", "copy/share", "performance", "physical devices"),
    ),
    Theme(
        "offline",
        "Offline content is cleaner and lighter, so updates stay reliable.",
        ("lean", "seed", "catalogue", "catalog", "artifact", "r2", "data", "publish"),
    ),
    Theme(
        "reliability",
        "We fixed issues and polished the app to make daily reading more reliable.",
        ("fix", "harden", "reliability", "regression", "polish", "empty state", "spacing"),
    ),
)


def run_git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ("git", "-C", str(repo), *args),
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def latest_tag(repo: Path) -> str:
    return run_git(repo, "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")


def tag_timestamp(repo: Path, tag: str) -> str:
    return run_git(repo, "log", "-1", "--format=%cI", tag)


def commits_since_ref(repo: Path, ref: str) -> list[Commit]:
    output = run_git(repo, "log", "--format=%s", "--reverse", f"{ref}..HEAD")
    return [Commit(line) for line in output.splitlines() if line.strip()]


def commits_since_time(repo: Path, timestamp: str) -> list[Commit]:
    output = run_git(repo, "log", "--format=%s", "--reverse", f"--since={timestamp}", "HEAD")
    return [Commit(line) for line in output.splitlines() if line.strip()]


def count_since_ref(repo: Path, ref: str) -> int:
    return int(run_git(repo, "rev-list", "--count", f"{ref}..HEAD") or "0")


def count_since_time(repo: Path, timestamp: str) -> int:
    return int(run_git(repo, "rev-list", "--count", f"--since={timestamp}", "HEAD") or "0")


def matching_themes(commits: list[Commit]) -> list[Theme]:
    haystack = "\n".join(commit.subject.lower() for commit in commits)
    selected: list[Theme] = []
    for theme in THEMES:
        if any(re.search(pattern, haystack, flags=re.IGNORECASE) for pattern in theme.patterns):
            selected.append(theme)
    return selected


def fit_for_play(lines: list[str]) -> str:
    selected: list[str] = []
    for line in lines:
        candidate = "\n\n".join([*selected, line])
        if len(candidate) <= MAX_PLAY_CHARS:
            selected.append(line)
    if not selected:
        return "We fixed issues and polished the app to make daily reading more reliable."
    return "\n\n".join(selected)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-repo", default=".", type=Path)
    parser.add_argument("--data-repo", default="../alquran-data", type=Path)
    parser.add_argument("--output", default="play-store-notes.txt", type=Path)
    parser.add_argument("--metadata-output", default="release-note-metadata.txt", type=Path)
    args = parser.parse_args()

    app_repo = args.app_repo.resolve()
    data_repo = args.data_repo.resolve()

    tag = latest_tag(app_repo)
    timestamp = tag_timestamp(app_repo, tag)
    app_commits = commits_since_ref(app_repo, tag)
    data_commits = commits_since_time(data_repo, timestamp)
    themes = matching_themes([*app_commits, *data_commits])

    note_lines = [theme.text for theme in themes]
    if not note_lines:
        note_lines = ["We fixed issues and polished the app to make daily reading more reliable."]

    notes = fit_for_play(note_lines)
    args.output.write_text(notes + "\n", encoding="utf-8")

    metadata = "\n".join(
        (
            f"release_anchor={tag}",
            f"release_anchor_timestamp={timestamp}",
            f"app_commit_count={count_since_ref(app_repo, tag)}",
            f"data_commit_count={count_since_time(data_repo, timestamp)}",
            f"selected_themes={','.join(theme.key for theme in themes) or 'maintenance'}",
            f"play_store_note_chars={len(notes)}",
        )
    )
    args.metadata_output.write_text(metadata + "\n", encoding="utf-8")
    print(notes)
    print()
    print(metadata)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
