# Security Posture — Details

> Summary view: [security-posture.md](security-posture.md)

---

## Controls In Place

### Host Isolation

- WSL2 hypervisor boundary separates the sandbox from the Windows host
- Windows interop disabled (`interop.enabled = false`) — cannot run Windows executables from inside the distro
- Windows PATH excluded (`appendWindowsPath = false`) — no Windows executables leak into Linux `$PATH`
- Automatic Windows drive mounting disabled (`automount.enabled = false`)
- `protectBinfmt = true` — prevents the distro from registering binary formats on the host kernel (blocks a class of container escape)

### Filesystem

- No Windows drives auto-mounted at boot; all access is on-demand via explicit commands
- Only `/etc/fstab` entries are mounted (`mountFsTab = true`)
- Persistence mount (`~/.claude`) uses `drvfs` with `uid=1000`, `gid=1000`, `umask=022`
- Symlink `~/.claude.json → ~/.claude/.claude.json` ensures Claude's config survives distro rebuilds
- Project mounts support explicit `--ro` (read-only) or `--rw` (read-write) modes
- `index-projects` mounts the Windows projects folder read-only for directory listing, then unmounts
- Remount detection: if a project is already mounted with a different mode it is unmounted and remounted with the correct mode
- `unmount-project` changes out of the project directory before unmounting to avoid "device busy" errors

### User & Privilege

- Default WSL user is non-root (`dev`)
- Sudo requires a password — the user is in the `sudo` group but `NOPASSWD` is not set
- Home directory created with `useradd -m` (standard ownership)
- Default umask `0022` — new files are not world-writable

### Process Containment

- systemd runs as PID 1 (proper cgroup management and service supervision)
- bubblewrap (`bwrap`) installed for Claude's internal sandbox mode (Linux namespace isolation)
- Unprivileged user namespaces available so bubblewrap works without root

### Workflow Safeguards

- `__TOKEN__` placeholders (e.g. `__PROJECTS_DRVFS__`) are replaced with actual Windows paths at deploy time — no paths hardcoded in shell scripts
- `PROJECTS_DRVFS` is injected once at deploy time; mount commands fail visibly if the path is wrong, but there is no explicit pre-check
- Scripts are normalised to LF line endings and written as UTF-8 without BOM before being copied into the distro
- Profile and workflow scripts are only sourced if the file exists (`[ -f ... ] && source`)
- Bash profiles skip all setup for non-interactive shells

### File Permissions

- Persistence mount enforces `uid=1000`, `gid=1000`, `umask=022` via fstab mount options
- Project mounts enforce the same ownership and umask regardless of the Windows-side permissions

### Application Layer

- Claude permission modes let you dial autonomy per session:
  - `plan` — read and plan only, no changes
  - `acceptEdits` — can edit files, asks before running commands
  - `--dangerously-skip-permissions` — full autonomy (safe here because isolation is at the environment level)
- `CLAUDE.md` per-project policies: declare off-limits paths, branch rules, or any plain-language constraints
- `~/.claude/settings.json` deny lists permanently block specific tools or commands (e.g. `Bash(rm -rf:*)`)
- Worktree mode (`claude -w`) puts Claude on a separate branch — main is untouched until you merge
- Git provides a full, auditable trail of every change Claude makes

### Admin Operations

- All PowerShell scripts check for Administrator elevation at startup and exit immediately if not elevated
- Required source files are validated with `Test-Path` before the installer does any work
- Uninstall requires explicit confirmation before each destructive step (default answer: No)
- Persistence directory (`$ClaudePersistenceDir`) is explicitly preserved on uninstall — never deleted
- Temporary files (container rootfs tarball, fstab staging fragments) are deleted at the end of installation
- The container and pulled image are removed from the container runtime after the rootfs is exported

---

## Gaps & Missing Controls

### 1 — No outbound network filtering `HIGH`

No firewall rules, DNS filtering, or proxy configuration. Any process inside the sandbox can reach any internet host freely. A compromised dependency or tool can exfiltrate data with nothing blocking it.

**What would fix it:** A per-distro `iptables`/`nftables` allowlist, or a `.wslconfig` HTTP proxy pointing to an inspecting proxy on the host.

---

### 2 — No resource limits `MEDIUM`

No CPU, memory, or disk quotas applied to the distro. A runaway process (e.g. an infinite loop, a large build) can exhaust host RAM or disk. No `.wslconfig` template is provided or documented.

**What would fix it:** A documented `.wslconfig` with `memory=`, `processors=`, and `swap=` values. Optionally systemd slice limits inside the distro.

---

### 3 — No audit logging `MEDIUM`

No `auditd`, `syslog` forwarding, or mount event tracking beyond what git records. If something goes wrong there is no record of what commands ran, what was mounted, or what processes were spawned.

**What would fix it:** Enable `auditd` or `rsyslog` in the distro. Forward logs to a file on the persistence mount so they survive rebuilds.

---

### 4 — No input validation on project names `MEDIUM`

`mount-project` concatenates the `$project` argument directly into a path without any sanitisation. A name like `../../etc` would resolve outside the projects tree. The index picker (`switch-project`) mitigates this for interactive use, but direct calls to `mount-project` are unprotected.

**What would fix it:** Strip or reject any name that contains `/`, `\`, or `..` before constructing the mount path. Optionally validate the name against the projects index.

---

### 5 — No image digest pinning `MEDIUM`

`debian:bookworm-slim` is a floating tag. Each install pulls whatever the registry serves at that moment. There is no `@sha256:` digest and no signature check.

**What would fix it:** Pin the image to a known digest in `sandbox-config.ps1` (e.g. `debian:bookworm-slim@sha256:<hash>`). Re-pin intentionally when updating.

---

### 6 — No update / patch mechanism `MEDIUM`

`apt upgrade` is run once during installation but there is no script, cron job, or documented process for keeping packages current afterwards. Packages accumulate known CVEs over time.

**What would fix it:** A `Update-ClaudeSandbox.ps1` script (or documented `apt upgrade` workflow) run on a regular schedule.

---

### 7 — Claude installer uses curl-pipe-bash `MEDIUM`

The installer runs `curl -fsSL https://claude.ai/install.sh | bash` with no checksum or signature verification. HTTPS protects the download in transit but does not guarantee the script hasn't changed between installs or that the server wasn't compromised.

**What would fix it:** Download the script to a temp file, display its hash, and require confirmation before executing — or use an offline package if one becomes available.

---

### 8 — Plaintext password in config `LOW–MEDIUM`

`$UserPassword = "changeme"` is stored in plain text in `sandbox-config.ps1`. The risk is low for a private local checkout but increases if the file is committed to a shared repository or sent to someone.

**What would fix it:** Prompt for the password interactively during install instead of storing it in the config file. At minimum, validate that the default value has been changed before proceeding.

---

### 9 — No session timeout `LOW`

No `TMOUT` variable is set in any profile. Idle shells stay open indefinitely. On a shared or unattended machine this leaves an authenticated session exposed.

**What would fix it:** Set `TMOUT=900` (15 minutes) in `profiles/default.sh` or document it as a recommended hardening step.

---

### 10 — GPU passthrough enabled by default `LOW`

`gpu.enabled = true` in `wsl.conf` even when Claude doesn't need GPU access. This exposes the host's GPU driver stack to the distro unnecessarily.

**What would fix it:** Default to `gpu.enabled = false` and let users opt in via `sandbox-config.ps1` if they need it.

---

### 11 — No secret management guidance `LOW`

No documentation or tooling for handling API keys, tokens, or `.env` files. Users may store secrets inside the persistence mount or checked-in project files without realising the exposure.

**What would fix it:** A section in `docs/security.md` covering where not to put secrets, how to use environment variables safely, and recommending a tool like `pass` or `age`.

---

### 12 — No backup strategy documented `LOW`

The persistence mount (`~/.claude`) survives distro rebuilds but there is no guidance on how often to back it up, how to verify its integrity, or how to recover if the Windows folder is deleted or corrupted.

**What would fix it:** A brief section in the docs noting what lives in the persistence directory and recommending a backup approach (e.g. robocopy to a second location, or inclusion in an existing backup job).
