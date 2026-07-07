# Visual baseline testing

> Scaffolded by `/visual-setup`. This project has visual testing **enabled** — see the
> `Visual testing` block in `.claude/context.md` for the exact tier and paths. Everything lives
> under one `visual-review/` folder and runs **in-project — no container**.

## The loop

1. **Run** the visual suite (Playwright serves the app in-project via `webServer`):
   ```bash
   npx playwright test -c visual-review/playwright.visual.config.ts
   ```
2. **Look** at any diff — baseline vs candidate vs diff, side by side:
   ```bash
   npx playwright show-report visual-review/results/report
   ```
3. **Approve** an intended change (HUMAN only — agents are blocked):
   ```bash
   npx playwright test -c visual-review/playwright.visual.config.ts --update-snapshots
   ```
4. **Commit** the changed PNGs. The committed baseline *is* the approval record.

## Where everything goes — one folder

```
visual-review/
  playwright.visual.config.ts   # config (paths below are relative to it)
  specs/          *.visual.spec.ts        ✅ committed
  baselines/      …-<platform>.png        ✅ committed — they ARE the approval record
  results/        actual/diff + report     ❌ gitignored (regenerable)
  uat/            /qa-tester review shots   ❌ gitignored (throwaway)
  visual-approvals.json                     ✅ committed
```

Only `visual-review/results/` and `visual-review/uat/` are gitignored; everything else under
`visual-review/` is committed. Change paths via `snapshotDir` / `outputDir` in the config (keep
throwaway output inside a gitignored path). Full-route screenshots are the whole surface — there is
no Storybook or review-app tier.

## Determinism — without a container

Screenshots differ across OSes on fonts and anti-aliasing, so baseline filenames carry a
`{platform}` suffix (`…-linux.png` / `…-darwin.png` / `…-win32.png`) — per-OS captures never clash.
The one rule that replaces the pinned container: **bless baselines on the same OS your CI runs on**
(run the visual job on a matching runner — the `CI OS` field in `context.md`). A small
`maxDiffPixelRatio` absorbs sub-pixel noise. Approve on the CI OS, or approved pixels may re-fail in
CI. Split a large suite across CI runners with `--shard=<i>/<n>`.

## Who may re-baseline

Only a **human at the terminal**. The `guard-visual-update` hook blocks agents from
`--update-snapshots`, so an agent can never silently bless a regression. Agents *read* approval state
(`/visual-review`) and can *inspect* the diff report (`/visual-report`); they do not create approvals.
