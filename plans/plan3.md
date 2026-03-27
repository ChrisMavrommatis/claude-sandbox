## Task: Research and planning only — do NOT implement anything.
## For each item, investigate feasibility on WSL2 Debian Bookworm,
## then write findings directly into plans/security-posture-details.md.
## No code changes. No installer changes. Output is documentation only.

---

### RESEARCH TASK 1 — AIDE (file integrity monitoring)

Investigate whether AIDE (Advanced Intrusion Detection Environment) is viable
for monitoring /etc/claude-code/ between sessions on WSL2.

Questions to answer:
- Is aide available in Debian Bookworm apt repos?
- Can the AIDE database be initialized and checked on a WSL2 distro?
- Does systemd service support work reliably for scheduled checks on WSL2?
- What is the performance cost of initializing the database on a typical
  project directory?
- Can the check be integrated into Test-Sandbox (run-and-compare) without
  requiring a systemd timer?
- What files should be in scope: /etc/claude-code/, /etc/wsl.conf,
  /etc/sudoers.d/, /etc/fstab, /etc/profile.d/session-timeout.sh?
- What is the failure mode if the database doesn't exist yet (first run)?

Write findings in plans/security-posture-details.md under a new section:

## AIDE file integrity monitoring `MEDIUM`

Include:
- Feasibility verdict (Viable / Blocked / Partial)
- Proposed scope (which files to watch)
- Integration approach with Test-Sandbox
- Where to store the database (persistence mount vs inside distro)
- Known limitations
- Implementation effort estimate (Low / Medium / High)

---

### RESEARCH TASK 2 — sysctl hardening

Investigate which sysctl hardening parameters are effective on WSL2 Debian
Bookworm and which are silently ignored or cause errors.

Test each of these parameters for WSL2 compatibility:

Network hardening:
- net.ipv4.tcp_syncookies = 1
- net.ipv4.conf.all.rp_filter = 1
- net.ipv4.conf.default.rp_filter = 1
- net.ipv4.icmp_echo_ignore_broadcasts = 1
- net.ipv4.conf.all.accept_redirects = 0
- net.ipv6.conf.all.accept_redirects = 0
- net.ipv4.conf.all.send_redirects = 0

Kernel hardening:
- kernel.dmesg_restrict = 1
- kernel.kptr_restrict = 2
- fs.protected_hardlinks = 1
- fs.protected_symlinks = 1
- kernel.yama.ptrace_scope = 1

For each parameter determine:
- Effective on WSL2? (yes / no / partial)
- Any known side effects on WSL2 specifically?
- Safe to deploy automatically in the installer?

Write findings in plans/security-posture-details.md under a new section:

## sysctl kernel hardening `LOW`

Include:
- A table: Parameter | Effective on WSL2 | Safe to auto-deploy | Notes
- Proposed /etc/sysctl.d/99-claude-sandbox.conf content (only parameters
  confirmed effective and safe)
- Any parameters to avoid and why
- Proposed Test-Sandbox check: read the deployed file and verify key
  parameters are present

---

### RESEARCH TASK 3 — Falco (eBPF runtime detection)

Investigate whether Falco is viable on WSL2 Debian Bookworm.

Questions to answer:
- Does the WSL2 kernel support eBPF to the degree Falco requires?
- Is the Falco kernel module or eBPF probe loadable on WSL2?
- Has anyone confirmed Falco working on WSL2 in 2025/2026?
- If not fully viable, is there a lightweight alternative
  (e.g. auditd-ng, tetragon, sysdig)?
- What rules would be most relevant for Claude Sandbox:
  detecting reads of /etc/shadow, mass file reads, unexpected network
  connections, writes to /etc/claude-code/?

Write findings in plans/security-posture-details.md under a new section:

## Falco runtime detection `LOW`

Include:
- Feasibility verdict with evidence (confirmed working / blocked / untested)
- If blocked: what the blocker is specifically (kernel module? eBPF version?)
- If viable: minimal rule set for Claude Sandbox use case
- Alternative tools if Falco is blocked
- Recommendation: pursue or park

---

### RESEARCH TASK 4 — osquery

Investigate whether osquery is viable as a queryable audit trail on WSL2.

Questions to answer:
- Does osquery run on WSL2 Debian Bookworm?
- Does the osqueryd daemon work with systemd on WSL2?
- What tables are most useful for Claude Sandbox auditing:
  processes, open_files, listening_ports, file_events, socket_events?
- Can it log Claude process file access to a persistent log in
  $ClaudePersistenceDir?
- What is the performance overhead?
- Is it overkill for a single-user dev sandbox?

Write findings in plans/security-posture-details.md under a new section:

## osquery audit trail `LOW`

Include:
- Feasibility verdict
- Most relevant tables for this use case
- Proposed query for detecting Claude reading credential files
- Performance considerations
- Recommendation: pursue or park

---

### RESEARCH TASK 5 — Lynis security audit

Investigate running Lynis as a one-shot post-install audit tool.

Questions to answer:
- Is lynis available in Debian Bookworm repos?
- Can it run non-interactively (for scripted use)?
- What score does a freshly installed Claude Sandbox get?
- Which Lynis recommendations are actionable on WSL2 vs blocked by the
  kernel?
- Can a Lynis run be added as an optional step in Test-Sandbox or
  Update-Sandbox?
- What's the runtime cost?

Write findings in plans/security-posture-details.md under a new section:

## Lynis post-install audit `LOW`

Include:
- How to run: lynis audit system --quick --no-colors
- Expected score range for this sandbox configuration
- Top 5 actionable findings vs top 5 WSL2-blocked findings
- Whether to integrate into Test-Sandbox (WARN-only, not FAIL)

---

### FINAL OUTPUT

After all research sections are written:

1. Add a summary table at the TOP of the new research entries
   (not at the top of the file -- after the existing content):

## Research Summary — Linux security tooling on WSL2

| Tool      | Feasibility | Priority | Recommendation |
| --------- | ----------- | -------- | -------------- |
| AIDE      | ?           | MEDIUM   | ?              |
| sysctl    | ?           | LOW      | ?              |
| Falco     | ?           | LOW      | ?              |
| osquery   | ?           | LOW      | ?              |
| Lynis     | ?           | LOW      | ?              |

Fill in Feasibility and Recommendation based on your findings.

2. Do not modify any other file.
3. Do not implement any of these tools.
4. List what was added to security-posture-details.md.

---

### IMPORTANT CONSTRAINTS

- If you cannot determine feasibility from available knowledge, say
  "Requires live testing" rather than guessing.
- Do not mark anything as "Viable" unless you are confident it works
  on WSL2 specifically -- not just on native Linux.
- WSL2 Debian Bookworm kernel is the Microsoft-built kernel, not a
  custom kernel. Assume stock unless stated otherwise.
- Be honest about uncertainty. "Unknown -- requires testing" is a
  valid and preferred answer over a confident wrong answer.