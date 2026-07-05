#!/usr/bin/env bash
# Seed a local go{minor} packaging repository from the go-pipeline template.
#
# Usage:
#   ./seed-go-repo.sh 1.25 /path/to/dockershelf-pipeline/go1.25
#
# Downloads the latest official precompiled Go patch release for the given minor
# line and initializes a git-buildpackage-ready repository.

set -euo pipefail

MINOR="${1:?usage: seed-go-repo.sh <minor e.g. 1.25> <target-dir>}"
TARGET="${2:?usage: seed-go-repo.sh <minor> <target-dir>}"
PIPELINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${PIPELINE}/templates/go-packaging"

if [ -e "${TARGET}" ]; then
    echo "ERROR: ${TARGET} already exists"
    exit 1
fi

go_arch() {
    case "$(uname -m)" in
        x86_64) echo amd64 ;;
        aarch64|arm64) echo arm64 ;;
        armv7l) echo armv6l ;;
        *)
            echo "ERROR: unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

resolve_latest_patch() {
    python3 "${PIPELINE}/scripts/resolve-go-patch.py" "${MINOR}"
}

ARCH="$(go_arch)"
PATCH="$(resolve_latest_patch "${MINOR}")"
TARBALL="go${PATCH}.linux-${ARCH}.tar.gz"
URL="https://go.dev/dl/${TARBALL}"
MINOR_DIR="go${MINOR}"

packaging_cron() {
    case "$MINOR" in
        1.20) echo '35 10 * * *' ;;
        1.21) echo '40 10 * * *' ;;
        1.22) echo '45 10 * * *' ;;
        1.23) echo '50 10 * * *' ;;
        1.24) echo '55 10 * * *' ;;
        1.25) echo '0 11 * * *' ;;
        *) echo '5 11 * * *' ;;
    esac
}

cp -a "${TEMPLATE}" "${TARGET}"
mkdir -p "${TARGET}/patches"

while IFS= read -r -d '' file; do
    if grep -qE '__GO_MINOR(__|_DIR__)?|__PACKAGING_CRON__' "${file}" 2>/dev/null; then
        perl -pi -e "s/__GO_MINOR_DIR__/${MINOR_DIR}/g; s/__GO_MINOR__/${MINOR}/g; s/__PACKAGING_CRON__/$(packaging_cron | sed 's/[\/&]/\\&/g')/g" "${file}"
    fi
done < <(find "${TARGET}" -type f -print0)

while IFS= read -r -d '' path; do
    newpath="${path//__GO_MINOR__/${MINOR}}"
    newpath="${newpath//__GO_MINOR_DIR__/${MINOR_DIR}}"
    if [ "${path}" != "${newpath}" ]; then
        mv "${path}" "${newpath}"
    fi
done < <(find "${TARGET}" -name '*__GO_MINOR*' -print0)

for suite in trixie unstable; do
    for track in mainline nightly; do
        changelog="${TARGET}/changelogs/${track}/${suite}"
        if [ -f "${changelog}" ]; then
            perl -pi -e "s/__GO_MINOR__\\.0\\.0/${PATCH}/g" "${changelog}"
        fi
    done
done

cd "${TARGET}"
chmod +x debiandirs/*/rules

echo "Downloading ${URL} ..."
curl -fsSL "${URL}" -o "${TARBALL}"
tar -xzf "${TARBALL}"
rm -f "${TARBALL}"

if [ ! -f go/VERSION ]; then
    echo "ERROR: extracted tree missing go/VERSION"
    exit 1
fi

git init -b main
git add -A
git commit -m "Initial go${MINOR} Debian repackaging repository (Go ${PATCH})"

echo "Seeded ${TARGET} with Go ${PATCH} (${ARCH})"
