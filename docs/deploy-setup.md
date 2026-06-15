# APT deploy setup (Go pipeline)

Go packages publish to the **same** DigitalOcean APT droplet and repository tree as Python and Node packages.
Org-level `DEPLOY_*` variables and `DEPLOY_SSH_KEY` configured for [python-pipeline](../../python-pipeline/docs/deploy-setup.md) apply here without duplication.

Public repository URL: **`https://apt.luisalejandro.org/dockershelf/`**

## Architecture

```text
go1.XX workflow  →  update-meta-gbp.yml  →  build  →  smoke  →  publish
                                                                    │
                                                                    ├─ rsync → /var/www/debian/incoming/
                                                                    └─ SSH  → import-incoming.sh → reprepro
                                                                                    │
                                                                              nginx /dockershelf/
```

Use [`deploy-connectivity.yml`](../.github/workflows/deploy-connectivity.yml) to verify SSH and paths without publishing packages.

## What is shared with Python and Node

| Item | Notes |
|------|-------|
| Droplet host | `apt.luisalejandro.org` |
| Repository root | `/var/www/debian` |
| Incoming directory | `/var/www/debian/incoming` |
| Nginx path | `/dockershelf/` → `/var/www/debian/` |
| `DEPLOY_SSH_KEY` | Org secret |
| `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_DIR`, `DEPLOY_INCOMING` | Org variables |

Go, Node, and Python packages share `trixie` and `unstable` codenames in the same `reprepro` configuration.

## Bootstrap and TLS

Do **not** run a second droplet bootstrap for Go. Follow the Python pipeline guide:

- [python-pipeline/docs/deploy-setup.md](https://github.com/Dockershelf/python-pipeline/blob/main/docs/deploy-setup.md) — DNS, TLS, GitHub secrets/variables
- [python-pipeline/debian-repo-setup/bootstrap-droplet.sh](https://github.com/Dockershelf/python-pipeline/blob/main/debian-repo-setup/bootstrap-droplet.sh)
- [python-pipeline/debian-repo-setup/create-ci-deploy-key.sh](https://github.com/Dockershelf/python-pipeline/blob/main/debian-repo-setup/create-ci-deploy-key.sh)

## Go-specific GitHub setup

| Secret / variable | Go-specific? |
|-----------------|----------------|
| `GH_PACKAGES_TOKEN` | Optional — for `dockershelf-go-builder` GHCR push on `go-pipeline` |
| `DEPLOY_*` | No — reuse org-level from Python setup |

Run `./scripts/ci-check-config.sh --strict` from `go-pipeline/` to verify configuration.

## Client apt line

```text
deb [signed-by=/usr/share/keyrings/dockershelf.gpg] https://apt.luisalejandro.org/dockershelf trixie main
```

Install Go:

```bash
apt-get update
apt-get install golang-1.25-go
go version
```

## Package names

| Go minor | Debian package |
|----------|----------------|
| 1.25 | `golang-1.25-go` |
| 1.24 | `golang-1.24-go` |
| … | `golang-<minor>-go` |

Packages install to `/usr/lib/go-<minor>` with `/usr/bin/go` and `/usr/bin/gofmt` symlinks.
