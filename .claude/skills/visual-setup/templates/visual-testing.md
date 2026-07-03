# Visual baseline testing

> Scaffolded by `/visual-setup`. This project has visual testing **enabled** — see the
> `Visual testing` block in `.claude/context.md` for the exact tier, pinned image, and paths.

## The loop

1. **Run** the visual suite in the pinned container (local == CI):
   ```bash
   docker compose -f docker-compose.visual.yml run --rm visual
   ```
2. **Look** at any diff — baseline vs candidate vs diff, side by side:
   ```bash
   npx playwright show-report
   ```
3. **Approve** an intended change (HUMAN only — agents are blocked):
   ```bash
   docker compose -f docker-compose.visual.yml run --rm visual \
     npx playwright test -c {{VISUAL_CONFIG}} --update-snapshots
   ```
4. **Commit** the changed PNGs. The committed baseline *is* the approval record.

## Where the screenshots go

Two kinds of output, opposite fates:

| Output | Location | Commit? |
|---|---|---|
| **Baselines** — blessed reference PNGs (`toHaveScreenshot`) | `{{VISUAL_TEST_DIR}}/__screenshots__/…-<platform>.png` | ✅ **yes** — they *are* the approval record |
| **Run artifacts** — actual/diff PNGs + traces | `test-results/visual/` | ❌ no (gitignored, regenerable) |
| **HTML report** — the side-by-side viewer | `playwright-report/` | ❌ no (gitignored) |

Only the baselines are committed. `test-results/` and `playwright-report/` are already in
`.gitignore`. Change the baseline location via `snapshotPathTemplate` in the config; change the
throwaway location via `outputDir` (keep it under a gitignored path).

## Determinism — why the container is non-negotiable

Screenshots differ across OSes on fonts and anti-aliasing. Baselines are therefore only
valid when captured in the **pinned image** (`docker-compose.visual.yml`), and CI must use
the **identical tag**. Baseline filenames carry a `{platform}` suffix so per-OS captures
never overwrite each other. Approve baselines rendered in this container — never a local
host render — or approved pixels will re-fail in CI.

## Worker sizing

`workers` is set **explicitly** (`PW_WORKERS`), never auto-detected: inside a container
`os.cpus()` reports the host's cores, not the container limit, so autodetect
over-subscribes and thrashes. Keep `PW_WORKERS` in lockstep with the container's `cpus`
limit — budget ~1 vCPU + ~1.5 GB RAM per worker. Split a large suite across CI runners
with `--shard=<i>/<n>`.

## Who may re-baseline

Only a **human at the terminal** or the **Tier 3 review app**. The `guard-visual-update`
hook blocks agents from `--update-snapshots`, so an agent can never silently bless a
regression. Agents *read* approval state (`/visual-review`); they do not create it.
