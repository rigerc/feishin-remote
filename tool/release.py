#!/usr/bin/env python3
"""Validate a release and write its metadata and notes."""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VERSION = r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
# Published before this tooling existed. Both tags carry 0.1.0+1 in pubspec.yaml
# because their build number came from the workflow run number (1 and 2).
LEGACY_TAGS = {"v0.1.0": 1, "v0.1.1": 2}


def git(*args):
    return subprocess.check_output(["git", *args], text=True, cwd=ROOT).strip()


def read_version(pubspec):
    match = re.search(rf"^version:\s*({VERSION})\+([1-9]\d*)\s*$", pubspec, re.M)
    if not match:
        raise SystemExit("Use version: X.Y.Z+N with a positive Android build number.")
    version = match[1]
    build = int(match[5])
    if build > 2_100_000_000:
        raise SystemExit("Android build number exceeds the Google Play versionCode limit.")
    return version, build


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Require this tag to point to the checked-out commit")
    parser.add_argument("--output", default="dist/release")
    args = parser.parse_args()
    version, build = read_version((ROOT / "pubspec.yaml").read_text())
    tag = f"v{version}"
    revision = git("rev-parse", "HEAD")
    if args.tag and (
        args.tag != tag or git("rev-parse", f"refs/tags/{tag}^{{commit}}") != revision
    ):
        raise SystemExit(f"The checkout and release tag must match {tag}.")

    for previous in git("tag", "--list", "v*").splitlines():
        if previous == tag or not re.fullmatch(rf"v{VERSION}", previous):
            continue
        if previous in LEGACY_TAGS:
            previous_version, previous_build = previous[1:], LEGACY_TAGS[previous]
        else:
            previous_version, previous_build = read_version(git("show", f"{previous}:pubspec.yaml"))
            if f"v{previous_version}" != previous:
                raise SystemExit(f"Tag {previous} disagrees with its pubspec.")
        previous_is_older = tuple(map(int, previous_version.split("."))) < tuple(map(int, version.split(".")))
        if previous_build == build or (previous_build < build) != previous_is_older:
            raise SystemExit(f"Build number {build} is out of sequence with {previous} ({previous_build}).")

    changelog = (ROOT / "CHANGELOG.md").read_text()
    section = re.search(rf"^## {re.escape(version)}[^\S\n]*\n(.*?)(?=^## |\Z)", changelog, re.M | re.S)
    if not section or not section[1].strip():
        raise SystemExit(f"Add a nonempty '## {version}' entry to CHANGELOG.md.")

    project = json.loads((ROOT / "project.json").read_text())
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    (output / "RELEASE_NOTES.md").write_text(section[1].strip() + "\n")
    metadata = {
        "tag": tag,
        "version": version,
        "build": build,
        "applicationId": project["applicationId"],
        "commit": revision,
    }
    (output / "release.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"{tag} build {build} at {revision}")


if __name__ == "__main__":
    main()
