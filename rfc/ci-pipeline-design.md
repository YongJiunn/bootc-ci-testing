# BootC CI/CD Pipeline RFC

| **Metadata**       | **Value**             |
|--------------------|-----------------------|
| **Status**         | V1                    |
| **Authors**        | @lewyongjiun          |
| **Created**        | 2026-03-19            |

## Motivation

The `bootc-service-design` RFC establishes the shift toward building immutable, versioned VM images to prevent runtime configuration drift. This document serves as the implementation standard for the Continuous Integration (CI) and Release pipeline that enforces these guarantees. It defines the branching strategy, security gating, and artifact lifecycle.

## Pipeline Architecture

To optimize runner execution limits and establish strict security gating, the pipeline is decoupled into three explicit execution phases.

### 1. Continuous Integration (`dev` branch)
To provide rapid feedback without consuming heavy build resources, commits pushed to development branches bypass image compilation.
- **Triggers:** Push to `dev`.
- **Execution:** Runs static analysis (ShellCheck) and formatting checks (CRLF validation).

### 2. Pull Request Gating (Shift-Left Validation)
Before any code merges to `main`, it must successfully compile an image. This prevents broken configurations from polluting the master branch.
- **Triggers:** Pull Request creation or update.
- **Execution:** Runs Linters and performs a primary `podman build` of all image variants. 
- **Branch Protection:** GitHub Branch Protection is enforced on `main`. The "Merge" action is strictly blocked until both the Linter and Build jobs report success. Artifact generation, vulnerability scanning, and release logic are actively excluded here to accelerate the PR feedback loop.

### 3. Release & Tagging (`v*` tags)
When code is merged to `main` and a semantic release tag is cut, the pipeline executes the full artifact generation, security auditing, and publishing suite.
- **Triggers:** Push to `refs/tags/v*`
- **Execution:**
  1. **Build Image:** Compiles the final container image utilizing GitHub Repository Secrets mounted securely via `--mount=type=secret`.
  2. **Audit:** Executes Trivy severity scans (High/Critical). Generates a vulnerability report and a blank Software Evaluation Report (SFR) required for software compliance.
  3. **Publish Container:** Pushes the finalized OCI image to the GitHub Container Registry (GHCR).
  4. **Build ISO:** Utilizes `bootc-image-builder` to wrap the OCI container into a bootable Anaconda ISO.
  5. **Release:** Attaches the built ISO, Trivy Report, and SFR file directly to the GitHub Release.

## Artifact & Secret Management
- **Secrets:** Build-time credentials (e.g., database passwords) are never baked into permanent image layers. They are supplied dynamically by GitHub Actions via `podman build --secret` and mounted into memory as `tmpfs` during the image compilation step.
- **Artifacts:** The pipeline treats the OCI container image as the single source of truth; the bootable ISO is structurally a downstream wrapper around this core container.
