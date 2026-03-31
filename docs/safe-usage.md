# Safe Usage Guide

How to use Claude Code effectively inside the distro.

## Mount control

Projects are not mounted automatically - you choose what Claude can access:

```bash
mount-project my-app --ro    # read-only: reviews, explanations, Q&A
mount-project my-app --rw    # read-write: active development
unmount-project my-app       # revoke access when done
```

Use `--ro` by default.
Only switch to `--rw` when Claude needs to write files.
Project names are validated to prevent path traversal.

## Permission modes

Control how much Claude acts autonomously per session:

```bash
claude --permission-mode plan         # read and plan only, no changes
claude --permission-mode acceptEdits  # edit files freely, ask before running commands
claude --dangerously-skip-permissions # no prompts (safe here - distro limits reach)
```

Start with `plan` for unfamiliar projects or whenever you are unsure of scope.

## Claude sandbox mode

Enable additional isolation for bash commands:

```bash
/sandbox
```

This uses bubblewrap to restrict what commands can reach, and filters outbound network requests by domain (subject to the active policy tier).
Combined with WSL2 isolation, this provides defense-in-depth against prompt injection and malicious dependencies.
Claude sandbox mode is opt-in - it is not active by default.

## Worktree isolation

For large or risky changes, isolate work using a native Claude Code worktree:

```bash
claude -w
```

This creates an isolated git worktree so `main` stays untouched until you merge.
Discard the worktree if the result is not what you wanted.

## Policy tiers

The distro ships with three managed policy tiers that control what Claude can do at the system level.
Switch tiers by editing `sandbox-config.ps1` and re-running the installer:

| Tier        | What changes vs default                                      |
|-------------|--------------------------------------------------------------|
| default     | Blocks `rm -rf /*`, `dd`, `mkfs` only                        |
| restrictive | Also blocks `curl`, `wget`, package installs, `git push`     |
| maximum     | All restrictive blocks plus stricter network filtering       |

All tiers are enforced via `/etc/claude-code/managed-settings.json` (verified by S-021).

## Project rules

Create a `CLAUDE.md` in any project root. 
Claude reads it at the start of every session in that directory:

```markdown
## Rules
- Never modify anything in src/legacy/
- Never read or print .env files
- Always use feature branches, never commit to main
```

The distro also deploys a managed policy at `/etc/claude-code/CLAUDE.md` that applies to all sessions automatically.
This is a **behavioural guardrail** - it relies on Claude following the instructions, not on the OS enforcing them. 
For hard blocks, use deny rules (see below).

## Deny rules

Add your own permanent blocks in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Bash(sudo *)",
      "Bash(apt-get install *)"
    ]
  }
}
```

For per-project rules, place the same file at `<project>/.claude/settings.json`.

## Reviewing changes

Before moving on from any Claude session:

```bash
git diff              # what changed but wasn't committed
git log --oneline -5  # what was committed
```

Undo the last commit without losing the changes: `git reset HEAD~1`.

## Secret management

Claude can read any file it has access to. Treat credentials accordingly:

- **Never commit secrets to git**: Add `.env` to `.gitignore`.
- **Never store secrets in `~/.claude`**: The persistence mount is fully readable by  Claude across all sessions, including future ones.
- **Exported environment variables are visible to Claude**: And every child process it spawns.
Acceptable for short-lived tokens; not for long-term credentials.
- **Mount read-only when secrets are present**: If a project contains `.env` files or credentials, use `--ro`.
Manage the secrets outside the mounted path.

## Backup

Claude's persistent state lives in the `$ClaudePersistenceDir` folder on your Windows host (default: `D:\.claude`). 
It contains your login session, settings, memory, and conversation history.

**Back up the entire folder:**

```powershell
robocopy $ClaudePersistenceDir "$ClaudePersistenceDir-backup" /MIR
```

Or include it in your existing Windows backup job.

**Recovery**: Restore the folder, then run `.\Verify-ClaudeSandbox.ps1` to confirm the sandbox is wired up correctly.

**What you lose without a backup**: Claude re-authentication, all conversation memory, custom settings and deny rules.
