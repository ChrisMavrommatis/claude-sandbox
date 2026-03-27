# Next Steps

Three implementation tasks to complete the security posture and add CI. These can be done independently in any order.

---

## 1. Managed Settings and Policy Deployment

Deploy `/etc/claude-code/managed-settings.json` and `/etc/claude-code/CLAUDE.md` into the sandbox during install. This closes several security gaps in one pass.

### managed-settings.json

Create `ClaudeSandbox/Assets/managed-settings.json`:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(dd *)",
      "Bash(mkfs *)",
      "Bash(:(){ :|:& };:)"
    ]
  },
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true
  }
}
```

Notes:
- Start minimal - only deny clearly destructive patterns
- Enable sandbox with fail-if-unavailable so bubblewrap is enforced
- Do NOT add `allowedDomains` yet - needs research on which domains are essential (apt repos, npm, pip, Anthropic API). Add in a follow-up once tested.
- Do NOT add `disableBypassPermissionsMode` - the sandbox itself is the isolation layer, bypass mode is acceptable inside it
- Do NOT add `allowManagedPermissionRulesOnly` - too restrictive for daily use

### managed CLAUDE.md

Create `ClaudeSandbox/Assets/managed-policy.md`:

Keep it short - these are hard rules that apply to every session in every project:

```markdown
# Sandbox Policy

- Never modify files outside the current working directory without explicit user approval
- Never modify /etc/wsl.conf, /etc/fstab, or /etc/sudoers.d/
- Never read or print the contents of .env files, credentials, or API keys unless the user explicitly asks
- Never run commands that delete the home directory, system files, or mounted project roots
- If you encounter credentials in source code, warn the user instead of using them
```

### Install-Sandbox changes

Add a new step (between current Step 3 and Step 4):

```powershell
# Deploy managed settings and policy
Write-Info "Deploying managed settings and policy..."
Invoke-InSandbox $DistroName "mkdir -p /etc/claude-code"
$managedSettingsPath = Get-AssetPath "managed-settings.json"
$managedSettingsContent = Get-Content $managedSettingsPath -Raw
Write-FileToDistro $DistroName "/etc/claude-code/managed-settings.json" $managedSettingsContent

$managedPolicyPath = Get-AssetPath "managed-policy.md"
$managedPolicyContent = Get-Content $managedPolicyPath -Raw
Write-FileToDistro $DistroName "/etc/claude-code/CLAUDE.md" $managedPolicyContent
Write-Ok "Managed settings and policy deployed"
```

### Update-Sandbox changes

Add the same deployment block so policy updates propagate on update.

### Test-Sandbox changes

Add two new checks:
- `I-013`: `/etc/claude-code/managed-settings.json` exists
- `I-014`: `/etc/claude-code/CLAUDE.md` exists

### Documentation updates

- `CLAUDE.md` - add `managed-settings.json` and `managed-policy.md` to Assets table, add I-013 and I-014 to check codes
- `plans/security-posture.md` - mark "Managed settings file" and "Managed policy CLAUDE.md" as Supported
- `plans/security-posture-details.md` - remove both entries (they're implemented)

### Files to create/modify

| Action | File                                         |
| ------ | -------------------------------------------- |
| Create | `ClaudeSandbox/Assets/managed-settings.json` |
| Create | `ClaudeSandbox/Assets/managed-policy.md`     |
| Modify | `ClaudeSandbox/Public/Install-Sandbox.ps1`   |
| Modify | `ClaudeSandbox/Public/Update-Sandbox.ps1`    |
| Modify | `ClaudeSandbox/Public/Test-Sandbox.ps1`      |
| Modify | `CLAUDE.md`                                  |
| Modify | `plans/security-posture.md`                  |
| Modify | `plans/security-posture-details.md`          |

---

## 2. GitHub Actions CI Workflow

Add a basic CI workflow that validates the PowerShell module loads and shell scripts parse correctly. Runs on every push and PR.

### Create `.github/workflows/validate.yml`

```yaml
name: Validate

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  powershell-module:
    name: Validate PowerShell Module
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Import module
        shell: pwsh
        run: |
          Import-Module ./ClaudeSandbox/ClaudeSandbox.psd1 -Force
          $commands = Get-Command -Module ClaudeSandbox
          Write-Host "Exported commands: $($commands.Count)"
          $commands | Format-Table Name, CommandType

      - name: Validate module manifest
        shell: pwsh
        run: Test-ModuleManifest ./ClaudeSandbox/ClaudeSandbox.psd1

  shell-scripts:
    name: Validate Shell Scripts
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Syntax check all .sh files
        run: |
          find . -name '*.sh' -print0 | while IFS= read -r -d '' f; do
            echo "Checking $f"
            bash -n "$f"
          done

      - name: Check for em dashes in markdown
        run: |
          if grep -rn '—' --include='*.md' .; then
            echo "::error::Em dashes found in markdown files"
            exit 1
          fi
```

Notes:
- Two jobs: PowerShell validation on Windows, shell script validation on Ubuntu
- Module import test catches missing exports, syntax errors in .ps1 files, broken dependencies
- `Test-ModuleManifest` catches version/GUID/export mismatches
- Shell syntax check catches bash parse errors
- Em dash check enforces the style rule automatically
- Does NOT run the installer or Test-Sandbox (would need a full WSL2 environment)

### Files to create

| Action | File                              |
| ------ | --------------------------------- |
| Create | `.github/workflows/validate.yml`  |

---

## 3. Mermaid Diagram Rendering Check

The threat model mermaid diagram needs to render on GitHub. GitHub supports mermaid in markdown natively since 2022, so the existing ` ```mermaid ` fence should work. No code changes needed.

### Verification

After pushing to GitHub:
1. Open `docs/threat-model.md` in the GitHub web UI
2. Confirm the mermaid diagram renders as a flowchart
3. If not: check for em dashes or special characters inside the mermaid block that break the parser

### Known issue

The mermaid block uses `\n` for line breaks inside node labels. GitHub's mermaid renderer handles this, but some older renderers don't. If it breaks, replace `\n` with `<br/>` inside the node strings.

---

## Implementation Order

1. **#2 CI workflow** first - catches issues in subsequent changes
2. **#1 Managed settings** - biggest security impact
3. **#3 Mermaid check** - verify after pushing #1 and #2
