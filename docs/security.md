# Using Claude Safely

## How the sandbox protects you

Claude runs inside an isolated Linux environment that is intentionally cut off from the rest of your Windows machine. Your Windows files are invisible to Claude by default — no project is accessible until you explicitly mount it. Claude also cannot see or call anything on your Windows host, so there is no risk of it accidentally (or otherwise) touching files outside the sandbox.

Think of it as a locked room. You decide what goes in, and nothing leaks out.

---

## Only give Claude access to what it needs

Projects are not mounted automatically. You bring them in when you need them and remove them when you are done:

```bash
mount-project my-app --ro    # read-only: Claude can look but not touch
mount-project my-app --rw    # read-write: Claude can make changes
unmount-project my-app       # close the door when you're done
```

If you are just asking Claude to review or explain code, mount read-only. Claude will still be able to read every file — it just cannot make any changes.

---

## Control how much Claude can do in a session

You can dial Claude's autonomy up or down depending on how much you trust the task:

```bash
claude --permission-mode plan          # Claude can only read and plan — no changes at all
claude --permission-mode acceptEdits   # Claude can edit files freely, but will still ask before running commands
claude --dangerously-skip-permissions  # Claude acts without asking — fine here since the sandbox already limits what it can reach
```

`plan` mode is a good starting point when you are exploring a new project or asking Claude to figure out a complex problem. You review the plan, then decide whether to let it proceed.

`--dangerously-skip-permissions` sounds alarming but is reasonable inside this sandbox — the isolation is handled at the environment level, not by the prompts.

---

## Use a separate branch for big changes

If Claude is about to make a lot of changes and you are not sure you will like all of them, start a worktree session:

```bash
claude -w
```

Claude works on a separate branch. Your main codebase is untouched until you choose to merge. If the result is not what you wanted, you can discard the whole branch without any cleanup.

---

## Tell Claude what is off-limits in each project

Create a `CLAUDE.md` file in the root of your project. Claude reads it automatically at the start of every session. Use it to set clear rules:

```markdown
## Off-limits
- Never modify anything in src/legacy/
- Never read or print the contents of .env files
- Do not commit directly to main — always use a feature branch
```

This does not require any technical configuration — Claude understands plain instructions and will follow them.

---

## Block specific actions permanently

If there are commands you never want Claude to run in any project, you can block them in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "deny": ["Bash(rm -rf:*)", "Bash(curl:*)", "Bash(wget:*)"]
  }
}
```

You can also do this per project by placing the same file in `<project>/.claude/settings.json`.

---

## Check what Claude did before you move on

It only takes a few seconds and saves a lot of headaches:

```bash
git diff              # see every file that changed
git log --oneline -5  # see what was committed
```

If something looks wrong, you can undo the last commit with `git reset HEAD~1` and the files will go back to how they were.
