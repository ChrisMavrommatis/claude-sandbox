# ADR-008: Image digest pinning

- **Date:** 2026-03-31
- **Status:** Accepted

## Problem

`debian:bookworm-slim` is a floating tag. Each install pulls whatever the registry
serves at that moment. A tag can silently point to a different image between installs
with no warning - introducing unexpected changes or, in a supply chain attack scenario,
a compromised image.

## Decision

**Digest pinning is opt-in. The default uses the floating tag. S-022 warns during
verification if no digest is pinned.**

## What this means in practice

- Default `$DistroImage = 'debian:bookworm-slim'` - works out of the box, no pinning
- To pin: get the current digest and set it in `sandbox-config.ps1`:

  ```powershell
  # Pull platform-specific image first
  podman pull --platform linux/amd64 debian:bookworm-slim

  # Get the digest
  podman inspect --format '{{.Digest}}' debian:bookworm-slim

  # Pin in sandbox-config.ps1
  $DistroImage = 'debian:bookworm-slim@sha256:<your-digest>'
  ```

- Digest is architecture-specific - amd64 and arm64 digests differ
- Pinned digests go stale as Debian releases security updates - re-pin periodically
- S-022 emits a warning (not a failure) if `$DistroImage` does not contain `@sha256:`

## Why opt-in rather than required

Forcing all users to pin means the digest goes stale silently on the next Debian
security update - users would install an outdated image without realising it. A warning
is more honest than a silent stale pin.

## Accepted risk

Without pinning, the installer pulls whatever `debian:bookworm-slim` resolves to at
install time. A compromised or unexpected image cannot be detected. This is accepted
because:

1. The image is pulled over HTTPS from Docker Hub or a configured registry
2. Debian's official image has a strong supply chain - compromise is low probability
3. The distro is rebuildable on demand - recovery from a bad image is straightforward

## Condition for revisiting

If the sandbox is used in a CI/CD pipeline or shared environment where reproducibility
is required, pinning should be mandatory. Change S-022 from WARN to FAIL and document
the re-pinning process as a required maintenance step.

## Controls reference

Digest pinning check: S-022 (warn-only).
Deployment Integrity gap: `docs/security-posture.md` - Deployment Integrity,
Image digest pinning row.
