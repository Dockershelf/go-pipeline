# Dockershelf Go packaging pipeline

Orchestration for repackaging official precompiled Go toolchains from [go.dev](https://go.dev/dl/) into Debian packages (`golang-<minor>-go`) and publishing to the self-hosted APT repository on DigitalOcean.

Mirrors [python-pipeline](../python-pipeline/) and [node-pipeline](../node-pipeline/) for Debian (`trixie`, `unstable`) and Dockershelf hosting.

## Workspace layout

Clone this repo as a sibling of the `go*` packaging repos:

```text
deadsnakes-pipeline/
├── go-pipeline/     # this repo
├── go1.20/
├── go1.21/
├── go1.22/
├── go1.23/
├── go1.24/
└── go1.25/
```

## Quick start

```bash
cd go-pipeline
cp config.env.example config.env
make bootstrap
make build-tools-image
make build-builder-images
make materialize GO=1.25 DIST=trixie
make build GO=1.25
make publish DIST=trixie
```

## Build a single distribution

```bash
make materialize GO=1.25 DIST=trixie
make build GO=1.25
```

Output `.deb` files land in `dist/`.

## Generate builder Dockerfiles

```bash
make generate-dockerfiles
make build-builder-images
```

Builder images are tagged `dockershelf-builder/<suite>` (e.g. `dockershelf-builder/trixie`).

Because Go is repackaged from official precompiled tarballs, builder images only need `debhelper` — no compiler toolchain.

## Configuration

Copy `config.env.example` to `config.env`. See `debian-repo-setup/README.md` for droplet APT hosting (shared with Python and Node packages).

## Source repositories

| Local path (sibling) | Remote |
|----------------------|--------|
| `../go1.20/` … `../go1.25/` | `https://github.com/Dockershelf/go1.XX` |

`make bootstrap` clones any missing `go*` repos from GitHub, or seeds them from `templates/go-packaging/` when remotes are unavailable.

## Operations manual

Step-by-step guides for maintainers: [docs/operations.md](docs/operations.md)

## Continuous integration

GitHub Actions workflows mirror [python-pipeline](../python-pipeline/docs/ci.md) and [node-pipeline](../node-pipeline/docs/ci.md):

- [docs/ci.md](docs/ci.md) — workflows, GHCR images, secrets, schedule
- [docs/deploy-setup.md](docs/deploy-setup.md) — shared APT droplet wiring

## Future work

- Multi-arch publish (amd64, arm64) via separate CI matrix jobs
- Debian smoke test in local `make` targets
- Integrate published packages into Dockershelf `go/build-image.sh`
