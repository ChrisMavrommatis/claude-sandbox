# Security Posture - Research Notes

Research and implementation notes for security items not yet supported. Items are removed from this file as they get implemented. See [security-posture.md](security-posture.md) for the full list.

Ordered by impact: HIGH first, then MEDIUM, then LOW.

---

## Sandbox network proxy `HIGH`

**Gap:** Claude's sandbox mode includes a proxy-based network filter that restricts which domains bash commands can reach. We install the prerequisites (bubblewrap + socat) but don't configure `allowedDomains` or enable the network proxy.

**What it is:** When sandbox mode is enabled with `/sandbox`, Claude runs bash commands through an OS-level sandbox (bubblewrap on Linux). Network access goes through a proxy that only allows connections to explicitly approved domains. New domains trigger a permission prompt.

**Why this matters:** This is different from iptables-level network filtering. The sandbox proxy works reliably on WSL2 because it's application-level, not kernel-level. It only applies to sandboxed bash commands, not to Claude's built-in tools.

**What to look for:**

- Configure `sandbox.network.allowedDomains` in managed settings to pre-approve needed domains
- Set `sandbox.enabled = true` in managed settings to enable by default
- Consider `sandbox.network.allowManagedDomainsOnly = true` to prevent users from adding domains
- socat is required for the network proxy - already installed by our sandbox

**Considerations:**

- This partially closes the "outbound network filtering" gap for bash commands
- Does NOT filter Claude's own WebFetch or other built-in tools - those need separate `WebFetch(domain:...)` rules
- Need to determine a sensible default domain allowlist (apt repos, Claude API, GitHub, npm registry)
- Too restrictive breaks `apt-get update`, `npm install`, `pip install`, etc.

**Implementation approach:**

- Add sandbox settings to the managed settings file (`/etc/claude-code/managed-settings.json`)
- Pre-approve essential domains: `deb.debian.org`, `*.anthropic.com`, `github.com`, `registry.npmjs.org`
- Set `sandbox.failIfUnavailable = true` to enforce sandboxing
- Deploy during `Install-Sandbox`

---

## Outbound network filtering (host-level) `HIGH`

**Gap:** Any process in the sandbox can reach any internet host. A compromised dependency or tool can exfiltrate data with nothing blocking it.

**Why it's hard:** WSL2 runs in a lightweight VM (backed by the Hyper-V hypervisor) with NAT networking managed by Windows. The network adapter resets on distro restart, so iptables rules don't persist without a systemd service. In mirrored networking mode (newer Windows builds), the distro shares the host's interfaces directly, making iptables even less effective.

**Considerations:**

- iptables inside WSL2 is unreliable across restarts and networking modes
- `.wslconfig` supports an HTTP proxy setting but requires a proxy server running on the host
- Windows Firewall can filter WSL2 traffic but the VM's IP range changes on every WSL restart
- DNS filtering (e.g. Pi-hole on host) would catch DNS-based exfiltration but not direct IP connections
- The sandbox network proxy (above) partially addresses this for bash commands

**Best approach:** Document recommended Windows Firewall rules or host-side proxy setup in `docs/safe-usage.md`. Don't try to automate it from inside the sandbox. This is fundamentally a host-level concern.

**Blocked by:** WSL2 networking architecture. No clean self-contained solution exists.

---

## Disable bypass permissions mode `MEDIUM`

**Gap:** Users can run Claude with `bypassPermissions` mode which skips all permission prompts. In a controlled sandbox this might be acceptable, but managed settings can prevent it.

**What it is:** Setting `permissions.disableBypassPermissionsMode = "disable"` in managed settings prevents users from activating bypass mode.

**What to look for:**

- Add to managed settings file
- Also consider `disableAutoMode` if auto mode is not desired

**Considerations:**

- In our sandbox, `bypassPermissions` is relatively safe because the environment itself is isolated
- Blocking it adds defense-in-depth but reduces user flexibility
- Decision: deploy it or not? Depends on how locked-down the user wants the sandbox

**Implementation approach:**

- Part of the managed settings deployment. One line in the settings JSON.

---

## Managed-only permission rules `MEDIUM`

**Gap:** Users can add their own `allow` rules in user or project settings, potentially widening permissions beyond what was intended.

**What it is:** Setting `allowManagedPermissionRulesOnly = true` in managed settings prevents user and project settings from defining allow/ask/deny rules. Only managed rules apply.

**Considerations:**

- Very restrictive - users can't customize permissions at all
- Better suited for enterprise/team environments than personal dev sandboxes
- Alternative: don't use this, and rely on deny rules in managed settings (deny can't be overridden regardless)

**Implementation approach:**

- Part of the managed settings deployment. Optional - may be too restrictive for most users.

---

## PreToolUse hooks `MEDIUM`

**Gap:** No runtime validation of tool calls beyond static deny lists. Hooks can inspect and block specific tool calls dynamically.

**What it is:** Claude Code hooks that run before each tool call. A hook script can inspect the tool name and arguments, then return allow/deny/prompt. More powerful than static rules because they can run arbitrary logic.

**What to look for:**

- Configure in managed settings under `hooks.PreToolUse`
- Hook script receives tool name and arguments as JSON
- Exit code 0 = allow, 1 = prompt, 2 = block
- Deny rules still take precedence even if hook returns allow
- `allowManagedHooksOnly = true` prevents user hooks from overriding managed hooks

**Considerations:**

- Adds a shell script execution on every tool call - minor performance impact
- Need to write and test the hook script carefully
- Could validate: file paths, command patterns, network destinations
- Useful for blocking specific dangerous patterns that static rules can't express

**Implementation approach:**

- Create a hook script in `ClaudeSandbox/Assets/`
- Deploy to `/etc/claude-code/` during install
- Configure in managed settings
- Start simple - block a few high-risk patterns, expand over time

---

## Resource limits `MEDIUM`

**Gap:** No CPU, memory, or disk quotas. A runaway process can exhaust host resources.

**What to look for:**

- `.wslconfig` in `%USERPROFILE%` controls `memory`, `processors`, `swap` for ALL WSL distros
- Deploying it affects every distro on the machine, not just ours - this is the main risk
- systemd slice limits (`MemoryMax`, `CPUQuota`) work inside the distro but need a service file

**Considerations:**

- `.wslconfig` is global - could break the user's other WSL distros if they have different needs
- Should generate a template file but NOT auto-deploy it. Let the user review and place it themselves.
- Default values: `memory=4GB`, `processors=2`, `swap=2GB` are reasonable for dev work
- Add config variables to `sandbox-config.ps1` but only deploy if the user explicitly opts in

**Implementation approach:**

- Ship `ClaudeSandbox/Assets/.wslconfig.template`
- Add `$WslConfigDeploy = $false` to sandbox-config.ps1
- If enabled, copy to `$env:USERPROFILE\.wslconfig` during install (with backup of existing)
- Warn the user that this affects all WSL distros

---

## Audit logging `MEDIUM` (partially addressed)

**Gap:** Only git changes and bash history timestamps are recorded. No system-level command audit, mount event tracking, or process spawn logging.

**What's already done:** `HISTTIMEFORMAT` in profiles (S-018) provides timestamped command history.

**What remains:**

- `auditd` would provide kernel-level audit trail but adds overhead and complexity
- `rsyslog` could forward logs to a persistent file
- Mount/unmount operations in the workflow script could log to a file

**Considerations:**

- `auditd` may not work reliably in all WSL2 kernel versions
- Log rotation needed if logging to a file (persistence mount could fill up)
- For a local dev sandbox, bash history + git trail is likely sufficient
- Full auditd is more appropriate for enterprise/shared environments

**Implementation approach (if pursued):**

- Add mount/unmount logging to `workflows/default.sh` (append to `~/.claude/mount.log`)
- Skip auditd - too complex and fragile for WSL2
- Document the limitation for users who need full audit compliance

---

## Image digest pinning `MEDIUM`

**Gap:** `debian:bookworm-slim` is a floating tag. Each install pulls whatever the registry serves at that moment. No `@sha256:` digest or signature check.

**What to look for:**

- `podman inspect --format '{{.Digest}}' debian:bookworm-slim` gives the current digest
- Pin as `debian:bookworm-slim@sha256:<hash>` in `sandbox-config.ps1`

**Multi-arch digest pinning (resolved):**

- Pull the architecture-specific image explicitly: `podman pull --platform linux/amd64 debian:bookworm-slim`
- Get the platform-specific digest: `podman inspect --format '{{.Digest}}' debian:bookworm-slim`
- For ARM64 hosts: use `--platform linux/arm64` - the digest differs from amd64
- Pin in sandbox-config.ps1 as: `$DistroImage = 'debian:bookworm-slim@sha256:<your-digest>'`
- The digest is architecture-specific - document this in sandbox-config.ps1 with a comment explaining users must re-pin for their platform
- `podman create` and `docker create` both accept digest-pinned references; no tag is required if a digest is present

**Considerations:**

- Pinning means the digest goes stale - need a documented process to re-pin
- Could add a check that verifies `$DistroImage` contains `@sha256:` but that forces all users to pin
- Alternative: warn during install if no digest is present (WARN, not FAIL)

**Implementation approach:**

- Add a WARN (not FAIL) check to Test-Sandbox: if $DistroImage does not contain '@sha256:', emit a warning that the image is not digest-pinned
- Document the pinning process in sandbox-config.ps1
- Do not change the default - users opt in to pinning

---

## Claude installer uses curl-pipe-bash `MEDIUM`

**Gap:** `curl -fsSL https://claude.ai/install.sh | bash` with no checksum or signature verification.

**Why it matters:** HTTPS protects transit but not against server compromise, CDN poisoning, or time-of-check/time-of-use changes.

**Considerations:**

- No offline installer package currently available from Anthropic
- Could download to temp file, show hash, prompt for confirmation - but the hash changes with every release
- Could maintain a known-good hash in `sandbox-config.ps1` but it would go stale immediately
- npm/pip package would be better but Claude Code is distributed as a binary via this script

**Blocked by:** No alternative distribution mechanism from Anthropic. Monitor for official package manager support (apt, npm, etc.).

**Interim option:** Download to temp, display sha256, let user confirm. Low value since there's no known-good hash to compare against.

---

## ConfigChange hooks `LOW`

**Gap:** No auditing or blocking of settings changes during Claude sessions. A user (or Claude itself) could modify permissions mid-session.

**What it is:** Claude Code supports `ConfigChange` hooks that fire when settings are modified during a session. These can log changes or block them entirely.

**What to look for:**

- Hooks are configured in Claude's settings files
- Could log all permission changes to a file
- Could block widening of permissions (e.g., adding new allow rules)
- Useful for teams, less critical for solo local dev

**Considerations:**

- Adds complexity for marginal benefit in a single-user sandbox
- More valuable if the sandbox is shared or used in a team setting
- Need to research the exact hook configuration format
- Could be deployed as part of the managed settings file

**Implementation approach:**

- Low priority - implement after managed settings file is in place
- Add a hook in managed settings that logs config changes to persistence mount
- Consider blocking rather than just logging for high-risk changes

---

## Sudo brute-force limiting `LOW`

**Gap:** No PAM lockout after failed sudo attempts.

**Why it's not planned:** Risk of locking yourself out of a local dev sandbox outweighs the benefit. The threat model is "sandbox can't escape to host," not "someone is brute-forcing sudo from inside." If an attacker is inside the sandbox, they already have the access level Claude has.

**If reconsidered:** `pam_faillock` with `deny=5 unlock_time=600` would lock after 5 failures for 10 minutes. Requires adding `libpam-modules` and configuring `/etc/pam.d/common-auth`.

---

## Claude Code auto-updates `LOW`

**Gap:** Claude Code updates itself. No version pinning or rollback.

**Not fixable:** External tool managed by Anthropic. The binary at `~/.local/bin/claude` self-updates. No `--no-auto-update` flag exists. No package manager distribution available.

**Monitor for:** Official apt/npm/brew packages that would allow version pinning.

