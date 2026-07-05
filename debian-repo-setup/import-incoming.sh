#!/usr/bin/env bash
# Run on the DigitalOcean droplet after rsync delivers .deb files to incoming/.
#
# Usage (from deploy user):
#   ./import-incoming.sh trixie amd64
#   ./import-incoming.sh unstable arm64
#
# Expects:
#   REPO_ROOT=/var/www/debian
#   INCOMING=/var/www/debian/incoming

set -euo pipefail

CODENAME="${1:?usage: import-incoming.sh <trixie|unstable> [arch]}"
ARCH="${2:-}"
REPO_ROOT="${REPO_ROOT:-/var/www/debian}"
INCOMING="${INCOMING:-${REPO_ROOT}/incoming}"
export GNUPGHOME="${GNUPGHOME:-${REPO_ROOT}/.gnupg}"

# Scope to per-arch subdir if ARCH is given (multi-arch publish isolation)
if [[ -n "$ARCH" ]]; then
    INCOMING="${INCOMING}/${ARCH}"
fi

shopt -s nullglob
debs=("${INCOMING}"/*+"${CODENAME}"*.deb)
if [ "${#debs[@]}" -eq 0 ]; then
    debs=("${INCOMING}"/*.deb)
fi
if [ "${#debs[@]}" -eq 0 ]; then
    echo "No .deb files in ${INCOMING}"
    exit 0
fi

for deb in "${debs[@]}"; do
    echo "Including ${deb} into ${CODENAME}..."
    reprepro -b "${REPO_ROOT}" includedeb "${CODENAME}" "${deb}"
    rm -f "${deb}"
done

# Regenerate indices (picks up new arches automatically)
reprepro -b "${REPO_ROOT}" export

echo "Done. Repository updated under ${REPO_ROOT}/dists/${CODENAME}/"
