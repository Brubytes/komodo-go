#!/usr/bin/env python3
"""Build Codemagic's release_notes.json from the curated release notes.

One source of truth per version:
  release-notes/<version>.md          GitHub release body; also App Store
                                      "What's New" (converted to plain text)
  release-notes/<version>.store.txt   Google Play notes (max 500 characters)
  metadata/version/<version>/en-US.json
                                      optional App Store listing fields
                                      (description, keywords, promotionalText,
                                      marketingUrl, supportUrl)

Usage:
  store_release_notes.py ios <version>        write release_notes.json for iOS
  store_release_notes.py android <version>    write release_notes.json for Play
  store_release_notes.py check <version>      validate both, write nothing

Codemagic picks up release_notes.json from the repository root and publishes
it to TestFlight "What to Test", App Store "What's New" (when submitting for
review) and Google Play.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGUAGE = "en-US"

APP_STORE_WHATS_NEW_LIMIT = 4000
PLAY_LIMIT = 500
APP_STORE_LIMITS = {
    "description": 4000,
    "keywords": 100,
    "promotional_text": 170,
}
# metadata JSON key -> Codemagic release_notes.json key
METADATA_FIELDS = {
    "description": "description",
    "keywords": "keywords",
    "promotionalText": "promotional_text",
    "marketingUrl": "marketing_url",
    "supportUrl": "support_url",
}


class NotesError(Exception):
    pass


def markdown_to_store_text(markdown: str) -> str:
    """Plain text for store fields: headings become labels, bullets become •."""
    lines: list[str] = []
    after_heading = False
    for raw in markdown.strip().splitlines():
        line = raw.rstrip()
        if not line.strip():
            if after_heading:
                continue  # keep a heading directly above its bullets
            if lines and lines[-1] == "":
                continue
            lines.append("")
            continue
        heading = re.match(r"^#{1,6}\s+(.*)$", line)
        if heading:
            line = heading.group(1)
            after_heading = True
        else:
            after_heading = False
            line = re.sub(r"^\s*[-*]\s+", "• ", line)
        line = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)  # links
        line = re.sub(r"(\*\*|__|`)", "", line)  # emphasis, code
        lines.append(line)
    return "\n".join(lines).strip()


def _read(path: Path) -> str:
    if not path.is_file():
        raise NotesError(f"Missing {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise NotesError(f"{path.relative_to(ROOT)} is empty")
    return text


def _check_limit(name: str, text: str, limit: int) -> None:
    if len(text) > limit:
        raise NotesError(f"{name} is {len(text)} characters (limit {limit})")


def ios_entry(version: str) -> dict[str, str]:
    md = _read(ROOT / "release-notes" / f"{version}.md")
    entry = {"language": LANGUAGE, "text": markdown_to_store_text(md)}
    _check_limit("App Store What's New", entry["text"], APP_STORE_WHATS_NEW_LIMIT)

    metadata_path = ROOT / "metadata" / "version" / version / f"{LANGUAGE}.json"
    if metadata_path.is_file():
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        for source, target in METADATA_FIELDS.items():
            value = metadata.get(source)
            if isinstance(value, str) and value.strip():
                entry[target] = value.strip()
        for field, limit in APP_STORE_LIMITS.items():
            if field in entry:
                _check_limit(f"App Store {field}", entry[field], limit)
    return entry


def android_entry(version: str) -> dict[str, str]:
    text = _read(ROOT / "release-notes" / f"{version}.store.txt")
    _check_limit("Google Play release notes", text, PLAY_LIMIT)
    return {"language": LANGUAGE, "text": text}


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in {"ios", "android", "check"}:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    mode, version = argv[1], argv[2].removeprefix("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        print(f"Invalid version '{version}', expected X.Y.Z", file=sys.stderr)
        return 2

    try:
        if mode == "check":
            ios = ios_entry(version)
            android = android_entry(version)
            print(f"App Store What's New: {len(ios['text'])} characters")
            print(f"Google Play notes: {len(android['text'])} characters")
            return 0
        entry = ios_entry(version) if mode == "ios" else android_entry(version)
    except (NotesError, json.JSONDecodeError) as error:
        print(f"Release notes for {version}: {error}", file=sys.stderr)
        return 1

    out = ROOT / "release_notes.json"
    out.write_text(json.dumps([entry], indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {out.relative_to(ROOT)} for {mode} {version}:")
    print(entry["text"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
