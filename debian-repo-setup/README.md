# DigitalOcean Droplet — APT repository setup

Templates for hosting Dockershelf-built Node.js `.deb` packages with **reprepro** and **nginx**.

Node packages share the same repository tree as Python packages (`/var/www/debian`). No separate droplet is required.

## Layout on the droplet

```text
/var/www/debian/
├── conf/
│   └── distributions          # from reprepro-distributions
├── incoming/                  # rsync target for new .deb files
├── dists/                     # reprepro-generated indices
└── pool/                      # reprepro package pool
```

## One-time server setup

See [python-pipeline/debian-repo-setup/README.md](https://github.com/Dockershelf/python-pipeline/blob/main/debian-repo-setup/README.md) for the full droplet bootstrap. Node packages publish into the same `trixie` and `unstable` codenames.

## Client apt line (Dockershelf images)

```text
deb [signed-by=/usr/share/keyrings/dockershelf.gpg] https://apt.dockershelf.example/debian trixie main
```

Use codename matching the image base (`trixie` or `unstable` for sid).

## Publish flow (from local pipeline)

From `node-pipeline/` after `make build`:

```bash
make publish DIST=trixie
```

This rsyncs `dist/*.deb` to the droplet and runs `import-incoming.sh` over SSH.
