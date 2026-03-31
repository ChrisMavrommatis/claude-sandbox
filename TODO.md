# TODO

Items deferred to a future session or pending a decision before implementation.

## Update-ClaudeSandbox -- to be determined

An update script (`Update-ClaudeSandbox.ps1` / `Update-Sandbox`) was removed because
it referenced flat asset files (`managed-settings.json`, `managed-policy.md`) that no
longer exist after the policy system moved to the tiered `policies/<name>/` structure.

Before re-adding it, decide how to handle policy re-deploy:

- **Option A** -- Add a `Policy` key to `$Config` (e.g. `Policy = "default"`).
  `Update-Sandbox` reads it and calls `Set-SandboxPolicy`. The config becomes the
  source of truth for which tier re-deploys on update.
- **Option B** -- Omit policy re-deploy from the update script entirely.
  `Change-Policy.ps1` remains the sole way to switch or re-apply a policy.

The update script itself is straightforward once this is resolved:
apt upgrade, re-deploy profile and workflow, re-deploy policy (if Option A), verify.

## First release

When the project is first published or shared, create `CHANGELOG.md` following the
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format. Start with a single
`[1.0.0]` entry dated the release date. Do not reconstruct pre-release development
history -- start clean from the public baseline.
