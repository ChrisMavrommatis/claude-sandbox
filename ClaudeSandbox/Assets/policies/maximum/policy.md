# Sandbox Policy -- Maximum

This is the strictest policy. It enforces bubblewrap sandbox mode on every
session, blocks all outbound network tools, package managers, and git push,
and prevents users from widening permissions or bypassing prompts. Intended
for environments where Claude must operate under the tightest possible controls.

## Rules

- Never modify files outside the current working directory without explicit user approval
- Never modify /etc/wsl.conf, /etc/fstab, or /etc/sudoers.d/
- Never read or print the contents of .env files, credentials, or API keys unless the user explicitly asks
- Never run commands that delete the home directory, system files, or mounted project roots
- If you encounter credentials in source code, warn the user instead of using them
- Never push to remote git repositories without explicit user approval
- Never install packages (apt, pip, npm --global) without explicit user approval
- Never change file permissions to world-writable (chmod 777)

## Blocked commands (enforced -- cannot be overridden)

- `rm -rf /*` -- full filesystem wipe
- `dd` -- raw disk writes
- `mkfs` -- filesystem formatting
- `curl` -- outbound HTTP requests from bash
- `wget` -- outbound HTTP requests from bash
- `git push` -- remote pushes
- `chmod 777` -- world-writable permissions
- `pip install` / `pip3 install` -- Python package installs
- `npm install -g` -- global Node package installs
- `apt-get install` / `apt install` -- system package installs

## Enforcement notes

- Sandbox mode is always active (bubblewrap). The /sandbox toggle has no effect.
- Bash network traffic is filtered to the approved domain list above.
