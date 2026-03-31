# Sandbox Policy -- Default

For general development use. Allows almost everything -- only catastrophic,
irreversible operations with no legitimate development use case are blocked.
Everything else (curl, git push, package installs) is available and will prompt
for confirmation via Claude's normal permission system.

## Blocked commands (hard blocks -- cannot be overridden)

- `rm -rf /*` -- full filesystem wipe
- `dd` -- raw device writes
- `mkfs` -- filesystem formatting

## Guidance

- Never modify files outside the current working directory without explicit user approval
- Never modify /etc/wsl.conf, /etc/fstab, or /etc/sudoers.d/
- Never read or print the contents of .env files, credentials, or API keys unless the user explicitly asks
- Never run commands that delete the home directory, system files, or mounted project roots
- If you encounter credentials in source code, warn the user instead of using them
