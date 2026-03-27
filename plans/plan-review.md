# Plan Review - Cross-Reference Results

Cross-reference of `plans/plan.md` against `plans/next-steps.md` and current repo state.
Generated 2026-03-27.

---

## Task-by-Task Status

### Task 1 - Interactive password wizard
**Status:** Done (expanded to full install wizard)
**What was done:** The thin wrapper `Install-ClaudeSandbox.ps1` now runs an interactive wizard before calling `Install-Sandbox`. All config values are prompted with defaults from sandbox-config.ps1. Password uses SecureString with confirmation, is never stored in config (default is now empty string), and is cleared from memory after chpasswd. `-NonInteractive` switch on the wrapper skips the wizard for CI. The module function `Install-Sandbox` is pure automation - it accepts a fully populated `$Config` and never prompts. Wizard/picker UI lives in wrappers, not in module functions.
**Files changed:** Install-Sandbox.ps1, Install-ClaudeSandbox.ps1, sandbox-config.ps1, CLAUDE.md, README.md

### Task 2 - .gitignore
**Status:** Partially done
**Current state:** `.gitignore` exists but differs from plan.md spec. Current contents cover IDE dirs, build artifacts, and `.claude/settings.local.json`. Missing from plan.md spec: `sandbox-config.ps1`, `*.log`, `*.tmp`, `Thumbs.db`, `desktop.ini`, `$RECYCLE.BIN/`, `*.ps1xml`, `*.swp`.
**Key gap:** `sandbox-config.ps1` is NOT gitignored. Since it contains a hardcoded password (`changeme`), this is the most important missing entry.
**Action:** Merge the plan.md entries into the existing .gitignore. Keep the existing entries that aren't in plan.md (they're valid). Add `sandbox-config.ps1` as the priority item.

### Task 3 - sandbox-config.example.ps1
**Status:** Not done
**Current state:** File does not exist. `sandbox-config.ps1` is committed directly.
**Depends on:** Task 2 (gitignoring sandbox-config.ps1) should happen at the same time, otherwise gitignoring config without providing a template breaks new clones.
**Action:** Create as described in plan.md. Do Tasks 2 + 3 together.

### Task 4 - Tighten doc sync rule in CLAUDE.md
**Status:** Not done
**Current state:** CLAUDE.md still has the broad rule: "After any change to the codebase, update CLAUDE.md, README.md, and plans/security-posture.md / plans/security-posture-details.md to reflect the current state."
**Action:** Replace with the precise version from plan.md. This prevents unintended edits to security posture files.

### Task 5 - Enforcement column in security-posture.md
**Status:** Not done
**Current state:** Tables have Name, Description, Impact, Status, Check columns. No Enforcement column.
**Conflicts with next-steps.md:** next-steps.md #1 says to mark "Managed settings file" and "Managed policy CLAUDE.md" as Supported after implementation. Task 5 would add Enforcement values like "Sandbox (when implemented)" for those same rows. These don't conflict - Task 5 adds the column structure, next-steps #1 later updates the Status value.
**Action:** Implement. Do this before next-steps #1 so the Enforcement column exists when managed settings are deployed.

### Task 6 - Fix TMOUT bypass in security-posture-details.md
**Status:** Not done
**Current state:** The TMOUT section in security-posture-details.md still recommends "add TMOUT to workflow script with `__SessionTimeout__` token" - the simple/bypassable approach.
**Discrepancy:** plan.md specifies `readonly TMOUT` in `/etc/profile.d/session-timeout.sh`, which is better (prevents `unset TMOUT` bypass). These are contradictory approaches for the same feature.
**Action:** Update security-posture-details.md with plan.md's approach (readonly + profile.d). The current approach is inferior.

### Task 7 - Secret management caveat in security-posture-details.md
**Status:** Not done
**Current state:** The "Secret management guidance" section lists general advice but is missing the two specific caveats from plan.md:
1. Env vars are visible to child processes including Claude
2. Never store secrets in `$ClaudePersistenceDir`
**Action:** Add the two items as described in plan.md.

### Task 8 - Resolve multi-arch digest pinning
**Status:** Not done
**Current state:** The "Image digest pinning" section in security-posture-details.md still contains "Need to research" bullet points about multi-arch manifests and digest-only references.
**Action:** Replace with the resolved approach from plan.md. Also update Implementation approach to remove "(needs testing)" qualifier.

### Task 10 - SECURITY.md
**Status:** Different document exists
**Current state:** `SECURITY.md` exists but is a minimal responsible disclosure/vulnerability reporting policy (19 lines). plan.md describes a comprehensive security posture document with Design Principles, Controls Summary table, and Known Limitations (up to 120 lines).
**Discrepancy:** These serve different purposes. The current SECURITY.md follows GitHub's conventional SECURITY.md pattern (vulnerability reporting). plan.md's version is more of a security overview/summary.
**Action:** Two options:
- **Option A (recommended):** Keep current SECURITY.md as the vulnerability reporting policy (this is what GitHub expects at this path). Create the plan.md content as a new section in an existing doc (e.g., expand `docs/about.md` or add to README). The Controls Summary table would duplicate `plans/security-posture.md` - consider just linking to it instead.
- **Option B:** Replace current SECURITY.md with plan.md's version, embedding the vulnerability reporting section at the bottom. Larger file but everything in one place.

### Task 11 - Architecture Decision Records
**Status:** Not done
**Current state:** `docs/decisions/` directory does not exist. None of the 5 ADR files (ADR-001 through ADR-005) exist.
**Conflicts with next-steps.md:** None - next-steps.md does not cover ADRs.
**Action:** Create as described in plan.md. The ADR content in plan.md is well-written and ready to use verbatim.

---

## Overlaps Between plan.md and next-steps.md

| Topic                  | plan.md                                                         | next-steps.md                                              | Conflict? |
| ---------------------- | --------------------------------------------------------------- | ---------------------------------------------------------- | --------- |
| Managed settings       | Task 5 pre-labels Enforcement as "Sandbox (when implemented)"   | #1 implements the actual file and marks Status as Supported | No        |
| Managed policy CLAUDE.md | Task 5 pre-labels Enforcement as "Sandbox (when implemented)" | #1 implements the actual file and marks Status as Supported | No        |
| Sandbox fail-if-unavail | Task 5 adds Enforcement column value                           | #1 bundles it into managed-settings.json                   | No        |
| TMOUT                  | Task 6 fixes the approach in details doc                        | Not covered                                                | No        |
| CI workflow            | Not covered                                                     | #2 creates .github/workflows/validate.yml                  | No        |
| Mermaid check          | Not covered                                                     | #3 manual verification after push                          | No        |

No direct conflicts. The plans are complementary - plan.md is mostly documentation/posture cleanup, next-steps.md is implementation.

---

## Recommended Execution Order

1. **Task 4** - Tighten doc sync rule (prevents accidental posture file edits during other tasks)
2. **Tasks 2 + 3** - .gitignore + example config (credential safety, do together)
3. **Task 1** - Password wizard (depends on Task 3 existing as the template)
4. **Tasks 6, 7, 8** - security-posture-details.md fixes (documentation only, no code)
5. **Task 5** - Enforcement column (documentation, prepares for managed settings)
6. **Task 10** - SECURITY.md decision (Option A or B)
7. **Task 11** - ADRs (standalone, no dependencies)
8. **next-steps #2** - CI workflow (catches issues in subsequent changes)
9. **next-steps #1** - Managed settings deployment (biggest security impact)
10. **next-steps #3** - Mermaid check (after push)

---

## Final Checks from plan.md

plan.md includes a "FINAL CHECKS" section with 7 verification steps. These should be run after all plan.md tasks are complete, not after each individual task. The checks reference files that don't exist yet (sandbox-config.example.ps1, docs/decisions/) so they can't pass until the tasks are done.
