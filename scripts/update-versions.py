#!/usr/bin/env python3
"""
Update Makefile image tags and OCI version annotations from apko lock files.

For each image whose tag contains a full x.y.z version, finds the single
unpinned package directly listed in its YAML (the "primary package"), reads
its resolved version from the lock file, and updates the Makefile tag and
annotation when the version has changed.

Images with channel tags (base:stable, nodejs:22, golang:1.22, rust:1.92,
jdk:11, etc.) are skipped — their tags are intentional and do not change.
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
    """Return the upstream version of pkg_name (x86_64) from a lock file."""
    data = json.loads(lock_path.read_text())
    for pkg in data["contents"]["packages"]:
        if pkg["name"] == pkg_name and pkg["architecture"] == "x86_64":
            return strip_wolfi_suffix(pkg["version"])
    return None


def get_direct_packages(yaml_path: Path) -> list[str]:
    """
    Return packages listed directly in this YAML's contents.packages,
    excluding anything pulled in via include:.
    """
    try:
        import yaml
        data = yaml.safe_load(yaml_path.read_text()) or {}
        return data.get("contents", {}).get("packages", [])
    except ImportError:
        pass

    # Fallback regex parser for the consistent apko YAML format
    packages: list[str] = []
    in_pkgs = False
    pkg_indent: int | None = None
    for line in yaml_path.read_text().splitlines():
        if re.match(r" {4,}packages:\s*$", line):
            in_pkgs = True
            pkg_indent = None
            continue
        if in_pkgs:
            m = re.match(r"( +)- (.+)", line)
            if m:
                indent = len(m.group(1))
                if pkg_indent is None:
                    pkg_indent = indent
                if indent == pkg_indent:
                    packages.append(m.group(2).strip())
            elif line.strip() and not line.startswith("    "):
                in_pkgs = False
    return packages


def primary_package(yaml_path: Path, image_tag: str) -> str | None:
    """
    Return the primary package name if this image has a trackable version,
    otherwise None.

    Trackable: tag contains a full x.y.z version AND the YAML has exactly
    one directly-listed package with no version constraint (i.e. unpinned).
    """
    if not re.search(r":\d+\.\d+\.\d+", image_tag):
        return None  # channel tag (nodejs:22, golang:1.22, base:stable, …)

    unpinned = [
        p for p in get_direct_packages(yaml_path)
        if not re.search(r"[=<>!~]", p)
    ]
    return unpinned[0] if len(unpinned) == 1 else None


def makefile_entry(config_rel: str) -> tuple[str, str] | tuple[None, None]:
    """Return (target, image_tag) for config_rel, or (None, None)."""
    m = re.search(
        rf"call IMAGE,([^,]+),{re.escape(config_rel)},([^)]+)",
        MAKEFILE.read_text(),
    )
    return (m.group(1), m.group(2)) if m else (None, None)


def update_makefile(config_rel: str, old_ver: str, new_ver: str) -> None:
    content = MAKEFILE.read_text()
    # Handles simple tags (grype:0.110.0) and compound ones (golangci-lint:2.11.4-go1.22)
    pattern = (
        rf"(call IMAGE,[^,]+,{re.escape(config_rel)},[^:]+:)"
        rf"{re.escape(old_ver)}"
        rf"((?:-go[\d.]+)?)\)"
    )
    updated = re.sub(pattern, rf"\g<1>{new_ver}\2)", content)
    if updated != content:
        MAKEFILE.write_text(updated)


def update_annotation(yaml_path: Path, old_ver: str, new_ver: str) -> None:
    content = yaml_path.read_text()
    # Match the version with or without surrounding quotes, preserving them —
    # otherwise a quoted annotation (e.g. `version: "0.46.1"`) silently never
    # updates and drifts from the Makefile tag.
    updated = re.sub(
        rf'(org\.opencontainers\.image\.version:\s*)"?{re.escape(old_ver)}"?',
        rf'\g<1>{new_ver}',
        content,
    )
    if updated != content:
        yaml_path.write_text(updated)


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
            print(f"Warning: no YAML for {lock_path}", file=sys.stderr)
            continue

        config_rel = str(yaml_path.relative_to(REPO))
        _, image_tag = makefile_entry(config_rel)
        if not image_tag:
            continue

        pkg = primary_package(yaml_path, image_tag)
        if not pkg:
            continue

        m = re.search(r":(\d+\.\d+\.\d+)", image_tag)
        current_ver = m.group(1) if m else None
        if not current_ver:
            continue

        new_ver = lock_version(lock_path, pkg)
        if not new_ver or new_ver == current_ver:
            continue

        any_changes = True
        print(f"  {config_rel}: {pkg} {current_ver} -> {new_ver}")
        update_makefile(config_rel, current_ver, new_ver)
        update_annotation(yaml_path, current_ver, new_ver)

    if not any_changes:
        print("No version changes detected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
