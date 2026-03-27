# Next Steps

All implementation tasks are complete. One manual verification remains.

---

## Mermaid Diagram Rendering Check

The threat model mermaid diagram needs to render on GitHub. GitHub supports mermaid in markdown natively since 2022, so the existing ` ```mermaid ` fence should work. No code changes needed.

### Verification

After pushing to GitHub:
1. Open `docs/threat-model.md` in the GitHub web UI
2. Confirm the mermaid diagram renders as a flowchart
3. If not: check for em dashes or special characters inside the mermaid block that break the parser

### Known issue

The mermaid block uses `\n` for line breaks inside node labels. GitHub's mermaid renderer handles this, but some older renderers don't. If it breaks, replace `\n` with `<br/>` inside the node strings.
