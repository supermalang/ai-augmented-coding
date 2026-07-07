# PR template (canonical)

> The **fixed shape** every PR takes, ordered so the reviewer can approve/reject in ~30 seconds
> without opening the diff (the diff is last on purpose). `/pr-reviewer` fills every section in this
> order; empty sections say `None`, never blank.
>
> **[CONFIGURE — github | gitlab]** copy the body below to the path your host reads, so it
> auto-populates new PRs (mirrors `ci-adapters/` — keep the one for your host):
> - GitHub → `.github/PULL_REQUEST_TEMPLATE.md`
> - GitLab → `.gitlab/merge_request_templates/Default.md`

---

```markdown
## Summary
<one line: what changed and why> · Task: <ROADMAP task link>

## Acceptance criteria
<checklist copied from the task, each box ticked when met>
- [ ] …

## Visual changes
<For UI work: the preview link + a link to the visual expected/actual/diff report.
 "None" if no UI change. Raw gitignored result PNGs are NOT pasted — link the report/preview instead.>
- Preview: <preview URL, or "none">
- Visual report: <link to the CI visual-report artifact, or `/visual-report` output if inline>

## Checks & facts
- CI: <green / red — link>
- Estimate: <story points>   ·   Cycle time: <Delivered − Started>   ·   Perf: <blockers/breaches or "none">

## Risk flags
<one line each, only if present — these tell the reviewer "look harder">
- ⚠️ Schema migration   ·   ⚠️ Auth/permissions   ·   ⚠️ Dependency change

## Details
<the diff — the platform renders it automatically; kept last, it's the last resort not the first look>
```

---

**Screenshot boundary:** a screenshot or preview in a PR is for the **human to look at and decide**.
The pipeline never blesses its own visual baselines — showing a screenshot and approving a baseline
are different acts, and only the human does the second (`guard-visual-update` enforces it).
