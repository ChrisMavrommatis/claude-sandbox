# Security Research

Open investigations and deferred items that require external verification or future
action. Resolved items are closed inline with their ADR or control reference.

---

## Open Investigations

### I-001 · allowManagedPermissionRulesOnly local enforcement

**Question:** Does `allowManagedPermissionRulesOnly` in
`/etc/claude-code/managed-settings.json` take effect when Claude Code runs locally,
or does it require a Teams/Enterprise subscription?

**Why it matters:** If locally enforced, it closes prompt-injection-driven permission
widening mid-session without affecting user-initiated permission modes.

**How to test:**

```bash
# Add to /etc/claude-code/managed-settings.json:
# { "allowManagedPermissionRulesOnly": true }

# Attempt to add a user-level allow rule via Claude's settings.
# Rejected = local enforcement confirmed.
# Applied normally = setting has no local effect.
```

**Owner:** Manual test in distro.
**ADR:** ADR-009.
**Blocking:** Adding `allowManagedPermissionRulesOnly` to any policy tier.

---

## Deferred Items

### D-001 · Mandatory image digest pinning for CI/CD

**Context:** Image digest pinning is currently opt-in. S-022 warns but does not fail
if no digest is pinned.

**Condition to act:** If the sandbox is adopted in a CI/CD pipeline or shared
environment where reproducibility is required, S-022 should be changed from WARN to
FAIL and the re-pinning process documented as a required maintenance step.

**ADR:** ADR-008.

---

### D-002 · Secret scanning integration

**Context:** There are currently no dedicated checks for `.env` files or secret pattern
scanning. S-015 and S-016 are file-permission checks (wsl.conf ownership and
sudoers.d perms) and are unrelated to secret detection. A dedicated secret scanner
(e.g. `trufflehog`, `gitleaks`) is not currently integrated.

**Condition to act:** If the project grows to include multiple contributors or is
mirrored to a remote repository, a pre-commit or CI-integrated secret scanner should
replace the current pattern-match approach.

**ADR:** None yet - raise ADR-010 if adopted.

---

### D-003 · Shared host / CI/CD deployment - out of scope

**Context:** Shared host and CI/CD deployment scenarios are out of scope for this
sandbox. The sandbox is designed for single-user workstations only.

**Decision:** Will not be investigated. If scope ever changes, raise a new ADR
rather than reopening this entry.

---

### D-004 · disableBypassPermissionsMode is a non-goal

**Context:** `disableBypassPermissionsMode` in managed settings blocks
`--dangerously-skip-permissions` entirely, including for the user. This is the wrong
control for this sandbox. Users must be able to run `--dangerously-skip-permissions`
for unattended sessions. This setting will not be added to any policy tier.

**Decision:** Rejected by design. See ADR-009.

---

## Watching

Items not yet actionable but worth tracking as Claude Code evolves.

| Item  | What to watch for                                                                   |
|-------|-------------------------------------------------------------------------------------|
| W-001 | Claude Code changelog for `allowManagedPermissionRulesOnly` local enforcement notes |
| W-002 | Claude Code changelog for new managed settings that affect permission scope         |
| W-003 | Debian bookworm-slim CVE cadence - inform re-pinning frequency recommendation       |
