#!/usr/bin/env bash
# Prepare CI workspace: init go submodule and export image env vars.
#
# Usage:
#   GO_REPO_DIR=/path/to/go1.25 PIPELINE_DIR=/path/to/go-pipeline \
#     ./scripts/ci-setup-workspace.sh
#
# Or pass positional args: ./ci-setup-workspace.sh /path/to/go1.25 [/path/to/go-pipeline]

set -euo pipefail

GO_REPO_DIR="${GO_REPO_DIR:-${1:-}}"
PIPELINE_DIR="${PIPELINE_DIR:-${2:-}}"

if [[ -z "$GO_REPO_DIR" ]]; then
    echo "GO_REPO_DIR required (env or first argument)" >&2
    exit 1
fi

GO_REPO_DIR="$(cd "$GO_REPO_DIR" && pwd)"
PIPELINE_DIR="${PIPELINE_DIR:-$(dirname "$GO_REPO_DIR")/go-pipeline}"
PIPELINE_DIR="$(cd "$PIPELINE_DIR" && pwd)"

for f in meta-gbp build docker-run tools; do
    if [[ ! -e "$PIPELINE_DIR/$f" ]]; then
        echo "missing $PIPELINE_DIR/$f" >&2
        exit 1
    fi
done

if [[ ! -f "$GO_REPO_DIR/.gitmodules" ]]; then
    echo "missing $GO_REPO_DIR/.gitmodules" >&2
    exit 1
fi

git -C "$GO_REPO_DIR" submodule update --init go || true
if [[ -d "$GO_REPO_DIR/go/.git" ]]; then
    git -C "$GO_REPO_DIR/go" fetch --tags origin || true
fi

export GO_REPO_DIR
export PIPELINE_DIR
export DOCKERSHELF_ARCH="${DOCKERSHELF_ARCH:-amd64}"
export DOCKERSHELF_BUILDER_IMAGE="${DOCKERSHELF_BUILDER_IMAGE:-ghcr.io/dockershelf/dockershelf-go-builder}"
export DOCKERSHELF_TOOLS_IMAGE="${DOCKERSHELF_TOOLS_IMAGE:-ghcr.io/dockershelf/dockershelf-go-builder/tools}"

if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
        echo "GO_REPO_DIR=$GO_REPO_DIR"
        echo "PIPELINE_DIR=$PIPELINE_DIR"
        echo "DOCKERSHELF_ARCH=$DOCKERSHELF_ARCH"
        echo "DOCKERSHELF_BUILDER_IMAGE=$DOCKERSHELF_BUILDER_IMAGE"
        echo "DOCKERSHELF_TOOLS_IMAGE=$DOCKERSHELF_TOOLS_IMAGE"
    } >>"$GITHUB_ENV"
fi

echo "GO_REPO_DIR=$GO_REPO_DIR"
echo "PIPELINE_DIR=$PIPELINE_DIR"
echo "DOCKERSHELF_ARCH=$DOCKERSHELF_ARCH"
echo "DOCKERSHELF_BUILDER_IMAGE=$DOCKERSHELF_BUILDER_IMAGE"
echo "DOCKERSHELF_TOOLS_IMAGE=$DOCKERSHELF_TOOLS_IMAGE"
