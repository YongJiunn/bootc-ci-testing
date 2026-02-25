# Workflow README
## On every PR/Push to main
The workflow will:
1. Build the image
2. Run Trivy security gate
3. Validate waiver documentation
4. Upload report
5. STOP

If:
- HIGH/CRITICAL vulnerability exists → ❌ CI fails
- Undocumented waiver exists → ❌ CI fails
- Everything clean → ✅ CI passes

No registry push.
No signing.
No ISO.

This is Validation Mode.

## Only when developer creates a Git tag
```
git tag v1.2.0
git push origin v1.2.0
```
Now workflow runs in Release Mode.

But release mode still:

1. Builds
2. Runs Trivy gate
3. Validates waiver documentation

If anything fails → ❌ Release job stops immediately.

Only if all validation steps are green:

- Login to GHCR
- Push semver + sha tags
- Keyless Cosign sign
- Build ISO
- Attach ISO to GitHub Release

## The pipeline does NOT automatically prevent someone from tagging.
Github cannot stop someone from running:
```
git tag v1.2.0
```
What it does instead:
It ensures that even if they tag, the relase will fail unless validation passess.

## What problem does cosign solves?

Cosign is a tool that is used to sign and verify container images. It is a part of the Sigstore project, which is a project that is used to sign and verify container images.

When we push to GHCR:
```
ghcr.io/yongjiun/bootc-postgres:v0.0.8
```
You now have:
- A tagged container
- Stored in a registry
- Mutable by tag reference

But nothing cryptographically proves:

- Who built it
- Whether it was tampered with
- Whether it’s the one your CI produced
- Whether someone re-pushed a malicious image

A container tag is not trust. It is just a label.1

Cosign adds:
```
Cryptographic identity binding between your CI pipeline and that specific image digest.
```

