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

## What does Cosign actually signs?

Cosign does NOT sign the tag.

It signs the digest. Eg: ghcr.io/yongjiun/bootc-postgres@sha256:abc123...

This creates:
- A signature object
- Stored back into GHCR
- Associated with that exact digest 

Now the image becomes: Verifiably produced by our GitHub workflow identity. 

## What threat model does Cosign protects against?

Without Cosign:

If someone:
- Pushes malicious image with same tag
- Compromises registry account
- Replaces image in GHCR
- Modifies CI pipeline later

Your ISO build will blindly consume that image.

With Cosign:

The image must:

- Have valid signature
- Match GitHub OIDC identity
- Match expected workflow
- Match expected repo

Otherwise ISO step fails.

## How does cosign signing works?
1. Requests OIDC identity from GitHub
2. Generates ephemeral key pair
3. Gets certificate from Sigstore
4. Signs image digest
5. Uploads signature to GHCR
6. Logs entry in transparency log (Rekor)

This means:

The signature is tied to:

1. Your repository
2. Your workflow run
3. Your commit SHA
4. GitHub identity

“Image is verifiably produced by this CI workflow under this repository at this commit.”

That’s supply chain provenance.

## Supply Chain Terms

Without Cosign:

- You have artifact storage.

With Cosign:

- You have artifact authenticity.
- You have non-repudiation.
- You have tamper detection.
- You have identity binding.

This is what makes your pipeline enterprise-grade.

## Phase 1:

1. Build
2. Scan
3. Validate

## Phase 2 (Release Tag):

1. Push image
2. Resolve digest
3. Cosign sign digest
4. Cosign verify digest
5. Pull image
6. Build ISO
7. Attach ISO to release

Cosign becomes the trust anchor.

GHCR:
Stores artifact.

Cosign:
Binds artifact to trusted identity.

ISO build:
Derives secondary artifact from trusted primary artifact.

The correct order is:

Push → Sign → Verify → Consume

What you created is:

A cryptographic proof that this exact image digest was signed by this GitHub workflow identity.

Not by your laptop.
Not by a random user.
By your CI identity.

## What Happens If Someone Tampered With Image?

Suppose attacker:

- Pushes malicious image under same tag
- Rewrites tag to new digest

Verification will:

- Resolve new digest
- Try to find signature for that digest
- Fail

Because signature only exists for original digest.

Tampering becomes detectable.