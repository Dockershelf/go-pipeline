# APT deploy setup (Go pipeline)

Go packages publish to the **same** DigitalOcean APT droplet as Python and Node. Org-level `DEPLOY_*` variables and `DEPLOY_SSH_KEY` apply here without duplication.

Droplet bootstrap, DNS, TLS, and the import binary live in **[dockershelf-apt](https://github.com/Dockershelf/dockershelf-apt)**. Do **not** run a second droplet bootstrap.

Public repository URL: **`https://apt.dockershelf.com/dockershelf/`**

Canonical checklist: [dockershelf-apt/docs/deploy-setup.md](https://github.com/Dockershelf/dockershelf-apt/blob/main/docs/deploy-setup.md).

## Architecture

```text
go1.XX workflow  →  update-meta-gbp.yml  →  build  →  smoke  →  publish
                                                                    │
                                                                    ├─ rsync → /var/www/debian/incoming/
                                                                    └─ SSH  → /usr/local/bin/dockershelf-import-incoming
                                                                                    │
                                                                              nginx /dockershelf/
```

## What is shared

| Item | Notes |
|------|-------|
| Droplet host | `apt.dockershelf.com` |
| Repository root | `/var/www/debian` |
| Incoming directory | `/var/www/debian/incoming` |
| Import binary | `/usr/local/bin/dockershelf-import-incoming` |
| Nginx path | `/dockershelf/` → `/var/www/debian/` |
| `DEPLOY_SSH_KEY` | Org secret |
| `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_DIR`, `DEPLOY_INCOMING` | Org variables |

Go, Node, and Python packages share `trixie` and `unstable` codenames in the same `reprepro` configuration.

## Go-specific GitHub setup

| Secret / variable | Go-specific? |
|-----------------|----------------|
| `DEPLOY_*` | No — reuse org-level from dockershelf-apt setup |

Run `./scripts/ci-check-config.sh --strict` from `go-pipeline/` to verify configuration.

## Client apt line

```text
deb [signed-by=/usr/share/keyrings/dockershelf.gpg] https://apt.dockershelf.com/dockershelf trixie main
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
