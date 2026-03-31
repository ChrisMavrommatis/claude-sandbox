# Security Posture

> For research notes on unsupported items see [security-research.md](security-research.md)

## Check Code System

Every control that can be verified programmatically is assigned a check code and tested
by `Test-Sandbox.ps1` after installation. Controls marked Yes without a check code
are verified by design (e.g. inherent to WSL2) or by inspection rather than automated test.

- **I-NNN** - Installation checks: verify the installer produced the expected state
  (user exists, packages installed, files deployed, mounts configured).
- **S-NNN** - Security checks: verify the security posture of the running system
  (permissions, hardening settings, policy enforcement, hook behaviour).

## Host Isolation

| Name                       | Description                                                                   | Impact | Supported | Enforced by | Check |
|----------------------------|-------------------------------------------------------------------------------|--------|-----------|-------------|-------|
| WSL2 hypervisor boundary   | Distro runs in a lightweight VM backed by the Hyper-V hypervisor              | HIGH   | Yes       | WSL2        | -     |
| Windows interop disabled   | Cannot run Windows executables from inside the distro                         | HIGH   | Yes       | Distro      | S-001 |
| Windows PATH excluded      | No Windows executables leak into Linux `$PATH`                                | HIGH   | Yes       | Distro      | S-002 |
| Automount disabled         | Windows drives not mounted automatically at boot                              | HIGH   | Yes       | Distro      | S-003 |
| Outbound network filtering | Firewall rules or proxy to control what the distro can reach on the internet  | HIGH   | No        | -           | -     |
| Binary format protection   | `protectBinfmt = true` prevents registering binfmt handlers on host kernel    | MEDIUM | Yes       | Distro      | S-004 |
| GPU passthrough toggle     | Controlled by `$GpuEnabled` config variable; default off                      | LOW    | Yes       | Distro      | S-014 |

---

## Filesystem

| Name                       | Description                                                        | Impact | Supported | Enforced by | Check        |
|----------------------------|--------------------------------------------------------------------|--------|-----------|-------------|--------------|
| fstab-only mounts          | Only `/etc/fstab` entries are mounted; no automatic drive access   | HIGH   | Yes       | Distro      | S-019        |
| Persistence mount security | `~/.claude` mounted with `uid`/`gid`, `umask=022`, `metadata`      | MEDIUM | Yes       | Distro      | S-010, S-011 |
| Project mount modes        | Projects mounted with explicit `--ro` or `--rw`; remount detection | MEDIUM | Yes       | User        | -            |
| Project name validation    | Rejects names with `/`, `\`, or `..` to block path traversal       | MEDIUM | Yes       | Distro      | S-012        |
| Persistence symlink        | `~/.claude.json` -> `~/.claude/.claude.json` survives rebuilds     | LOW    | Yes       | Distro      | I-010        |

---

## User & Privilege

| Name                         | Description                                                                  | Impact | Supported | Enforced by | Check        |
|------------------------------|------------------------------------------------------------------------------|--------|-----------|-------------|--------------|
| Non-root default user        | WSL distro runs as regular user, not root                                    | HIGH   | Yes       | Distro      | S-006        |
| Password-gated sudo          | `sudo` requires password; no `NOPASSWD` entries                              | HIGH   | Yes       | Distro      | S-007        |
| Default password warning     | Installer warns and prompts if password is still `changeme`                  | MEDIUM | Yes       | Distro      | S-013        |
| File permission verification | `wsl.conf` and `sudoers.d/pwfeedback` checked for correct ownership and mode | MEDIUM | Yes       | Distro      | S-015, S-016 |
| Umask enforcement            | `umask 022` set in shell profiles to prevent world-writable files            | LOW    | Yes       | Distro      | S-017        |
| Sudo password feedback       | Visual feedback during password entry via `pwfeedback`                       | LOW    | Yes       | Distro      | S-008        |
| Safe password handling       | Password piped to `chpasswd` via temp file, not in command args              | LOW    | Yes       | Distro      | -            |
| Session timeout (TMOUT)      | Auto-close idle shells after configurable period                             | LOW    | Yes       | Distro      | S-020        |
| Sudo brute-force limiting    | PAM lockout after failed sudo attempts                                       | LOW    | No        | -           | -            |

---

## Process Containment

| Name                  | Description                                                 | Impact | Supported | Enforced by | Check |
|-----------------------|-------------------------------------------------------------|--------|-----------|-------------|-------|
| systemd as PID 1      | Proper cgroup management and service supervision            | MEDIUM | Yes       | Distro      | S-005 |
| Bubblewrap namespaces | `bwrap` installed for Claude's internal sandbox mode        | MEDIUM | Yes       | Distro      | S-009 |
| Resource limits       | CPU, memory, disk quotas via `.wslconfig` or systemd slices | MEDIUM | No        | -           | -     |
| AppArmor profiles     | Per-process MAC restricting filesystem and network access   | LOW    | No        | -           | -     |

---

## Application Layer

| Name                            | Description                                                                                    | Impact | Supported | Enforced by      | Check |
|---------------------------------|------------------------------------------------------------------------------------------------|--------|-----------|------------------|-------|
| Permission modes                | `plan` / `acceptEdits` / `--dangerously-skip-permissions` per session                          | HIGH   | Yes       | User             | -     |
| Claude `/sandbox` mode          | Filesystem and network isolation for bash commands via bubblewrap                              | HIGH   | Yes       | Distro           | S-009 |
| Sandbox network proxy           | Domain-level filtering via `allowedDomains`; applies when Claude sandbox mode is active        | HIGH   | Yes       | Distro           | I-013 |
| Managed settings file           | Organisation-wide permissions via `/etc/claude-code/managed-settings.json`                     | MEDIUM | Yes       | Distro           | I-013 |
| Managed policy CLAUDE.md        | Organisation-wide rules deployed to `/etc/claude-code/CLAUDE.md`                               | MEDIUM | Yes       | Distro           | I-014 |
| PreToolUse hooks                | Runtime hooks that block specific tool calls before execution                                  | MEDIUM | Yes       | Distro           | I-015 |
| Write access restriction        | Claude can only write to the directory where it was started and its subdirectories             | MEDIUM | Yes       | Claude Code      | -     |
| Command blocklist               | Catastrophic commands denied in all tiers; `curl`/`wget`/installs in restrictive+              | MEDIUM | Yes       | Managed settings | S-021 |
| Per-project policies            | `CLAUDE.md` declares off-limits paths, branch rules, constraints                               | MEDIUM | Yes       | User             | -     |
| Tool deny lists                 | `~/.claude/settings.json` permanently blocks specific commands                                 | MEDIUM | Yes       | User             | -     |
| Worktree isolation              | `claude -w` works on a separate branch; main untouched                                         | MEDIUM | Yes       | Claude Code      | -     |
| Sandbox fail-if-unavailable     | `sandbox.failIfUnavailable` makes Claude sandbox mode a hard requirement                       | MEDIUM | No        | -                | -     |
| Disable bypass permissions mode | Prevent use of `bypassPermissions` via managed settings                                        | MEDIUM | No - non-goal. Users must be able to run `--dangerously-skip-permissions`. See ADR-009. | - | - |
| Managed-only permission rules   | `allowManagedPermissionRulesOnly` prevents user/project allow rules                            | MEDIUM | No - under investigation. Local enforcement of `allowManagedPermissionRulesOnly` is unverified. See ADR-009, security-research.md I-001. | - | - |
| ConfigChange hooks              | Hooks to audit or block settings changes during sessions                                       | LOW    | No        | -                | -     |
| Claude Code auto-updates        | Version pinning or rollback for Claude Code itself                                             | LOW    | No        | -                | -     |

---

## Audit & Logging

| Name                 | Description                                                | Impact | Supported | Enforced by | Check |
|----------------------|------------------------------------------------------------|--------|-----------|-------------|-------|
| Git audit trail      | All Claude changes tracked and reversible via git          | MEDIUM | Yes       | User        | -     |
| System audit logging | `auditd` / `syslog` for commands, mounts, process spawning | MEDIUM | No        | -           | -     |
| History timestamps   | `HISTTIMEFORMAT` set in profiles for command audit trail   | LOW    | Yes       | Distro      | S-018 |

---

## Deployment Integrity

| Name                          | Description                                                          | Impact | Supported | Enforced by | Check |
|-------------------------------|----------------------------------------------------------------------|--------|-----------|-------------|-------|
| Token replacement             | `__TOKEN__` placeholders replaced at deploy time; no hardcoded paths | MEDIUM | Yes       | Distro      | -     |
| Image digest pinning          | Container image pinned to `@sha256:` digest for reproducibility      | MEDIUM | No        | -           | -     |
| Claude Code install integrity | Verify checksum/signature of Claude install script before running    | MEDIUM | No        | -           | -     |
| Line ending normalization     | Scripts written as LF / UTF-8 no-BOM before copying to distro        | LOW    | Yes       | Distro      | -     |

> S-022 warns when the image is not digest-pinned.

---

## Admin Operations

| Name                       | Description                                                     | Impact | Supported | Enforced by | Check |
|----------------------------|-----------------------------------------------------------------|--------|-----------|-------------|-------|
| Admin elevation required   | All scripts check for Administrator and exit if not elevated    | HIGH   | Yes       | Distro      | -     |
| Post-install verification  | `Test-Sandbox.ps1` runs automated checks at end of install      | HIGH   | Yes       | Distro      | -     |
| Update mechanism           | Planned; removed pending reimplementation                       | MEDIUM | No        | -           | -     |
| Safe uninstall             | Confirmation prompts; persistence directory never deleted       | MEDIUM | Yes       | Distro      | -     |
| Temp file cleanup          | Container tarball, staging files removed after install          | LOW    | Yes       | Distro      | -     |
| Secret management guidance | Where to store API keys, `.env` handling, recommended tools     | LOW    | Yes       | User        | -     |
| Backup strategy            | What to back up, how often, recovery procedure                  | LOW    | Yes       | User        | -     |
