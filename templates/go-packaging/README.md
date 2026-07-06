# go__GO_MINOR_DIR__

Debian packaging for Go __GO_MINOR__: compiles the Go toolchain from the official [golang/go](https://github.com/golang/go) source tree into `golang-__GO_MINOR__-go` packages for enterprise `.deb`-only installs.

## Supported Debian suites

- `trixie`
- `unstable`

Packaging trees live under `debiandirs/<suite>/`. Changelog tracks:

- **mainline** — `changelogs/mainline/<suite>`

## Build (from workspace)

Clone or seed this repo as a sibling of `go-pipeline/`, then from `go-pipeline/`:

```bash
make materialize GO=__GO_MINOR__ DIST=trixie
make build GO=__GO_MINOR__
```

## Layout

| Path | Purpose |
|------|---------|
| `go/` | Go source tree (git submodule from golang/go, `release-branch.go__GO_MINOR__` branch) |
| `patches/` | Quilt series (applied via `gbp pq`) |
| `debiandirs/` | Per-suite Debian packaging (`trixie`, `unstable`) |
| `changelogs/` | `mainline` dch history per suite |
| `.github/workflows/main.yml` | Caller workflow for scheduled CI (seeded per minor line) |
