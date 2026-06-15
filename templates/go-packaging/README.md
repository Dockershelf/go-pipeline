# go__GO_MINOR_DIR__

Debian packaging for Go __GO_MINOR__: repackages the official precompiled toolchain from [go.dev](https://go.dev/dl/) into `golang-__GO_MINOR__-go` packages for enterprise `.deb`-only installs.

## Supported Debian suites

- `trixie`
- `unstable`

Packaging trees live under `debiandirs/<suite>/`. Changelog tracks:

- **mainline** — `changelogs/mainline/<suite>`
- **nightly** — `changelogs/nightly/<suite>`

## Build (from workspace)

Clone or seed this repo as a sibling of `go-pipeline/`, then from `go-pipeline/`:

```bash
make materialize GO=__GO_MINOR__ DIST=trixie
make build GO=__GO_MINOR__
```

## Layout

| Path | Purpose |
|------|---------|
| `go/` | Official precompiled Go toolchain tree (from go.dev tarball) |
| `patches/` | Quilt series (usually empty for repackaging) |
| `debiandirs/` | Per-suite Debian packaging (`trixie`, `unstable`) |
| `changelogs/` | `mainline` and `nightly` dch history per suite |
| `.github/workflows/main.yml` | Caller workflow for scheduled CI (seeded per minor line) |
