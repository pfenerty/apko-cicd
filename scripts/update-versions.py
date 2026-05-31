#!/usr/bin/env python3
"""
Update apko YAML version pins, OCI version annotations, and Makefile image tags
based on generated apko lock files.

Reads every *.lock.json found under the repo, derives the corresponding .yaml,
and updates any =~X.Y.Z pins (three-component versions only) whose resolved
version has changed. Major-only (=~22) and major.minor-only (=~1.22) pins are
intentionally left alone — they are range constraints, not point pins.
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MAKEFILE = REPO / "Makefile"


def strip_wolfi_suffix(version: str) -> str:
    """0.110.0-r2 -> 0.110.0"""
    return re.sub(r"-r\d+$", "", version)


def lock_version(lock_path: Path, pkg_name: str) -> str | None:
    """Return the upstream version of pkg_name from a lock file (x86_64)."""
    data = json.loads(lock_path.read_text())
    for pkg in data["contents"]["packages"]:
        if pkg["name"] == pkg_name and pkg["architecture"] == "x86_64":
            return strip_wolfi_suffix(pkg["version"])
    return None


def update_yaml(yaml_path: Path, lock_path: Path) -> dict[str, tuple[str, str]]:
    """
    Update =~X.Y.Z pins in yaml_path from lock_path.
    Also updates the org.opencontainers.image.version annotation when the
    annotation value exactly matches the old pin version.
    Returns {pkg_name: (old_ver, new_ver)} for each changed package.
    """
    content = yaml_path.read_text()
    changes: dict[str, tuple[str, str]] = {}

    def replace(m: re.Match) -> str:
        prefix = m.group(1)    # "- grype=~"
        pkg_name = m.group(2)  # "grype"
        old_ver = m.group(3)   # "0.110.0"
        new_ver = lock_version(lock_path, pkg_name)
        if new_ver and new_ver != old_ver:
            changes[pkg_name] = (old_ver, new_ver)
            return f"{prefix}{new_ver}"
        return m.group(0)

    new_content = re.sub(r"(- ([\w-]+)=~)(\d+\.\d+\.\d+\S*)", replace, content)

    for _pkg, (old_ver, new_ver) in changes.items():
        new_content = new_content.replace(
            f"org.opencontainers.image.version: {old_ver}",
            f"org.opencontainers.image.version: {new_ver}",
        )

    if new_content != content:
        yaml_path.write_text(new_content)

    return changes


def update_makefile(yaml_path: Path, changes: dict[str, tuple[str, str]]) -> None:
    """
    Update the IMAGE() call(s) in the Makefile for the given yaml config.
    Handles simple tags (grype:0.110.0) and compound tags (golangci-lint:2.11.4-go1.22).
    """
    if not changes:
        return

    content = MAKEFILE.read_text()
    new_content = content
    config_rel = str(yaml_path.relative_to(REPO))

    for _pkg, (old_ver, new_ver) in changes.items():
        # Matches: call IMAGE,<target>,<config>,<image-name>:<old_ver><optional-suffix>)
        # The optional suffix handles the -go1.22 part of golangci-lint tags.
        pattern = (
            rf"(call IMAGE,[^,]+,{re.escape(config_rel)},[^:]+:)"
            rf"{re.escape(old_ver)}"
            rf"((?:-go[\d.]+)?)\)"
        )
        new_content = re.sub(pattern, rf"\g<1>{new_ver}\2)", new_content)

    if new_content != content:
        MAKEFILE.write_text(new_content)


def main() -> int:
    lock_files = sorted(REPO.glob("**/*.lock.json"))
    if not lock_files:
        print("No lock files found — run 'apko lock' for each config first")
        return 1

    any_changes = False
    for lock_path in lock_files:
        stem = lock_path.name.removesuffix(".lock.json")
        yaml_path = lock_path.parent / f"{stem}.yaml"
        if not yaml_path.exists():
            print(f"Warning: no YAML found for {lock_path}", file=sys.stderr)
            continue

        changes = update_yaml(yaml_path, lock_path)
        if changes:
            any_changes = True
            rel = yaml_path.relative_to(REPO)
            for pkg, (old, new) in changes.items():
                print(f"  {rel}: {pkg} {old} -> {new}")
            update_makefile(yaml_path, changes)

    if not any_changes:
        print("No version changes detected")

    return 0


if __name__ == "__main__":
    sys.exit(main())
