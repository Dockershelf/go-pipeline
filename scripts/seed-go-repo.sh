#!/usr/bin/env bash
# Seed a local go{minor} packaging repository from the go-pipeline template.
#
# Usage:
#   ./seed-go-repo.sh 1.25 /path/to/dockershelf-pipeline/go1.25
#
# The upstream `go/` submodule gitlink is registered pointing to the
# release-branch.go{minor} branch HEAD, but the working tree is not cloned
# here (too large for bootstrap). Initialize it later with
# ../init-go-submodules.sh or:
#   git submodule update --init go

set -euo pipefail

MINOR="${1:?usage: seed-go-repo.sh <minor e.g. 1.25> <target-dir>}"
TARGET="${2:?usage: seed-go-repo.sh <minor> <target-dir>}"
PIPELINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${PIPELINE}/templates/go-packaging"

if [ -e "${TARGET}" ]; then
    echo "ERROR: ${TARGET} already exists"
    exit 1
fi

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

cd "${TARGET}"
git init -b main
chmod +x debiandirs/*/rules

# Register go/ as a proper 160000 gitlink pointing to the
# release-branch.go${MINOR} branch HEAD, matching the python-pipeline
# cpython/ and node-pipeline node/ submodule patterns.
# The working tree is populated later by init-go-submodules.sh or:
#   git submodule update --init go
GO_SHA="$(curl -fsSL "https://api.github.com/repos/golang/go/branches/release-branch.go${MINOR}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['commit']['sha'])")"
rm -rf go
git update-index --add --cacheinfo 160000 "${GO_SHA}" go
git add .gitmodules
git commit -m "Initial go${MINOR} Debian packaging repository"

echo "Seeded ${TARGET} (run init-go-submodules.sh to fetch upstream go)"
