## IMPORTANT: Write all documents in the third person from the perspective of
## the tool and its users. Do not reference the author, their background,
## or any personal information. Documents should read as if written by a
## professional team, not an individual developer.

---

## Task: Project hardening, credential safety, and portfolio build
## Work through tasks in order. Follow all CLAUDE.md rules throughout.
## Tasks marked [WIZARD], [FIX], [NEW FILE] for easy tracking.
## Read all tasks before starting. After each task, state what you did
## and which files changed. Do not modify security-posture.md or
## security-posture-details.md except in tasks that explicitly target them
## (Tasks 5, 6, 7, 8).

---

### [WIZARD] TASK 1 — Remove hardcoded password from sandbox-config.ps1

Currently $UserPassword is hardcoded in sandbox-config.ps1. Replace with an
interactive wizard in Install-Sandbox so the password is never stored in a
config file during normal use.

Changes to sandbox-config.ps1:
- Set $UserPassword = "" (empty string, not removed — preserves CI use case)
- Add comment above it:
  "# Leave blank to be prompted interactively during install (recommended).
  # Set a value here only for non-interactive / CI runs."

Changes to the Install-Sandbox function (ClaudeSandbox/Public/Install-Sandbox.ps1):
- At the very start of the function body, before any setup begins, add:
  if ([string]::IsNullOrEmpty($Config.UserPassword)) {
      $secure = Read-Host -Prompt "Set sandbox user password" -AsSecureString
      $Config.UserPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
          [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
      )
      $secure = $null
      [GC]::Collect()
  }
- The existing code that passes $Config.UserPassword to chpasswd does not need
  to change — it will receive the value from either source transparently
- After chpasswd is called, clear the value:
  $Config.UserPassword = $null
  [GC]::Collect()

Changes to CLAUDE.md:
- In the thin wrapper template example, mark UserPassword as optional:
  UserPassword = $UserPassword  # Optional — leave blank to prompt interactively
- In the Configuration section, update the $UserPassword entry to:
  "$UserPassword — Optional. Leave blank to be prompted during install.
  Set only for non-interactive or CI runs. Never commit a real value to git."

Changes to README.md:
- In the Quick Start config block, change to:
  $UserPassword = ""  # Leave blank to be prompted during install (recommended)
- Remove any example showing a hardcoded password value

Verification:
- The existing S-013 check (password changed from default) must still pass
- Do not add new check codes for this task — behaviour change only

---

### [NEW FILE] TASK 2 — Create .gitignore

Create .gitignore at the project root.

Contents (use exactly):

```gitignore
# sandbox-config.ps1 is gitignored because it may contain a password
# if the user sets $UserPassword for non-interactive runs.
# Use sandbox-config.example.ps1 as your starting point.
sandbox-config.ps1

# Logs and temp files
*.log
*.tmp

# Windows noise
Thumbs.db
desktop.ini
$RECYCLE.BIN/

# PowerShell
*.ps1xml

# Editor
.vscode/
.idea/
*.swp
```

---

### [NEW FILE] TASK 3 — Create sandbox-config.example.ps1

Create sandbox-config.example.ps1 as the committed reference template.
This file IS safe to commit — it contains no real values.

Rules:
- Header comment block at the top:
  "# Claude Sandbox configuration template.
  # Copy this file to sandbox-config.ps1 and edit before running the installer.
  # sandbox-config.ps1 is gitignored. This file is safe to commit."
- Every variable must have a one-line comment explaining what it does
- $UserPassword = "" with comment:
  "# Leave blank to be prompted interactively during install (recommended)"
- All path variables use clearly fake placeholder values:
  $ProjectsPath = "D:\Projects"
  $ClaudePersistenceDir = "D:\.claude"
  $InstallDir = "C:\WSL\ClaudeSandbox"
- All other variables copied from sandbox-config.ps1 with their default values
  and comments
- No real credentials, paths, or machine-specific values anywhere in this file

Update README.md Quick Start:
- Change "open sandbox-config.ps1 and set your paths" to:
  "Copy sandbox-config.example.ps1 to sandbox-config.ps1 and set your paths"
- Show the copy command:
  Copy-Item sandbox-config.example.ps1 sandbox-config.ps1

---

### [FIX] TASK 4 — Tighten the doc sync rule in CLAUDE.md

The current "Keep documentation in sync" rule is too broad. It tells Claude to
update security-posture files after any change, which risks unsupervised edits
to security documentation.

Replace the existing rule with this more precise version:

"**Keep documentation in sync:**
- README.md: update when commands, scripts, or user-facing behaviour changes
- CLAUDE.md: update when architecture, functions, or coding conventions change
- plans/security-posture.md and plans/security-posture-details.md: update ONLY
  when explicitly implementing or resolving a security control or gap. Do NOT
  modify these files as a side effect of unrelated changes (adding a config
  variable, fixing a bug, updating a profile, etc.). If a change has security
  implications but you were not asked to update the posture files, flag it in
  your response instead."

---

### [FIX] TASK 5 — Fix Permission modes classification in plans/security-posture.md

The row "Permission modes | HIGH | Supported" is misleading. These are
user-selected modes — the sandbox enforces nothing here.

Add an "Enforcement" column to the Application Layer (Claude) section table.
Insert it between the "Status" and "Check" columns.

Enforcement values:
- "Sandbox"        — enforced automatically regardless of user action
- "User"           — relies on user choosing correctly; not enforced by sandbox
- "Claude default" — Claude's own default behaviour; not a sandbox control

Apply to every row in the Application Layer table:
- Permission modes                → User
- Claude /sandbox mode            → Sandbox
- Sandbox network proxy           → Sandbox (when implemented)
- Command blocklist               → Claude default
- Per-project policies            → User
- Tool deny lists                 → User
- Worktree isolation              → User
- Write access restriction        → User
- Managed settings file           → Sandbox (when implemented)
- Managed policy CLAUDE.md        → Sandbox (when implemented)
- Sandbox fail-if-unavailable     → Sandbox (when implemented)
- Disable bypass permissions mode → Sandbox (when implemented)
- Managed-only permission rules   → Sandbox (when implemented)
- PreToolUse hooks                → Sandbox (when implemented)
- ConfigChange hooks              → Sandbox (when implemented)

Also add the Enforcement column to the User & Privilege table:
- Non-root default user     → Sandbox
- Password-gated sudo       → Sandbox
- Default password warning  → Sandbox
- Umask enforcement         → Sandbox
- Session timeout (TMOUT)   → User (not yet implemented — will become Sandbox after Task 6)

Preserve all existing column widths and alignment per CLAUDE.md table rules.

---

### [FIX] TASK 6 — Fix TMOUT bypass in plans/security-posture-details.md

In the "Session timeout (TMOUT)" section, the current implementation approach
sets TMOUT in the workflow script. This is bypassable with `unset TMOUT`.

Replace the entire Implementation approach section with:

"**Implementation approach:**

- Use `readonly TMOUT=N` not a plain assignment — readonly prevents `unset TMOUT`
  from bypassing it
- Deploy via `/etc/profile.d/session-timeout.sh` instead of the workflow script —
  this applies to every interactive shell, not just workflow sessions
- Add a `$SessionTimeout = 0` variable to sandbox-config.ps1 (0 = disabled)
- Wire token replacement into Install-Sandbox:
  deploy /etc/profile.d/session-timeout.sh with the value substituted at install time
- If $SessionTimeout is 0, deploy the file with TMOUT unset (no-op) or skip
  deploying it entirely
- Add check S-020 to Test-Sandbox:
  if $SessionTimeout > 0, verify /etc/profile.d/session-timeout.sh exists and
  contains the string 'readonly TMOUT'
- Once implemented: update Status in security-posture.md from 'Not Supported'
  to 'Supported' and Enforcement from 'User' to 'Sandbox'"

---

### [FIX] TASK 7 — Fix secret management caveat in plans/security-posture-details.md

In the "Secret management guidance" section, update the "What to cover" list.

Add these two items:

- "Environment variables are visible to all child processes spawned in that
  session, including Claude itself. This is acceptable for short-lived secrets
  but means Claude can read any secret you export as an env var. If a project
  requires secrets at runtime, prefer mounting it read-only and managing secrets
  outside the mount path using `pass` or `age`."

- "Never store secrets inside $ClaudePersistenceDir — Claude has full read
  access to this directory across all sessions, including future ones."

Do not change any other part of this section.

---

### [FIX] TASK 8 — Resolve multi-arch digest pinning open question
          in plans/security-posture-details.md

In the "Image digest pinning" section, find the two "Need to research" bullet
points about multi-arch manifests and replace them with:

"**Multi-arch digest pinning (resolved):**

- Pull the architecture-specific image explicitly:
  `podman pull --platform linux/amd64 debian:bookworm-slim`
- Get the platform-specific digest:
  `podman inspect --format '{{.Digest}}' debian:bookworm-slim`
- For ARM64 hosts: use `--platform linux/arm64` — the digest differs from amd64
- Pin in sandbox-config.ps1 as:
  `$DistroImage = 'debian:bookworm-slim@sha256:<your-digest>'`
- The digest is architecture-specific — document this in sandbox-config.example.ps1
  with a comment explaining users must re-pin for their platform
- `podman create` and `docker create` both accept digest-pinned references;
  no tag is required if a digest is present"

Also update the Implementation approach section:
- Remove the "(needs testing)" qualifier
- Add: "Add a WARN (not FAIL) check to Test-Sandbox: if $DistroImage does not
  contain '@sha256:', emit a warning that the image is not digest-pinned"

Do not change Status in security-posture.md — Status changes to Supported only
after the actual pinning is implemented in code, not just because the approach
is documented.

---

### [NEW FILE] TASK 10 — Create SECURITY.md

Create SECURITY.md at the project root. Max 120 lines.

Use these exact headings:

## What This Is
Two sentences. What Claude Sandbox is and what threat it is designed to address.
Do not oversell — be specific about what it reduces, not what it eliminates.

## Design Principles
Five bullets — the core security decisions:
- Defense-in-depth: multiple independent layers so no single misconfiguration
  exposes everything
- Least privilege: non-root default user, password-gated sudo, explicit RO/RW
  mount modes per project
- Honest gap documentation: known limitations are listed openly, not hidden
  (see Known Limitations below)
- Verifiable posture: every control is linked to a Test-Sandbox check code
  (e.g. S-001, S-007) so the security posture can be verified after any change
- Minimal blast radius: Windows interop disabled, automount disabled, Windows PATH
  excluded — Claude cannot reach the host filesystem except through explicit mounts

## Controls Summary
Table — columns: Category | Key Controls | Status

Rows:
- Host Isolation | WSL2 Hyper-V boundary; interop disabled (S-001); automount disabled (S-003); Windows PATH excluded (S-002) | Supported
- Filesystem | Mount-on-demand (fstab-only, S-019); explicit RO/RW per project; path traversal validation (S-012) | Supported
- Access Control | Non-root default user (S-006); password-gated sudo (S-007); umask enforcement (S-017) | Supported
- Process Containment | systemd as PID 1 (S-005); bubblewrap for Claude sandbox mode (S-009) | Supported
- Application Layer | Command blocklist; tool deny lists; per-project CLAUDE.md policies; worktree isolation | Partial — see posture matrix
- Audit & Logging | Timestamped bash history (S-018); git audit trail on projects | Partial — no kernel-level audit

Link at the end of this section:
"Full controls matrix with check codes: [plans/security-posture.md](plans/security-posture.md)"

## Known Limitations
Honest bullet list — do not soften any of these:
- No outbound network filtering at the host level (WSL2 NAT architecture constraint;
  see ADR-002)
- Sandbox network proxy for bash commands not yet configured — bash has unrestricted
  outbound access until deployed
- Claude's built-in tools (WebFetch) are not filtered by any sandbox control
- Claude Code installed via curl-pipe-bash with no checksum verification (see ADR-005)
- Container image not pinned to digest by default — floating tag pulls latest
- Claude Code self-updates automatically; no version pinning is available
- Claude has full read access to the persistence mount by design — any credentials
  stored there are accessible to Claude across all sessions

## Reporting Security Issues
"If you discover a security issue in this project, please open a GitHub issue
with the title prefix [SECURITY], or contact the maintainer directly before
disclosing publicly."

---

### [NEW FILE] TASK 11 — Create Architecture Decision Records

Create the folder docs/decisions/.

Create docs/decisions/README.md:
- First line: "Architecture Decision Records (ADRs) document significant design
  decisions, the context that drove them, and their security implications."
- Then a table: columns ADR | Title | Status | Date
  List all 5 ADRs below with status Accepted and date 2026-03-27

Use this exact format for every ADR file:
ADR-NNN: Title
Date: 2026-03-27
Status: Accepted

Context
Decision
Consequences
Security Implications
text

---

Create these 5 files:

**docs/decisions/ADR-001-wsl2-over-vm.md**

Context:
Claude Sandbox needs an isolated Linux environment on a Windows developer machine.
The options considered were WSL2 and a full hypervisor VM (Hyper-V, VirtualBox,
or VMware). The environment must support Claude Code's bubblewrap sandbox mode,
mount Windows project folders on demand, and start quickly enough for daily use.

Decision:
Use WSL2. The Hyper-V-backed VM boundary provides meaningful isolation for the
primary threat (containment of Claude's actions), while drvfs mounts, fast startup,
and native Windows Terminal integration make it practical for daily development.

Consequences:
- Install is a one-command PowerShell script; no VM image management
- Projects mount instantly via drvfs with no syncing
- WSL2 starts in seconds vs minutes for a full VM
- Windows interop, automount, and Windows PATH must be explicitly disabled
  (done — S-001, S-002, S-003) because they are enabled by default and would
  break the isolation boundary

Security Implications:
WSL2 is not as isolated as a full VM. A full hypervisor VM with no shared
clipboard, no shared filesystem, and no guest additions would provide stronger
containment. The trade-off was made in favour of usability for daily developer
use. A kernel-level exploit in WSL2 could theoretically break containment to the
Windows host. This risk is accepted — the primary threat model is Claude acting
outside its intended scope, not a kernel exploit. If the threat model changes
(e.g. running untrusted third-party code at scale), a full VM should be
reconsidered.

---

**docs/decisions/ADR-002-no-iptables.md**

Context:
A key goal is preventing Claude or code it runs from exfiltrating data over the
network. The obvious Linux approach is iptables rules inside the WSL2 distro.

Decision:
Do not rely on iptables inside WSL2 for outbound filtering. Instead:
- Rely on Claude's sandbox network proxy (allowedDomains) for bash commands
  (planned — not yet deployed)
- Accept that Claude's built-in tools (WebFetch) are unfiltered
- Document host-level options (Windows Firewall, host-side proxy) in safe-usage.md
  but do not automate them from inside the sandbox

Consequences:
- No outbound network filtering is active today for bash commands (gap tracked
  in security-posture.md as HIGH / Not Supported)
- When sandbox network proxy is deployed, bash commands will be domain-filtered
- WebFetch remains unfiltered — this is an accepted residual risk

Security Implications:
iptables inside WSL2 has two fundamental problems:

1. In NAT mode (default): the virtual network adapter is recreated on every WSL
   restart. iptables rules can be restored via a systemd service, but they bind
   to an adapter that may not exist in the same state after restart, making them
   fragile in practice.

2. In mirrored networking mode (Windows 11 22H2+): WSL2 shares the host's
   physical network interfaces directly. iptables rules inside the distro affect
   host-level interfaces, making automation dangerous and behaviour unpredictable.
   Multiple open issues in the WSL2 GitHub repository document interface
   disappearance and instability in mirrored mode.

The maintenance burden and fragility outweigh the security benefit for a local
developer sandbox. Host-level Windows Firewall rules are the correct layer for
network egress control, but their management is outside the scope of this project
and must be handled by the user.

---

**docs/decisions/ADR-003-password-gated-sudo.md**

Context:
This is a local developer sandbox. The user owns the machine and knows the sudo
password. The question is: why enforce password-gated sudo instead of NOPASSWD,
which would be more convenient?

Decision:
Require a password for all sudo operations. No NOPASSWD entries in sudoers.

Consequences:
- Slight friction when the user legitimately needs to run a sudo command
- Claude cannot escalate to root without a human typing a password
- Verified by check S-007; Test-Sandbox will fail if NOPASSWD is found

Security Implications:
The password requirement is not for the user — it is a control against Claude.
Prompt injection is a realistic attack vector: malicious content in a project
file or a web page Claude fetches could instruct Claude to run a sudo command.
Without a password requirement, Claude could execute that instruction
autonomously, particularly in an unattended session.

The design principle here is that security controls must not depend on Claude
behaving correctly. Claude may be prompt-injected, hallucinating, or
misunderstanding its scope. The sudo password is a hard control that requires
a human to be present and consenting before any privilege escalation occurs.

---

**docs/decisions/ADR-004-persistence-mount.md**

Context:
Claude Code stores its state — login credentials, memory, conversation history,
settings, and tool permissions — in a ~/.claude directory. If this directory is
inside the WSL2 distro, it is destroyed every time the distro is rebuilt.
Rebuilding the distro (to apply updates or reset a compromised environment) would
require re-authentication and lose all Claude memory and settings.

Decision:
Bind-mount ~/.claude from a Windows directory ($ClaudePersistenceDir) via
/etc/fstab. The directory persists on the Windows host across all distro rebuilds.
A symlink ~/.claude.json -> ~/.claude/.claude.json ensures Claude's top-level
config file is also persisted.

Consequences:
- Claude login, memory, and settings survive distro rebuilds
- Recovery from a bad state is: rebuild distro, run installer, everything works
- The persistence directory is always mounted read-write — Claude can write to it

Security Implications:
This is the primary security trade-off in the persistence design. Claude has full
read and write access to its own settings, conversation history, API credentials,
and tool permission rules via the persistence mount. A compromised Claude session
could:
- Read conversation history from previous sessions
- Widen its own tool permissions for future sessions by modifying settings.json
- Read the Claude API key stored in the directory

Mitigations considered and their outcomes:
- Read-only mount: rejected — Claude cannot function with a read-only ~/.claude
- Per-file ACLs: not supported by drvfs at the file level
- Separate read-only mount for credentials: not supported by Claude Code's
  directory structure
- Managed settings file (planned): will enforce deny rules at the application
  layer regardless of what settings.json contains, partially mitigating the
  permission-widening risk

This risk is accepted as a necessary trade-off for the persistence feature.
Users should be aware that Claude can read all files in $ClaudePersistenceDir.

---

**docs/decisions/ADR-005-curl-pipe-bash.md**

Context:
Claude Code is installed using Anthropic's official installer:
  curl -fsSL https://claude.ai/install.sh | bash

This pattern (curl-pipe-bash) downloads and immediately executes a shell script
with no checksum verification, no signature check, and no opportunity to inspect
the script before it runs.

Decision:
Use the official Anthropic installer as-is. No alternative distribution mechanism
exists. An interim improvement — downloading the script to a temp file before
executing it — allows the user to inspect the content but provides no security
guarantee since there is no known-good hash to verify against.

Consequences:
- Install is straightforward and tracks Anthropic's official distribution
- No version pinning — the script installs whatever Claude Code version is
  current at install time
- Users who want to inspect the script can download it first manually

Security Implications:
HTTPS protects against network-level MITM but does not protect against:
- Server-side compromise of claude.ai
- CDN poisoning
- Time-of-check / time-of-use substitution between download and execution

The hash changes with every Claude Code release, making a known-good comparison
impractical without a publisher-maintained checksum file (which Anthropic does
not currently provide).

This risk is accepted because:
1. No alternative distribution exists
2. The blast radius is limited — the installer runs inside the WSL2 sandbox,
   not on the Windows host
3. Anthropic is a trusted vendor for this tool

Condition for revisiting this decision:
If Anthropic publishes Claude Code via a package manager (apt, npm, brew, or
winget), that distribution should be used instead. Package manager distributions
provide cryptographic verification, version pinning, and reproducible installs.
Monitor https://github.com/anthropics/claude-code for distribution updates.

---

### FINAL CHECKS

Run these after all tasks are complete:

1. Verify .gitignore exists and contains sandbox-config.ps1
2. Verify sandbox-config.example.ps1 exists and contains no real credentials
   or machine-specific paths. Search for "yourpassword" — must not appear anywhere.
3. Verify all new files appear in the CLAUDE.md Key Files / Documentation table:
   - sandbox-config.example.ps1
   - .gitignore
   - SECURITY.md
   - docs/decisions/README.md
   - docs/decisions/ADR-001 through ADR-005
4. Verify SECURITY.md is listed in README.md under a new "Security" section:
   "See [SECURITY.md](SECURITY.md) for the security posture summary."
   Note: docs/threat-model.md and PURPOSE.md are handled in a separate instruction.
5. Verify no task introduced a claim in any document that is not backed by
   actual implemented code. If a control is planned but not yet implemented,
   it must be described as planned, not supported.
6. Verify the Enforcement column was added to security-posture.md tables without
   breaking column alignment (per CLAUDE.md table formatting rules).
7. List every file created or modified with a one-line summary of what changed.
Before You Run This
Two things to check:

1. Task numbering — Task 9 is intentionally skipped. If Claude comments on the gap between Task 8 and Task 10, that's fine — it won't affect execution. You can add a line after Task 8 if you want to be explicit:

### TASK 9 — Skipped
## (threat-model.md and PURPOSE.md are handled in a separate instruction)
2. Run order — Run this session before the PURPOSE.md/threat-model.md session. The SECURITY.md created here will be referenced by the threat model's Section 8, so it needs to exist first.