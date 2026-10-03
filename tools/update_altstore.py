#!/usr/bin/env python3
"""Prepend a release to the AltStore source manifest.

AltStore reads update candidates from `versions[0]`, so a newly published build
has to be *prepended*, not appended. This is run by the release workflow with
the metadata read out of the IPA that was just built, so `version`,
`buildVersion` and `size` always describe the actual attached asset.
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path


def build_entry(args: argparse.Namespace) -> dict:
    return {
        "version": args.version,
        "buildVersion": args.build,
        "date": datetime.datetime.now(datetime.timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        ),
        "localizedDescription": args.notes,
        "size": args.size,
        "minOSVersion": args.min_os_version,
        "downloadURL": args.download_url,
    }


def update(manifest: dict, entry: dict) -> dict:
    if not manifest.get("apps"):
        raise ValueError("manifest has no apps to update")

    for app in manifest["apps"]:
        versions = [
            existing
            for existing in app.get("versions", [])
            # Drop any previous entry for this exact build so re-running a
            # release job is idempotent instead of stacking duplicates.
            if not (
                existing.get("version") == entry["version"]
                and str(existing.get("buildVersion")) == str(entry["buildVersion"])
            )
        ]
        versions.insert(0, entry)
        app["versions"] = versions

    return manifest


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, default=Path("altstore.json"))
    parser.add_argument("--version", required=True, help="CFBundleShortVersionString")
    parser.add_argument("--build", required=True, help="CFBundleVersion")
    parser.add_argument("--size", required=True, type=int, help="IPA size in bytes")
    parser.add_argument("--min-os-version", required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--notes", default="")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    manifest = json.loads(args.file.read_text(encoding="utf-8"))
    update(manifest, build_entry(args))
    args.file.write_text(
        json.dumps(manifest, indent=4) + "\n", encoding="utf-8"
    )

    print(
        f"Updated {args.file}: {args.version} ({args.build}), "
        f"{args.size} bytes at versions[0]"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
