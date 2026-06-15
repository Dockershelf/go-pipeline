#!/usr/bin/env python3
"""Resolve the latest Go patch release for a minor version line from go.dev."""
from __future__ import annotations

import argparse
import json
import sys
import urllib.request


def resolve_latest_patch(minor: str, *, stable_only: bool = True) -> str:
    data = json.load(urllib.request.urlopen('https://go.dev/dl/?mode=json'))
    versions: list[str] = []
    for entry in data:
        ver = entry.get('version', '').removeprefix('go')
        if not ver.startswith(f'{minor}.'):
            continue
        if stable_only and not entry.get('stable'):
            continue
        versions.append(ver)
    if not versions and stable_only:
        return resolve_latest_patch(minor, stable_only=False)
    if not versions:
        raise SystemExit(f'no Go release found for minor line {minor}')
    versions.sort(key=lambda v: tuple(int(p) for p in v.split('.')))
    return versions[-1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('minor', help='Go minor line, e.g. 1.25')
    parser.add_argument(
        '--include-prerelease',
        action='store_true',
        help='include non-stable releases when no stable match exists',
    )
    args = parser.parse_args()
    print(resolve_latest_patch(args.minor, stable_only=not args.include_prerelease))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
