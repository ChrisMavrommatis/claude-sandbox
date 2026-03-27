## Task: Security improvements — work through in order.
## Read all tasks before starting. After each task state what changed.
## Do NOT modify security-posture.md or security-posture-details.md except
## in tasks that explicitly target them.

---

### TASK 1 — Sandbox network proxy: configure allowedDomains

File: ClaudeSandbox/Assets/managed-settings.json

Add allowedDomains to the sandbox configuration. This closes the highest-rated
open gap (HIGH / Not Supported) for bash command network filtering.

Replace the current sandbox block with:

  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "network": {
      "allowedDomains": [
        "deb.debian.org",
        "security.debian.org",
        "*.anthropic.com",
        "api.anthropic.com",
        "github.com",
        "*.github.com",
        "registry.npmjs.org",
        "pypi.org",
        "files.pythonhosted.org"
      ]
    }
  }

Then update plans/security-posture.md:
- Change "Sandbox network proxy" Status from "Not Supported" to "Supported"
- Change its Enforcement from "Sandbox (when impl.)" to "Sandbox"
- Add check code "I-013" (covered by existing managed settings check)

Then update docs/threat-model.md:
- Section 4 trust boundary table: change "Planned - not yet deployed" to
  "Sandbox-enforced via allowedDomains (managed-settings.json)"
- Section 6E, Info Disclosure row: change Status from "Planned" to "Mitigated"
  and update Control to reference the deployed allowedDomains list
- Section 7 Accepted Risks: update "Outbound network not filtered at host level"
  to note that bash traffic is now domain-filtered; WebFetch remains unfiltered
- Section 8 Planned Mitigations: remove the "Sandbox network proxy" row

Also update docs/about.md and SECURITY.md:
- In the Known Limitations list, change:
  "Sandbox network proxy for bash commands not yet configured - bash has
   unrestricted outbound access until deployed"
  To:
  "Sandbox network proxy restricts bash commands to an approved domain list;
   Claude's built-in tools (WebFetch) remain unfiltered"

Note: CVE-2025-66479 fix (allowedDomains = [] silent failure) is already
documented in threat-model.md. Do not remove it - it remains relevant context.

---

### TASK 2 — Image digest pinning: wire up the WARN check in Test-Sandbox

File: ClaudeSandbox/Public/Verify-ClaudeSandbox.ps1

Add a new check after S-021:

  # S-022: Image digest pinning (warn-only)
  if ($Config.DistroImage -match '@sha256:') {
      Write-CheckResult "S-022" "PASS" "Distro image is digest-pinned"
  } else {
      Write-CheckResult "S-022" "WARN" "Distro image not digest-pinned (no @sha256: in DistroImage)"
  }

Add S-022 to the check code table in CLAUDE.md:
  | `S-022` | Security | Distro image pinned to digest (@sha256:) |

Update plans/security-posture.md:
- Add check code "S-022" to the "Image digest pinning" row
- Status stays "Not Supported" -- the check warns but pinning is not enforced

---

### TASK 3 — Document S-013 Python crypt deprecation in posture-details

File: plans/security-posture-details.md

Find the section "Secret management guidance" or add a new section near the
bottom for verification gaps. Add:

---

## S-013 password check — Python crypt deprecation note `LOW`

**Current implementation:** The S-013 check in Test-Sandbox uses Python's
`spwd` and `crypt` modules to verify the sandbox user password is not still
set to the default value `changeme`. This approach is reliable on Debian
Bookworm which ships Python 3.11.

**Future gap:** `spwd` and `crypt` are deprecated as of Python 3.11 and
removed in Python 3.13. When the base image is upgraded to a Debian version
shipping Python 3.13+, S-013 will silently return "error" and always emit
PASS, meaning the default password warning will stop working.

**Replacement when needed:**
```bash
python3 -c "
import hashlib, struct
shadow = open('/etc/shadow').read()
for line in shadow.splitlines():
    if line.startswith('$Username:'):
        hash = line.split(':')[1]
        break
# Use passlib or openssl instead
"
```
Or using openssl directly:
```bash
salt=$(grep '^$Username:' /etc/shadow | cut -d'$' -f3)
stored=$(grep '^$Username:' /etc/shadow | cut -d':' -f2)
computed=$(openssl passwd -6 -salt "$salt" 'changeme')
[ "$computed" = "$stored" ] && echo match || echo no
```

**Action required when:** Debian base image is upgraded beyond Bookworm.

---

### TASK 4 — PreToolUse hook: block reads of credential file patterns

This task has two parts: create the hook script asset and wire it into
the installer and managed settings.

**Part A — Create the hook script:**

Create ClaudeSandbox/Assets/hooks/pretooluse-credential-guard.sh

Content:

```bash
#!/usr/bin/env bash
# PreToolUse hook: block reads of credential file patterns
# Claude Code passes tool name and input as JSON to stdin.
# Exit 2 to block, exit 0 to allow.

input=$(cat)
tool=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path','') or d.get('tool_input',{}).get('path',''))" 2>/dev/null)

# Only inspect file read operations
if [[ "$tool" != "Read" && "$tool" != "Edit" && "$tool" != "Write" ]]; then
    exit 0
fi

# Block access to credential file patterns
patterns=(
    ".env"
    ".env.*"
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
    "*credentials*"
    "*secret*"
    "*.token"
    "id_rsa"
    "id_ed25519"
    "*.ovpn"
)

filename=$(basename "$path")

for pattern in "${patterns[@]}"; do
    if [[ "$filename" == $pattern ]]; then
        echo "Blocked: credential file pattern matched ($filename)" >&2
        exit 2
    fi
done

exit 0
```

**Part B — Wire into managed-settings.json:**

Add a hooks section to managed-settings.json:

  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash /etc/claude-code/hooks/pretooluse-credential-guard.sh"
          }
        ]
      }
    ]
  }

**Part C — Deploy in Install-Sandbox:**

In Install-Sandbox.ps1, after deploying managed-settings.json and
managed-policy.md, add:

  # Deploy PreToolUse credential guard hook [I-015]
  Write-Info "Deploying PreToolUse credential guard hook..."
  Invoke-InSandbox $DistroName "mkdir -p /etc/claude-code/hooks"
  $hookPath = Get-AssetPath "hooks/pretooluse-credential-guard.sh"
  $hookContent = Get-Content $hookPath -Raw
  Write-FileToDistro $DistroName "/tmp/pretooluse-credential-guard.sh" $hookContent
  Invoke-InSandbox $DistroName "mv /tmp/pretooluse-credential-guard.sh /etc/claude-code/hooks/pretooluse-credential-guard.sh && chmod 755 /etc/claude-code/hooks/pretooluse-credential-guard.sh"
  Write-Ok "Credential guard hook deployed"

**Part D — Add I-015 check to Test-Sandbox:**

  # I-015: PreToolUse credential guard hook deployed
  if (Test-InSandbox "test -f /etc/claude-code/hooks/pretooluse-credential-guard.sh") {
      Write-CheckResult "I-015" "PASS" "Credential guard hook deployed"
  } else {
      Write-CheckResult "I-015" "FAIL" "Credential guard hook missing"
  }

**Part E — Update documentation:**

Add I-015 to CLAUDE.md check code table:
  | `I-015` | Installation | PreToolUse credential guard hook deployed |

Update plans/security-posture.md:
- Change "PreToolUse hooks" Status from "Not Supported" to "Supported"
- Change Enforcement from "Sandbox (when impl.)" to "Sandbox"
- Add check code "I-015"

Update docs/threat-model.md:
- Section 6B, Info Disclosure (Claude reads credentials in mounted project):
  Change Status from "Partial" to "Mitigated"
  Add to Control: "PreToolUse hook blocks reads of .env, *.pem, *credentials*,
  and other credential file patterns (I-015)"
  Update Residual Risk: "Blocks by filename pattern only. Files with
  non-standard names containing credentials are not blocked. Direct bash
  `cat` commands are not covered by this hook."
- Section 7 Accepted Risks: update "Claude can read credentials in mounted
  RW project directories" to note PreToolUse hook is now deployed
- Section 8 Planned Mitigations: remove PreToolUse hooks row

---

### FINAL CHECKS

1. Verify managed-settings.json is valid JSON (no trailing commas)
2. Verify allowedDomains contains the core package registry domains
3. Verify S-022 appears in the CLAUDE.md check code table
4. Verify I-015 appears in the CLAUDE.md check code table
5. Verify "Sandbox network proxy" is Supported in security-posture.md
6. Verify "PreToolUse hooks" is Supported in security-posture.md
7. Search threat-model.md Section 8 -- "Sandbox network proxy" and
   "PreToolUse hooks" must not appear there (both now implemented)
8. List every file created or modified with a one-line summary.