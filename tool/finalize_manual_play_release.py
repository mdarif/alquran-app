#!/usr/bin/env python3
"""Finalize repo + update metadata after a manual Play Console release."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


def run(args: list[str], *, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(args))
    return subprocess.run(args, cwd=cwd, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def output(args: list[str], *, cwd: Path) -> str:
    return run(args, cwd=cwd).stdout.strip()


def require_clean(repo: Path) -> None:
    status = output(["git", "status", "--short"], cwd=repo)
    if status:
        raise SystemExit(f"Working tree is not clean:\n{status}")


def update_pubspec(pubspec: Path, version: str, build_number: int) -> None:
    text = pubspec.read_text()
    next_text, count = re.subn(
        r"^version:\s+\d+\.\d+\.\d+\+\d+\s*$",
        f"version: {version}+{build_number}",
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit(f"Could not update version in {pubspec}")
    pubspec.write_text(next_text)


def verify_update_json(path: Path, version: str) -> None:
    data = json.loads(path.read_text())
    if data.get("latestVersion") != version:
        raise SystemExit(f"{path} latestVersion is {data.get('latestVersion')}, expected {version}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="Semver released on Play, for example 1.2.6")
    parser.add_argument("--build-number", required=True, type=int, help="Android versionCode released on Play")
    parser.add_argument("--aab", type=Path, help="Manual AAB to attach to the GitHub Release")
    parser.add_argument("--data-repo", type=Path, default=Path("../alquran-data"))
    parser.add_argument("--r2-bucket", default="al-quran-editions")
    parser.add_argument("--public-update-url", default="https://alquranreader.com/app-update.json")
    parser.add_argument("--skip-r2", action="store_true")
    parser.add_argument("--skip-github-release", action="store_true")
    parser.add_argument("--skip-push", action="store_true")
    args = parser.parse_args()

    repo = Path.cwd()
    tag = f"v{args.version}"
    app_update = repo / "app-update.json"
    play_notes = repo / "play-store-notes.txt"
    release_metadata = repo / "release-note-metadata.txt"

    require_clean(repo)
    run(["git", "fetch", "origin", "--tags"], cwd=repo)
    if output(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo) != "develop":
        raise SystemExit("Run this from the develop branch.")
    if run(["git", "rev-parse", f"refs/tags/{tag}"], cwd=repo, check=False).returncode == 0:
        raise SystemExit(f"Tag {tag} already exists.")
    if args.aab and not args.aab.exists():
        raise SystemExit(f"AAB not found: {args.aab}")

    update_pubspec(repo / "pubspec.yaml", args.version, args.build_number)
    run(
        [
            "dart",
            "run",
            "tool/generate_app_update_config.dart",
            f"--latest-version={args.version}",
            "--minimum-supported-version=1.0.0",
            "--remind-after-days=7",
            f"--output={app_update}",
        ],
        cwd=repo,
    )
    verify_update_json(app_update, args.version)

    run(
        [
            "python3",
            "tool/generate_reader_release_notes.py",
            "--app-repo",
            str(repo),
            "--data-repo",
            str(args.data_repo),
            "--output",
            str(play_notes),
            "--metadata-output",
            str(release_metadata),
        ],
        cwd=repo,
    )

    if not args.skip_r2:
        run(
            [
                "npx",
                "wrangler",
                "r2",
                "object",
                "put",
                f"{args.r2_bucket}/app-update.json",
                "--file",
                str(app_update),
                "--content-type",
                "application/json",
                "--cache-control",
                "public, max-age=300",
                "--remote",
            ],
            cwd=repo,
        )
        live = run(["curl", "-fsSL", f"{args.public_update_url}?cachebust={tag}"], cwd=repo, check=False)
        if live.returncode == 0:
            live_json = json.loads(live.stdout)
            if live_json.get("latestVersion") != args.version:
                raise SystemExit(f"Live app-update.json latestVersion is {live_json.get('latestVersion')}")
            print(f"Verified live app-update.json advertises {args.version}.")
        else:
            print(
                "::warning::R2 object uploaded, but the public app-update URL did not verify. "
                "Check/deploy infra/app-update-worker before relying on the in-app banner."
            )

    run(["git", "add", "pubspec.yaml"], cwd=repo)
    run(["git", "commit", "-m", f"chore: release {tag}"], cwd=repo)
    run(["git", "tag", tag, "-m", f"Release {tag}"], cwd=repo)

    if not args.skip_push:
        run(["git", "push", "origin", "HEAD:develop", "HEAD:main", tag], cwd=repo)

    if not args.skip_github_release:
        release_notes = repo / "manual-release-notes.md"
        release_notes.write_text(
            "\n".join(
                [
                    "## What's changed",
                    "",
                    play_notes.read_text().strip(),
                    "",
                    "---",
                    f"**Build:** `{args.version}+{args.build_number}`",
                    "**Play upload:** completed manually in Play Console.",
                    "**Soft-update config:** generated by manual release finalizer.",
                    "",
                ]
            )
        )
        gh_args = [
            "gh",
            "release",
            "create",
            tag,
            f"{app_update}#Soft update config",
            f"{play_notes}#Play Store release notes",
            f"{release_metadata}#Release note source metadata",
            "--title",
            f"Al Quran {tag}",
            "--notes-file",
            str(release_notes),
        ]
        if args.aab:
            gh_args.insert(4, f"{args.aab}#Al Quran Android App Bundle (manual Play upload)")
        run(gh_args, cwd=repo)
        release_notes.unlink(missing_ok=True)

    app_update.unlink(missing_ok=True)
    play_notes.unlink(missing_ok=True)
    release_metadata.unlink(missing_ok=True)
    print(f"Manual release finalization complete for {args.version}+{args.build_number}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
