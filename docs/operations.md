# Go pipeline operations

Maintainer runbook for the Dockershelf Go repackaging pipeline.

## 1. Add a new Go minor line (e.g. 1.26)

1. Add `1.26` to `GO_VERSIONS` in [Makefile](../Makefile).
2. Seed the packaging repo:
   ```bash
   ./scripts/seed-go-repo.sh 1.26 ../go1.26
   ```
3. Push `go1.26` to GitHub when ready.
4. Regenerate builder Dockerfiles if `debian/control` Build-Depends changed:
   ```bash
   make generate-dockerfiles
   make build-builder-images
   ```

## 2. Bump Go patch version

1. Run `meta-gbp update` to fetch the latest upstream patch on the release
   branch, rebase any local patches, update changelogs, and commit the new
   `go/` submodule pointer:
   ```bash
   cd ../go1.25
   ../go-pipeline/meta-gbp update --no-interactive
   ```
   (Drop `--no-interactive` to resolve rebase conflicts interactively.)
2. Materialize and build:
   ```bash
   cd ../go-pipeline
   make materialize GO=1.25 DIST=trixie
   make build GO=1.25
   ```
3. For a packaging-only rebuild (no upstream change), bump the changelog
   counter instead:
   ```bash
   cd ../go1.25
   ../go-pipeline/meta-gbp changelog -m "Rebuild for trixie."
   ```

## 3. Add a new Debian suite

1. Copy `debiandirs/trixie/` to `debiandirs/<new-suite>/` in each `go*` repo.
2. Add `changelogs/mainline/<new-suite>` and `changelogs/nightly/<new-suite>`.
3. Add the suite to `DOCKERSHELF_SUITES` in `config.env`.
4. Run `make generate-dockerfiles && make build-builder-images`.

## 4. Publish to APT repository

```bash
make publish DIST=trixie
```

Requires the `DEPLOY_*` variables in `config.env` (or org-level GitHub variables) and SSH access to the droplet. See [`docs/deploy-setup.md`](deploy-setup.md) for the full wiring.

## 5. Enterprise install on target hosts

After publishing, register the repository and install:

```bash
curl -fsSL https://apt.dockershelf.com/dockershelf/dists/trixie/Release.gpg | gpg --dearmor -o /usr/share/keyrings/dockershelf.gpg
echo "deb [signed-by=/usr/share/keyrings/dockershelf.gpg] https://apt.dockershelf.com/dockershelf trixie main" > /etc/apt/sources.list.d/dockershelf.list
apt-get update
apt-get install golang-1.25-go
go version
```

## 6. Enable GitHub Actions CI

See [docs/ci.md](ci.md) for workflow setup, secrets, and per-repo `main.yml` rollout.
