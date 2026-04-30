# Contributing

## Table of Contents

- [CI Pipeline Structure](#ci-pipeline-structure)
  - [What This Pipeline Builds](#what-this-pipeline-builds)
  - [What CI Tests Validate vs What They Don't](#what-ci-tests-validate-vs-what-they-dont)
  - [Pipeline Flow](#pipeline-flow)
  - [Variant Matrix Logic](#variant-matrix-logic)
- [Contributing to an Existing Variant](#contributing-to-an-existing-variant)
  - [Adding Variant-Specific Tests](#adding-variant-specific-tests)
- [Bootstrapping a New Variant](#bootstrapping-a-new-variant)

---

# CI Pipeline Structure

## What This Pipeline Builds

Each variant (`postgres`, `haproxy`, `servicevm`, `bastion`) produces an **OCI image that contains a full OS rootfs** — systemd units, hardened configs, application services — packaged in OCI format. This is not a typical application container.

The same OCI image is consumed in two different ways:

| Consumer                             | How it uses the image                                                      |
| ------------------------------------ | -------------------------------------------------------------------------- |
| **CI (podman)**                      | Runs as a container under systemd to validate userspace and service wiring |
| **Deployment (bootc-image-builder)** | Wraps the image into a bootable Anaconda ISO for real hardware or VMs      |

## What CI Tests Validate vs What They Don't

The CI boots the image as a container with `podman run --systemd=always`. systemd starts as PID 1 inside the container, bringing up units just as a real OS boot would — but only the userspace portion.

**Validates:**

- All expected files, configs, and init scripts are present and executable
- systemd unit wiring is correct (units enabled, dependencies resolve)
- Services start successfully (init scripts run, app services reach active state)
- Application-layer correctness (e.g. postgres accepts queries) — via variant tests

**Does not validate:**

- Firmware / bootloader / GRUB path
- Kernel or initramfs behaviour
- Real disk install or partition layout

A green CI run means the image's userspace is correct. A full ISO boot on real hardware is still required for hardware-specific validation. See [`service_design/ci-pipeline-design.md`](service_design/ci-pipeline-design.md) for a detailed breakdown with boot path diagrams.

## Pipeline Flow

```
Push to dev / PR opened
  └─ Lint                  ShellCheck all *.sh files; enforce LF line endings

PR opened
  ├─ Lint                  (same as above)
  └─ setup-matrix          Detect which variants changed (path filter)
  └─ build-variants        For each affected variant, run in parallel:
       ├─ Build             Compile OCI image (secrets injected at build-time only)
       ├─ Systemd Boot      Start image under systemd as PID 1
       ├─ Health Check      Verify node-exporter is active — proves the full init
       │                    chain completed without errors
       ├─ Variant Tests     Run .github/variant-tests/<variant>/*.sh in the container
       ├─ Trivy Scan        CVE scan on a confirmed-functional image
       └─ Snapshot          Push verified image to GHCR as :pr-{N}

PR merged to main
  └─ Promote :pr-{N} → :latest  (no rebuild — same digest as what was tested)
  └─ Delete :pr-{N} tag and verify it is gone

Release tag pushed (e.g. postgres-v2.1 or v3.0)
  └─ Pull :latest          (no rebuild — consumes the promoted artifact)
  └─ Final Trivy scan
  └─ Tag versioned         Push :v{version} and :sha-{short} tags to GHCR
  └─ Build ISO             bootc-image-builder wraps the OCI image into an Anaconda ISO
  └─ Split ISO             Split into ≤1.9 GB parts (GitHub Release file size limit)
  └─ Attach to Release     ISO parts + Trivy report + blank SFR uploaded to GitHub Release
```

## Variant Matrix Logic

The pipeline only rebuilds variants whose files changed — not all every time.

| What changed                                 | Variants built                                          |
| -------------------------------------------- | ------------------------------------------------------- |
| `Containerfile` or `build_scripts/common/**` | All variants — shared foundation, any could be affected |
| `build_scripts/postgres/**` only             | `postgres` only                                         |
| `build_scripts/haproxy/**` only              | `haproxy` only                                          |
| None of the above                            | Nothing — pipeline skipped entirely                     |

---

# Contributing to an Existing Variant

## Adding Variant-Specific Tests

The generic health check only proves systemd came up cleanly. For application-level assertions, place shell scripts under:

```
.github/variant-tests/<variant-name>/
```

Every `*.sh` file in that directory is automatically copied into the running container and executed in alphabetical order. A non-zero exit from any script fails the pipeline.

**Example — postgres variant:**

```
.github/variant-tests/postgres/
└── test.sh     ← executes inside the booted container as root
```

```bash
#!/bin/bash
set -euo pipefail

# Wait for postgresql-17 to be active (init chain: init service → initdb → pg start)
timeout 120 bash -c 'until systemctl is-active --quiet postgresql-17.service; do sleep 5; done'

# Test connectivity and a basic query
runuser -u postgres -- pg_isready -h localhost -p 5432
runuser -u postgres -- psql -c "SELECT version();"
```

> **`sudo` vs `runuser`:** Scripts run as root inside the container. Use `runuser -u <user> -- <cmd>` to switch to a service account rather than `sudo -u <user>`. `sudo` goes through PAM, which is not fully functional in a container environment. `runuser` bypasses PAM and works in both container and bare-metal contexts.

---

# Bootstrapping a New Variant

Adding a new variant touches several files across the repo. Every step below is required — missing any one of them will cause the new variant to be silently ignored by the pipeline or fail at runtime.

The examples below use `bind` as the new variant name. Substitute your actual variant name throughout.

## Step 1 — Create build scripts

Create a directory for the variant's install scripts:

```
build_scripts/bind/
└── 20-install-bind.sh   ← variant-specific setup, follows the same numeric prefix convention
```

The `build.sh` entry point in `build_scripts/common/` picks up variant scripts from `build_scripts/$VARIANT/` automatically — no changes to `build.sh` are needed.

## Step 2 — Register path filters in the PR and merge workflows

The `setup-matrix` job in both `pr-ci.yml` and `merge-promotion.yml` uses `dorny/paths-filter` to decide which variants to build. Both files contain two places that must be updated:

**In `.github/workflows/pr-ci.yml` and `.github/workflows/merge-promotion.yml`:**

1. Add a filter entry under the `filters:` block:

```yaml
filters: |
  common:
    - 'Containerfile'
    - 'build_scripts/common/**'
  postgres:
    - 'build_scripts/postgres/**'
  # ... existing variants ...
  bind:                              # ← add this
    - 'build_scripts/bind/**'
```

2. Add the variant to the `changed` object and the `all` array in the `Build PR Matrix` step:

```js
const all = ["postgres", "haproxy", "servicevm", "bastion", "bind"];  // ← add "bind"

const changed = {
  common: ...,
  postgres: ...,
  // ...
  bind: "${{ steps.filter.outputs.bind }}" === "true",   // ← add this line
};
```

Both `pr-ci.yml` and `merge-promotion.yml` contain identical copies of this logic and must both be updated.

## Step 3 — Register the variant in the release workflow

`tag-release.yml` has its own hardcoded `DEFAULT_MATRIX` that determines which variants are included in a global `v*` release tag. Add the new variant there:

```bash
# In .github/workflows/tag-release.yml, setup-matrix job:
DEFAULT_MATRIX='["postgres", "haproxy", "servicevm", "bastion", "bind"]'  # ← add "bind"
```

## Step 4 — Add variant-specific tests

Create a test directory and at minimum a smoke test:

```
.github/variant-tests/bind/
└── test.sh
```

The test script runs inside the booted container as root. See [Adding Variant-Specific Tests](#adding-variant-specific-tests) above for conventions and examples.

If your variant has no application-level assertions yet, the directory can be omitted — the pipeline will skip the variant test step with a warning. However, a test script is strongly recommended before merging.

## Step 5 — Update the README

Add the new variant to the features list in `README.md` and document any new build arguments it introduces under the Build Arguments table.
