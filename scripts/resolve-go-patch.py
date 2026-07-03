#!/usr/bin/env python3
"""Resolve the latest Go patch release for a minor version line from go.dev."""
from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request


def _tarball_exists(minor: str, patch: int, arch: str) -> bool:
    ver = f'{minor}.{patch}'
    url = f'https://go.dev/dl/go{ver}.linux-{arch}.tar.gz'
    req = urllib.request.Request(url, method='HEAD')
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status in (200, 302)
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return False
        raise


def _probe_latest_patch(minor: str, arch: str = 'amd64') -> str:
    lo, hi = 0, 99
    found: int | None = None
    while lo <= hi:
        mid = (lo + hi) // 2
        if _tarball_exists(minor, mid, arch):
            found = mid
            lo = mid + 1
        else:
            hi = mid - 1
    if found is None:
        raise SystemExit(f'no Go release found for minor line {minor}')
    return f'{minor}.{found}'


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
    if versions:
        versions.sort(key=lambda v: tuple(int(p) for p in v.split('.')))
        return versions[-1]

    arch = os.environ.get('GO_CI_ARCH', 'amd64').strip() or 'amd64'
    return _probe_latest_patch(minor, arch)


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
