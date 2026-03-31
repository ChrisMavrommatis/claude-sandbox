# Sandbox Policy -- Restrictive

For security-conscious developers. Blocks unattended network downloads, package
installs, remote pushes, and dangerous permission changes. When /sandbox mode is
active, outbound bash traffic is filtered to an approved domain list. Operations
like git push and package installs are blocked outright -- not just prompted.

## Blocked commands (hard blocks -- cannot be overridden)

- `rm -rf /*` -- full filesystem wipe
- `dd` -- raw device writes
- `mkfs` -- filesystem formatting
- `curl` -- outbound HTTP requests from bash
- `wget` -- outbound HTTP requests from bash
- `git push` -- remote pushes
- `chmod 777` -- world-writable permissions
- `pip install` / `pip3 install` -- Python package installs
- `npm install -g` -- global Node package installs
- `apt-get install` / `apt install` -- system package installs

## Network filtering (when /sandbox is active)

Bash network traffic is restricted to an approved domain list:
deb.debian.org, security.debian.org, *.anthropic.com, api.anthropic.com,
github.com, *.github.com, registry.npmjs.org, pypi.org, files.pythonhosted.org

## Guidance

- Never modify files outside the current working directory without explicit user approval
- Never modify /etc/wsl.conf, /etc/fstab, or /etc/sudoers.d/
- Never read or print the contents of .env files, credentials, or API keys unless the user explicitly asks
- Never run commands that delete the home directory, system files, or mounted project roots
- If you encounter credentials in source code, warn the user instead of using them
- Never push to remote git repositories
- Never install packages without explicit user approval
- Never change file permissions to world-writable
