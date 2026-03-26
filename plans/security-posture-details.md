# Security Posture - Details

> Summary view: [security-posture.md](security-posture.md)

---

## Controls In Place

### Host Isolation

- WSL2 hypervisor boundary separates the sandbox from the Windows host
- Windows interop disabled (`interop.enabled = false`) - cannot run Windows executables from inside the distro `[S-001]`
- Windows PATH excluded (`appendWindowsPath = false`) - no Windows executables leak into Linux `$PATH` `[S-002]`
- Automatic Windows drive mounting disabled (`automount.enabled = false`) `[S-003]`
- `protectBinfmt = true` - prevents the distro from registering binary formats on the host kernel (blocks a class of container escape) `[S-004]`

### Filesystem

- No Windows drives auto-mounted at boot; all access is on-demand via explicit commands
- Only `/etc/fstab` entries are mounted (`mountFsTab = true`)
- Persistence mount (`~/.claude`) uses `drvfs` with dynamic `uid`/`gid`, `umask=022`, `metadata` `[S-010, S-011]`
- Symlink `~/.claude.json` -> `~/.claude/.claude.json` ensures Claude's config survives distro rebuilds `[I-010]`
- Project mounts support explicit `--ro` (read-only) or `--rw` (read-write) modes
- `index-projects` mounts the Windows projects folder read-only for directory listing, then unmounts
- Remount detection: if a project is already mounted with a different mode it is unmounted and remounted with the correct mode
- `unmount-project` changes out of the project directory before unmounting to avoid "device busy" errors
- Project name validation rejects names containing `/`, `\`, or `..` to prevent path traversal `[S-012]`

### User & Privilege

- Default WSL user is non-root `[S-006]`
- Sudo requires a password - the user is in the `sudo` group but `NOPASSWD` is not set `[S-007]`
- Sudo password feedback enabled via `/etc/sudoers.d/pwfeedback` `[S-008]`
- Home directory created with `useradd -m` (standard ownership)
- Default umask `0022` - new files are not world-writable
- Installer warns if password is still the default value and requires confirmation to proceed `[S-013]`

### Process Containment

- systemd runs as PID 1 (proper cgroup management and service supervision) `[S-005]`
- bubblewrap (`bwrap`) installed for Claude's internal sandbox mode (Linux namespace isolation)
- Unprivileged user namespaces available so bubblewrap works without root `[S-009]`

### GPU Access

- GPU passthrough controlled by `$GpuEnabled` config variable (default: `$false`) `[S-014]`
- Only enabled when explicitly set by user - reduces attack surface when GPU is not needed

### Workflow Safeguards

- `__TOKEN__` placeholders (e.g. `__PROJECTS_DRVFS__`, `__GpuEnabled__`) are replaced with actual values at deploy time - no paths or settings hardcoded in shell scripts
- Scripts are normalised to LF line endings and written as UTF-8 without BOM before being copied into the distro
- Profile and workflow scripts are only sourced if the file exists (`[ -f ... ] && source`)
- Bash profiles skip all setup for non-interactive shells

### File Permissions

- Persistence mount enforces ownership and `umask=022` via fstab mount options
- Project mounts enforce the same ownership and umask regardless of the Windows-side permissions

### Application Layer

- Claude permission modes let you dial autonomy per session:
  - `plan` - read and plan only, no changes
  - `acceptEdits` - can edit files, asks before running commands
  - `--dangerously-skip-permissions` - full autonomy (safe here because isolation is at the environment level)
- `CLAUDE.md` per-project policies: declare off-limits paths, branch rules, or any plain-language constraints
- `~/.claude/settings.json` deny lists permanently block specific tools or commands (e.g. `Bash(rm -rf:*)`)
- Worktree mode (`claude -w`) puts Claude on a separate branch - main is untouched until you merge
- Git provides a full, auditable trail of every change Claude makes

### Admin Operations

- All PowerShell scripts check for Administrator elevation at startup and exit immediately if not elevated
- Required source files are validated with `Test-Path` before the installer does any work
- Uninstall requires explicit confirmation before each destructive step (default answer: No)
- Persistence directory (`$ClaudePersistenceDir`) is explicitly preserved on uninstall - never deleted
- Temporary files (container rootfs tarball, fstab staging fragments) are deleted at the end of installation
- The container and pulled image are removed from the container runtime after the rootfs is exported

### Verification & Updates

- `Test-Sandbox` runs 26 automated checks (12 installation, 14 security) identified by codes `I-001` through `I-012` and `S-001` through `S-014`
- Verification runs automatically at the end of installation (Step 7)
- `Update-Sandbox` provides a patch mechanism: updates packages, re-deploys profiles, and verifies

---

## Gaps & Missing Controls

### 1 - No outbound network filtering `HIGH`

No firewall rules, DNS filtering, or proxy configuration. Any process inside the sandbox can reach any internet host freely. A compromised dependency or tool can exfiltrate data with nothing blocking it.

**What would fix it:** A per-distro `iptables`/`nftables` allowlist, or a `.wslconfig` HTTP proxy pointing to an inspecting proxy on the host.

---

### 2 - No resource limits `MEDIUM`

No CPU, memory, or disk quotas applied to the distro. A runaway process (e.g. an infinite loop, a large build) can exhaust host RAM or disk. No `.wslconfig` template is provided or documented.

**What would fix it:** A documented `.wslconfig` with `memory=`, `processors=`, and `swap=` values. Optionally systemd slice limits inside the distro.

---

### 3 - No audit logging `MEDIUM`

No `auditd`, `syslog` forwarding, or mount event tracking beyond what git records. If something goes wrong there is no record of what commands ran, what was mounted, or what processes were spawned.

**What would fix it:** Enable `auditd` or `rsyslog` in the distro. Forward logs to a file on the persistence mount so they survive rebuilds.

---

### 4 - No image digest pinning `MEDIUM`

`debian:bookworm-slim` is a floating tag. Each install pulls whatever the registry serves at that moment. There is no `@sha256:` digest and no signature check.

**What would fix it:** Pin the image to a known digest in `sandbox-config.ps1` (e.g. `debian:bookworm-slim@sha256:<hash>`). Re-pin intentionally when updating.

---

### 5 - Claude installer uses curl-pipe-bash `MEDIUM`

The installer runs `curl -fsSL https://claude.ai/install.sh | bash` with no checksum or signature verification. HTTPS protects the download in transit but does not guarantee the script hasn't changed between installs or that the server wasn't compromised.

**What would fix it:** Download the script to a temp file, display its hash, and require confirmation before executing - or use an offline package if one becomes available.

---

### 6 - No session timeout `LOW`

No `TMOUT` variable is set in any profile. Idle shells stay open indefinitely. On a shared or unattended machine this leaves an authenticated session exposed.

**What would fix it:** Set `TMOUT=900` (15 minutes) in `profiles/default.sh` or document it as a recommended hardening step.

---

### 7 - No secret management guidance `LOW`

No documentation or tooling for handling API keys, tokens, or `.env` files. Users may store secrets inside the persistence mount or checked-in project files without realising the exposure.

**What would fix it:** A section in `docs/security.md` covering where not to put secrets, how to use environment variables safely, and recommending a tool like `pass` or `age`.

---

### 8 - No backup strategy documented `LOW`

The persistence mount (`~/.claude`) survives distro rebuilds but there is no guidance on how often to back it up, how to verify its integrity, or how to recover if the Windows folder is deleted or corrupted.

**What would fix it:** A brief section in the docs noting what lives in the persistence directory and recommending a backup approach (e.g. robocopy to a second location, or inclusion in an existing backup job).

---

## Additional Risks (identified during security review, not yet in gap list)

### 9 - File permissions not verified `MEDIUM`

Test-Sandbox checks that files exist but not their permissions. `/etc/wsl.conf` and `/etc/sudoers.d/pwfeedback` should be owned by root and not world-writable. A non-root user could modify these to weaken security.

**What would fix it:** Add S-015 and S-016 checks to Test-Sandbox verifying ownership and permission bits. See [security-improvements.md](security-improvements.md) item A.

---

### 10 - No umask enforcement in shell profiles `LOW`

Global umask=022 is set at the mount level but the shell profiles don't reinforce it. A user could change umask to 0, making new files world-readable/writable.

**What would fix it:** Add explicit `umask 022` to both `default.sh` and `pretty.sh` profiles. Add S-017 check. See [security-improvements.md](security-improvements.md) item B.

---

### 11 - Symlink escape from project mounts `LOW-MEDIUM`

Projects mounted via drvfs at `/home/dev/projects/<name>`. Malicious code in a project could create Linux symlinks pointing outside the project directory (e.g. `../../.claude`), potentially accessing the persistence mount or other sensitive paths.

**What would fix it:** Add `-o nosymfollow` to mount options if supported by drvfs, or validate resolved paths don't escape `$PROJECTS_HOME`. See [security-improvements.md](security-improvements.md) item J.

---

### 12 - Password visible in process list during install `LOW`

`chpasswd` receives the password as a command-line argument via `Invoke-InSandbox`, which could briefly appear in the process list.

**What would fix it:** Pipe password to chpasswd via stdin instead of command arg. See [security-improvements.md](security-improvements.md) item F.

---

### 13 - No failed sudo attempt limiting `LOW`

No PAM lockout configuration. A process could brute-force the sudo password with no rate limiting or account lockout.

**Not planned:** Risk of locking yourself out of the sandbox outweighs the benefit for a local dev environment.

---

### 14 - Claude Code auto-updates outside sandbox control `LOW`

Claude Code installed via curl-pipe-bash updates itself automatically. Updates could introduce vulnerabilities. No version pinning or rollback mechanism exists.

**Not fixable:** External tool managed by Anthropic. No practical mechanism to pin versions.
