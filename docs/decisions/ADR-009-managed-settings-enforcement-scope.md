# ADR-009: Managed settings enforcement scope

- **Date:** 2026-03-31
- **Status:** Under investigation

## Problem

Claude Code supports managed settings via `/etc/claude-code/managed-settings.json`.
Two settings are relevant to session privilege control:

- `disableBypassPermissionsMode` - blocks `--dangerously-skip-permissions` entirely,
  including for the user
- `allowManagedPermissionRulesOnly` - prevents Claude from adding or widening its own
  permission rules mid-session

These were briefly added to `policies/maximum/settings.json` and then removed pending
verification of whether they are enforced locally or require a Teams/Enterprise
subscription to take effect.

## Explicit non-goal

**`disableBypassPermissionsMode` is not wanted in this sandbox.**

`--dangerously-skip-permissions` is a legitimate user choice, particularly for
unattended sessions where permission prompts cannot be interacted with. Blocking it
at the managed settings level would break that use case. This setting is ruled out
as a control by design, not by uncertainty.

## What is under investigation

`allowManagedPermissionRulesOnly` is the relevant control. The threat it addresses is:

- A prompt injection mid-session instructs Claude to add allow rules that widen its
  own permissions beyond what the user configured at startup
- The user did not intend this - Claude is autonomously expanding its own scope

If `allowManagedPermissionRulesOnly` works locally, it closes this vector without
affecting user-initiated permission modes at all.

## What is unknown

- Whether `allowManagedPermissionRulesOnly` is enforced when Claude Code runs with
  a local managed settings file
- Whether it requires a Teams/Enterprise subscription to take effect

If it does not work locally, it provides no protection and should not appear in any
policy tier.

## Decision

**Do not deploy `allowManagedPermissionRulesOnly` until local enforcement is confirmed.
Do not deploy `disableBypassPermissionsMode` at all - it is the wrong control for
this sandbox.**

## How to resolve the open investigation

Test directly inside the distro:

```bash
# Add to /etc/claude-code/managed-settings.json:
# { "allowManagedPermissionRulesOnly": true }

# Then attempt to add a user-level allow rule via Claude's settings:
# If the rule is rejected, local enforcement is confirmed.
# If it applies normally, the setting has no effect locally.
```

Once confirmed either way, update this ADR to Accepted or Closed and update
`docs/security-posture.md` accordingly.

## Accepted risk (current state)

Without `allowManagedPermissionRulesOnly` confirmed, a prompt injection mid-session
could instruct Claude to widen its own permission rules. The distro boundary remains
the primary containment layer for this gap.

## Controls reference

Managed settings: I-013.
Application Layer gaps: `docs/security-posture.md` - Managed-only permission rules row.
