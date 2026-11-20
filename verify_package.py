"""Check repository files and, optionally, the local ENA source modules.

Uses only the Python standard library. Source data are never copied or uploaded.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().lower()


def read_rows(name: str) -> list[dict[str, str]]:
    with (ROOT / name).open(newline="", encoding="utf-8-sig") as stream:
        return list(csv.DictReader(stream))


def check(path: Path, expected_bytes: int, expected_hash: str) -> bool:
    if not path.is_file():
        print(f"MISSING  {path}")
        return False
    actual_bytes = path.stat().st_size
    if actual_bytes != expected_bytes:
        print(f"SIZE     {path}: {actual_bytes} != {expected_bytes}")
        return False
    actual_hash = sha256(path)
    if actual_hash != expected_hash.lower():
        print(f"SHA256   {path}: {actual_hash} != {expected_hash.lower()}")
        return False
    print(f"OK       {path}")
    return True


def unique_module(root: Path, filename: str) -> Path | None:
    matches = list(root.rglob(filename))
    if len(matches) != 1:
        print(f"EXPECTED ONE {filename} beneath {root}; found {len(matches)}")
        return None
    return matches[0]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--historical", type=Path, help="Local ENA_2014_2024.sav")
    parser.add_argument("--ena-2025-root", type=Path, help="Folder with four official 2025 SAV modules")
    args = parser.parse_args()
    passed = True

    package = read_rows("PACKAGE_MANIFEST_SHA256.csv")
    print(f"Checking {len(package)} package files...")
    for row in package:
        relative = Path(row["path"])
        if relative.is_absolute() or ".." in relative.parts:
            print(f"INVALID PACKAGE PATH {relative}")
            passed = False
            continue
        passed = check(ROOT / relative, int(row["bytes"]), row["sha256"]) and passed

    if args.historical:
        row = next(row for row in read_rows("source_hashes.csv") if row["Name"] == "ENA_2014_2024.sav")
        print("Checking historical source; this 14.75 GB SHA-256 check may take several minutes...")
        passed = check(args.historical, int(row["Bytes"]), row["SHA256"]) and passed

    if args.ena_2025_root:
        for row in read_rows("source_manifest.csv"):
            module = unique_module(args.ena_2025_root, row["module"])
            passed = module is not None and check(module, int(row["bytes"]), row["sha256"]) and passed

    print("PASS: all requested checks matched." if passed else "FAIL: at least one check did not match.")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
