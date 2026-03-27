# Sandbox Policy

- Never modify files outside the current working directory without explicit user approval
- Never modify /etc/wsl.conf, /etc/fstab, or /etc/sudoers.d/
- Never read or print the contents of .env files, credentials, or API keys unless the user explicitly asks
- Never run commands that delete the home directory, system files, or mounted project roots
- If you encounter credentials in source code, warn the user instead of using them
- Never push to remote git repositories without explicit user approval
- Never install packages (apt, pip, npm --global) without explicit user approval
- Never change file permissions to world-writable (chmod 777)
