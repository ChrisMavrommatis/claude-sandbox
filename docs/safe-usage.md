# Security Guide

How to use Claude safely inside the sandbox.

---

## Mount control

Projects are not mounted automatically. You choose what Claude can access:

```bash
mount-project my-app --ro    # read-only
mount-project my-app --rw    # read-write
unmount-project my-app       # remove access
```

Use `--ro` when Claude only needs to read (reviews, explanations). Project names are validated to prevent path traversal.

---

## Permission modes

Control Claude's autonomy per session:

```bash
claude --permission-mode plan          # read and plan only, no changes
claude --permission-mode acceptEdits   # edit files freely, ask before commands
claude --dangerously-skip-permissions  # no prompts (safe here - sandbox limits reach)
```

Start with `plan` for unfamiliar projects.

---

## Sandbox mode

Enable filesystem and network isolation for bash commands:

```
/sandbox
```

This uses bubblewrap to restrict what commands can access. Network requests are filtered by domain. Combined with the WSL2 isolation, this provides defense-in-depth against prompt injection and malicious dependencies.

---

## Worktree isolation

For large or risky changes, use a separate branch:

```bash
claude -w
```

Main stays untouched until you merge. Discard the branch if the result isn't what you wanted.

---

## Project rules

Create a `CLAUDE.md` in any project root. Claude reads it at the start of every session:

```markdown
## Rules
- Never modify anything in src/legacy/
- Never read or print .env files
- Always use feature branches, never commit to main
```

---

## Deny lists

Block commands permanently in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(curl *)",
      "Bash(wget *)"
    ]
  }
}
```

Per-project: place the same file in `<project>/.claude/settings.json`.

---

## Review changes

Before moving on:

```bash
git diff              # see what changed
git log --oneline -5  # see what was committed
```

Undo the last commit: `git reset HEAD~1`.

---

## Secret management

Claude can read any file it has access to. Handle secrets carefully:

- **Never commit secrets to git.** Use `.gitignore` for `.env` files.
- **Never store secrets in `~/.claude`** (the persistence mount). Claude has full read access to this directory across all sessions, including future ones.
- **Environment variables are visible to Claude.** Any secret you `export` in a shell session is readable by Claude and every child process it spawns. This is acceptable for short-lived secrets but not for long-term credentials.
- **Mount read-only when secrets exist.** If a project contains `.env` files or credentials, mount it with `--ro` and manage secrets outside the mount path.
- **Use `pass` or `age` for encrypted storage.** These tools decrypt on demand and don't leave plaintext on disk.

---

## Backup strategy

Claude's persistent state lives in the `$ClaudePersistenceDir` folder on your Windows host (default: `D:\.claude`). This contains your Claude login, settings, memory, and conversation history.

**What to back up:** The entire `$ClaudePersistenceDir` folder.

**How:**

```powershell
robocopy D:\.claude D:\Backups\.claude /MIR
```

Or include it in your existing Windows backup job.

**Recovery:** Restore the folder, then run `.\Update-ClaudeSandbox.ps1` to verify everything is wired up correctly.

**What you lose without a backup:** Re-authentication with Claude, all conversation memory, custom settings and permission rules.
