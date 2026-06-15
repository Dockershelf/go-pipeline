# GitHub Actions CI

Continuous integration for Dockershelf Go repackaging: builder images on GHCR, scheduled
`meta-gbp update` / build / smoke test / APT publish across `go1.20`–`go1.25`.

## Workflows

| Workflow | Repo | Purpose |
|----------|------|---------|
| [`builder-images.yml`](../.github/workflows/builder-images.yml) | `go-pipeline` | Build and push `ghcr.io/dockershelf/dockershelf-go-builder/*` |
| [`update-meta-gbp.yml`](../.github/workflows/update-meta-gbp.yml) | `go-pipeline` | Reusable: update → build → smoke → publish |
| [`pr.yml`](../.github/workflows/pr.yml) | `go-pipeline` | `pre-commit` on pull requests |
| [`publish.yml`](../.github/workflows/publish.yml) | `go-pipeline` | Manual republish of local `dist/` to APT |
| [`deploy-connectivity.yml`](../.github/workflows/deploy-connectivity.yml) | `go-pipeline` | Manual SSH/incoming-dir check (no rsync) |
| [`main.yml`](../templates/go-packaging/.github/workflows/main.yml) | each `go1.XX` | Daily schedule + dispatch → calls reusable workflow |

## CI workspace layout

```text
$GITHUB_WORKSPACE/
├── go1.25/              # triggering go repo
└── go-pipeline/         # orchestration checkout
```

Scripts:

- [`scripts/ci-setup-workspace.sh`](../scripts/ci-setup-workspace.sh) — validate layout, export GHCR image names
- [`scripts/ci-pull-builder-images.sh`](../scripts/ci-pull-builder-images.sh) — pull GHCR images or build locally
- [`scripts/resolve-go-patch.py`](../scripts/resolve-go-patch.py) — latest patch from go.dev (used by `meta-gbp update` and seed)
- [`scripts/debian-smoke-test.sh`](../scripts/debian-smoke-test.sh) — install `.deb`s in `debian:{suite}-slim`
- [`scripts/ci-publish.sh`](../scripts/ci-publish.sh) — rsync + `import-incoming.sh`
- [`scripts/ci-deploy-preflight.sh`](../scripts/ci-deploy-preflight.sh) — validate `DEPLOY_*` vars (optional `--connectivity`)

## GHCR images

| Image | Tag |
|-------|-----|
| `ghcr.io/dockershelf/dockershelf-go-builder/tools` | `latest`, `sha-<commit>` |
| `ghcr.io/dockershelf/dockershelf-go-builder/trixie` | `latest`, `sha-<commit>` |
| `ghcr.io/dockershelf/dockershelf-go-builder/unstable` | `latest`, `sha-<commit>` |

`builder-images.yml` pushes on push to `main`; pull requests build only (no push).

Go builder images use a **separate** GHCR prefix from Python (`dockershelf-builder`) and Node (`dockershelf-node-builder`).

## Secrets and variables

Configure on **`Dockershelf/go-pipeline`** and each **`go1.XX`** repo (or at org level).

Run [`scripts/ci-check-config.sh`](../scripts/ci-check-config.sh) to list which secrets/variables are set (values are never printed). Use `--strict` to fail when deploy configuration is incomplete.

Full droplet + GitHub wiring: [`docs/deploy-setup.md`](deploy-setup.md).

### Secrets

| Name | Purpose |
|------|---------|
| `DEPLOY_SSH_KEY` | Private SSH key for `DEPLOY_USER@DEPLOY_HOST` (shared with Python/Node pipelines) |
| `GH_PACKAGES_TOKEN` | Optional; defaults to `GITHUB_TOKEN` with `packages: write` on `go-pipeline` |

### Repository variables

| Name | Example |
|------|---------|
| `DEPLOY_HOST` | `apt.luisalejandro.org` |
| `DEPLOY_USER` | `deploy` |
| `DEPLOY_DIR` | `/var/www/debian` |
| `DEPLOY_INCOMING` | `/var/www/debian/incoming` |
| `DEBFULLNAME` | `Dockershelf Maintainer` |
| `DEBEMAIL` | `maintainer@example.com` |

Publish jobs run only when `publish` input is true **and** `DEPLOY_HOST` is set. When deploy variables are missing, build and smoke still run and the workflow summary notes that publish was skipped.

## GitHub settings

1. **`go-pipeline` → Settings → Actions → General**
   - Workflow permissions: read and write (for GHCR push).
   - Allow reuse of workflows by repos in the `Dockershelf` org.

2. **Each `go1.XX` repo**
   - Actions → access to `go-pipeline` reusable workflows.
   - Caller workflow needs `permissions: contents: write` so `meta-gbp update` commits can push.
   - Same secrets/variables as above (or inherit org-level).

3. **GHCR package visibility**
   - Link each `dockershelf-go-builder/*` package to `go1.*` repos under **Package settings → Manage Actions access**, or make packages **public**.
   - Caller workflows use `permissions: packages: read`.
   - If `docker pull` is denied, CI builds from committed `dockerfiles/Dockerfile.*`.

## Schedule (UTC)

Cron is staggered after the Node window (`10:10`–`10:30` UTC):

| Repo | Cron |
|------|------|
| go1.20 | `35 10 * * *` |
| go1.21 | `40 10 * * *` |
| go1.22 | `45 10 * * *` |
| go1.23 | `50 10 * * *` |
| go1.24 | `55 10 * * *` |
| go1.25 | `0 11 * * *` |

Scheduled runs publish when deploy variables and `DEPLOY_SSH_KEY` are configured. Use `workflow_dispatch` with `publish: false` to build and smoke-test only.

## Per-repo rollout

1. Push `go-pipeline` to GitHub with workflows and scripts.
2. Run **Builder images** and **Deploy connectivity** on `go-pipeline`.
3. For each `go1.XX` repo:
   - Ensure packaging repo exists (clone or `make bootstrap`).
   - Copy or seed [`.github/workflows/main.yml`](../templates/go-packaging/.github/workflows/main.yml) (included when seeding from template).
   - Push with a PAT that has **`workflow`** scope.
4. Dispatch packaging on `go1.25` with `publish: false`, then `publish: true` when ready.

## Manual runs

**Full pipeline (go1.25):** Actions → packaging → Run workflow.

**Republish existing debs:** `go-pipeline` → Actions → publish → choose suite (expects `dist/*.deb` in the runner workspace).

**Deploy connectivity only:** `go-pipeline` → Actions → Deploy connectivity.

## Architecture note

CI runs on `ubuntu-latest` and sets `GO_CI_ARCH=amd64` during `meta-gbp update`, so published `.deb` packages contain the official **amd64** Go toolchain. arm64 builds require a separate matrix job (future work).

## Failure modes

| Failure | Action |
|---------|--------|
| `meta-gbp update` / `dch` exit 25 | Changelog heading has a space before `)`; fix with `dch` locally |
| `go1.20` not on go.dev | Skip repo in bootstrap or pin last known patch manually |
| Builder image pull fails | CI falls back to local docker build from committed `dockerfiles/` (slow) |
| Smoke test `apt-get -f install` fails | Check missing runtime deps in generated `.deb` set |
| Publish SSH/rsync fails | Verify `DEPLOY_*` variables and `DEPLOY_SSH_KEY`; run **Deploy connectivity** workflow |

## Verification checklist

After pushing `go-pipeline` to GitHub:

1. `./scripts/ci-check-config.sh --strict` (local, with `gh` authenticated)
2. Run **Deploy connectivity** workflow
3. Run **Builder images** workflow
4. Push `main.yml` to `go1.25`, dispatch with `publish: false`
5. Confirm artifact `golang-*-go_*_amd64.deb` installs and `go version` passes smoke
6. Dispatch with `publish: true` → verify package in APT `trixie` / `unstable` dists
