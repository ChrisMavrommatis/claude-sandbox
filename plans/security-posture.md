# Security Posture

> For research notes on unsupported items see [security-posture-details.md](security-posture-details.md)

## Host Isolation

| Name                       | Description                                                                        | Impact | Status        | Check |
| -------------------------- | ---------------------------------------------------------------------------------- | ------ | ------------- | ----- |
| WSL2 hypervisor boundary   | Sandbox runs in a lightweight VM backed by the Hyper-V hypervisor                  | HIGH   | Supported     | -     |
| Windows interop disabled   | Cannot run Windows executables from inside the distro                              | HIGH   | Supported     | S-001 |
| Windows PATH excluded      | No Windows executables leak into Linux `$PATH`                                     | HIGH   | Supported     | S-002 |
| Automount disabled         | Windows drives not mounted automatically at boot                                   | HIGH   | Supported     | S-003 |
| Outbound network filtering | Firewall rules or proxy to control what the sandbox can reach on the internet      | HIGH   | Not Supported | -     |
| Binary format protection   | `protectBinfmt = true` prevents registering binfmt handlers on host kernel         | MEDIUM | Supported     | S-004 |

## Filesystem

| Name                       | Description                                                        | Impact | Status    | Check        |
| -------------------------- | ------------------------------------------------------------------ | ------ | --------- | ------------ |
| fstab-only mounts          | Only `/etc/fstab` entries are mounted; no automatic drive access   | HIGH   | Supported | S-019        |
| Persistence mount security | `~/.claude` mounted with `uid`/`gid`, `umask=022`, `metadata`      | MEDIUM | Supported | S-010, S-011 |
| Project mount modes        | Projects mounted with explicit `--ro` or `--rw`; remount detection | MEDIUM | Supported | -            |
| Project name validation    | Rejects names with `/`, `\`, or `..` to block path traversal       | MEDIUM | Supported | S-012        |
| Persistence symlink        | `~/.claude.json` -> `~/.claude/.claude.json` survives rebuilds     | LOW    | Supported | I-010        |

## User & Privilege

| Name                         | Description                                                                  | Impact | Status        | Check        |
| ---------------------------- | ---------------------------------------------------------------------------- | ------ | ------------- | ------------ |
| Non-root default user        | WSL distro runs as regular user, not root                                    | HIGH   | Supported     | S-006        |
| Password-gated sudo          | `sudo` requires password; no `NOPASSWD` entries                              | HIGH   | Supported     | S-007        |
| Default password warning     | Installer warns and prompts if password is still `changeme`                  | MEDIUM | Supported     | S-013        |
| File permission verification | `wsl.conf` and `sudoers.d/pwfeedback` checked for correct ownership and mode | MEDIUM | Supported     | S-015, S-016 |
| Umask enforcement            | `umask 022` set in shell profiles to prevent world-writable files            | LOW    | Supported     | S-017        |
| Sudo password feedback       | Visual feedback during password entry via `pwfeedback`                       | LOW    | Supported     | S-008        |
| Safe password handling       | Password piped to `chpasswd` via temp file, not in command args              | LOW    | Supported     | -            |
| Session timeout (TMOUT)      | Auto-close idle shells after configurable period                             | LOW    | Not Supported | -            |
| Sudo brute-force limiting    | PAM lockout after failed sudo attempts                                       | LOW    | Not Supported | -            |

## Process Containment

| Name                  | Description                                                       | Impact | Status        | Check |
| --------------------- | ----------------------------------------------------------------- | ------ | ------------- | ----- |
| systemd as PID 1      | Proper cgroup management and service supervision                  | MEDIUM | Supported     | S-005 |
| Bubblewrap namespaces | `bwrap` installed for Claude's internal sandbox mode              | MEDIUM | Supported     | S-009 |
| Resource limits       | CPU, memory, disk quotas via `.wslconfig` or systemd slices       | MEDIUM | Not Supported | -     |

## GPU

| Name                   | Description                                                  | Impact | Status    | Check |
| ---------------------- | ------------------------------------------------------------ | ------ | --------- | ----- |
| GPU passthrough toggle | Controlled by `$GpuEnabled` config variable; default off     | LOW    | Supported | S-014 |

## Deployment Integrity

| Name                          | Description                                                            | Impact | Status        | Check |
| ----------------------------- | ---------------------------------------------------------------------- | ------ | ------------- | ----- |
| Token replacement             | `__TOKEN__` placeholders replaced at deploy time; no hardcoded paths   | MEDIUM | Supported     | -     |
| Image digest pinning          | Container image pinned to `@sha256:` digest for reproducibility        | MEDIUM | Not Supported | -     |
| Claude Code install integrity | Verify checksum/signature of Claude install script before running      | MEDIUM | Not Supported | -     |
| Line ending normalization     | Scripts written as LF / UTF-8 no-BOM before copying to distro          | LOW    | Supported     | -     |

## Audit & Logging

| Name                 | Description                                                        | Impact | Status        | Check |
| -------------------- | ------------------------------------------------------------------ | ------ | ------------- | ----- |
| Git audit trail      | All Claude changes tracked and reversible via git                  | MEDIUM | Supported     | -     |
| System audit logging | `auditd` / `syslog` for commands, mounts, process spawning         | MEDIUM | Not Supported | -     |
| History timestamps   | `HISTTIMEFORMAT` set in profiles for command audit trail           | LOW    | Supported     | S-018 |

## Application Layer (Claude)

| Name                            | Description                                                                     | Impact | Status        | Check |
| ------------------------------- | ------------------------------------------------------------------------------- | ------ | ------------- | ----- |
| Permission modes                | `plan` / `acceptEdits` / `--dangerously-skip-permissions` per session           | HIGH   | Supported     | -     |
| Claude `/sandbox` mode          | Filesystem and network isolation for bash commands via bubblewrap               | HIGH   | Supported     | S-009 |
| Sandbox network proxy           | Domain-level network filtering for sandboxed bash commands via `allowedDomains` | HIGH   | Not Supported | -     |
| Managed settings file           | Organization-wide permissions via `/etc/claude-code/managed-settings.json`      | MEDIUM | Not Supported | -     |
| Managed policy CLAUDE.md        | Organization-wide rules deployed to `/etc/claude-code/CLAUDE.md` in sandbox     | MEDIUM | Not Supported | -     |
| Sandbox fail-if-unavailable     | `sandbox.failIfUnavailable` makes sandbox a hard requirement                    | MEDIUM | Not Supported | -     |
| Disable bypass permissions mode | Prevent users from using `bypassPermissions` via managed settings               | MEDIUM | Not Supported | -     |
| Managed-only permission rules   | `allowManagedPermissionRulesOnly` prevents user/project allow rules             | MEDIUM | Not Supported | -     |
| PreToolUse hooks                | Runtime hooks that can block specific tool calls before execution               | MEDIUM | Not Supported | -     |
| Write access restriction        | Claude can only write to the folder where it was started and subfolders         | MEDIUM | Supported     | -     |
| Command blocklist               | `curl` and `wget` blocked by default in Claude; defense-in-depth                | MEDIUM | Supported     | -     |
| Per-project policies            | `CLAUDE.md` declares off-limits paths, branch rules, constraints                | MEDIUM | Supported     | -     |
| Tool deny lists                 | `~/.claude/settings.json` permanently blocks specific commands                  | MEDIUM | Supported     | -     |
| Worktree isolation              | `claude -w` works on a separate branch; main untouched                          | MEDIUM | Supported     | -     |
| ConfigChange hooks              | Hooks to audit or block settings changes during sessions                        | LOW    | Not Supported | -     |
| Claude Code auto-updates        | Version pinning or rollback for Claude Code itself                              | LOW    | Not Supported | -     |

## Admin Operations

| Name                       | Description                                                          | Impact | Status    | Check |
| -------------------------- | -------------------------------------------------------------------- | ------ | --------- | ----- |
| Admin elevation required   | All scripts check for Administrator and exit if not elevated         | HIGH   | Supported | -     |
| Post-install verification  | `Test-Sandbox` runs automated checks at end of install               | HIGH   | Supported | -     |
| Update mechanism           | `Update-Sandbox` runs apt upgrade, re-deploys profiles, verifies     | MEDIUM | Supported | -     |
| Safe uninstall             | Confirmation prompts; persistence directory never deleted            | MEDIUM | Supported | -     |
| Temp file cleanup          | Container tarball, staging files removed after install               | LOW    | Supported | -     |

## Documentation

| Name                        | Description                                                    | Impact | Status        | Check |
| --------------------------- | -------------------------------------------------------------- | ------ | ------------- | ----- |
| Secret management guidance  | Where to store API keys, .env handling, recommended tools      | LOW    | Not Supported | -     |
| Backup strategy             | What to back up, how often, recovery procedure                 | LOW    | Not Supported | -     |
