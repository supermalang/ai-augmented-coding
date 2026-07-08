# CI adapters — thin, per-vendor, pick one

The test-execution **core is CI-agnostic**: `npm run test:e2e:ci` shards via
`--shard=${SHARD_INDEX:-1}/${SHARD_TOTAL:-1}` and defaults to `1/1` (the whole suite, no CI). Each
shard emits a **blob** report; `npm run test:e2e:merge` stitches one HTML report.

An adapter's *only* job is to map the vendor's parallelism variables onto `SHARD_INDEX` /
`SHARD_TOTAL`, run on the **pinned Playwright image** (byte-identical screenshots — see
`docs/visual-testing.md` and the `Playwright image` key in `.claude/context.md`), and merge the blob
reports. **Keep the one adapter that matches `CI provider` in `.claude/context.md`; delete the rest.**

| Adapter | Vendor parallelism → shard vars |
|---|---|
| `github/` | `strategy.matrix` → `SHARD_INDEX` / `SHARD_TOTAL`; build once + share artifact; cache browsers; a `merge-reports` job |
| `gitlab/` | native `parallel: N` → `CI_NODE_INDEX` / `CI_NODE_TOTAL`; `image:` = the pinned Playwright image |
| `container/` | a shell loop / `docker run -e SHARD_INDEX=… -e SHARD_TOTAL=…` on the pinned image |

Nothing here is referenced by the pipeline core; these are copy-and-adjust starting points, kept out
of the portable path on purpose (no CI vendor is named in the core).

## Per-PR preview deploy

Each adapter also ships a **preview** step that deploys the PR branch to an ephemeral environment,
posts the URL to the PR, and tears it down on close. Like the shard step it is **portable**: it calls
the `Preview command` / `Teardown command` from `.claude/context.md` (*Preview deploy* section) — it
never names a vendor. Leave those keys blank to disable (the PR's Preview link is then `None`).

| Adapter | Preview file | How the URL reaches the PR |
|---|---|---|
| `github/` | `preview.yml` | deploy on `pull_request` open/sync; comment the URL; teardown on `closed` |
| `gitlab/` | `preview.gitlab-ci.yml` | GitLab *environment* with `environment.url`; `on_stop` teardown |
| `container/` | `preview.sh up` / `down` | prints the URL on its last stdout line for a webhook/glue script to post |

`/pr-reviewer` fills the PR template's *Visual changes* → **Preview** link from this URL when present,
and writes `None` when no preview command is configured. **Merge and visual-bless stay human** — a
preview is for a person to look at and decide; it never auto-merges or blesses baselines.

## Autonomy trigger (opt-in, WP3)

A thin step that **starts** the pipeline on a schedule/event, running `/ship-task open <cap>` headless.
**Off by default** — install only when `.claude/context.md` → *Autonomy trigger* → `Mode` is
`schedule`/`event`. Guardrails and the full contract live in [`../docs/autonomy-trigger.md`](../docs/autonomy-trigger.md).

| Adapter | Trigger file | Fires on |
|---|---|---|
| `github/` | `autonomy-trigger.yml` | `schedule:` cron + `workflow_dispatch` |
| `gitlab/` | a scheduled pipeline running the same headless command | pipeline schedule |
| `container/` | host cron invoking the headless runner | crontab |

A triggered run **opens PRs only** — it never merges, never blesses baselines, keeps all guard hooks
active, bounds itself with `Max tasks per run` (Concurrency 1), and stops-with-reason on repeated
blocks (a headless run can't answer a prompt).
