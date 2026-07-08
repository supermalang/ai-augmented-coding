# Autonomy trigger — self-starting pipeline (opt-in)

By default the pipeline is **pull**: a human runs `/ship-task`. The autonomy trigger makes it
**push** — a schedule or an event starts a batch run on its own. It is **off by default** (`Mode:
manual` in `.claude/context.md` → *Autonomy trigger*); a project opts in deliberately.

This is WP3 of the loop-3 foundations: the event layer that lets the loop start itself. It does **not**
add parallelism (Concurrency stays 1) and does **not** cross any human gate.

---

## What a triggered run may and may not do

A trigger is a thin CI step that invokes the batch pipeline:

```bash
/ship-task open <Max tasks per run>
```

**It may:** validate DoR, branch, implement, test, review, and **open PRs** into the PR target branch
(`develop`); append a WP1 **run trace** to each delivered task; stop and record a reason when blocked.

**It must never** (the three human gates stay human, exactly as in an interactive run):

| Gate | Who | Enforced by |
|---|---|---|
| **Merge** PR → `develop` | human | `/ship-task` never merges; branch protection on `develop` |
| **Bless** visual baselines | human | `guard-visual-update` blocks agent `--update-snapshots` |
| **Promote** `develop` → `main` | human | `/ship-task` never targets `main`; branch protection on `main` |

All `guard-*` hooks stay active in a triggered run — the trigger changes *when* the pipeline starts,
never *what it is allowed to do*.

---

## Guardrails (why an unattended run is safe)

- **Bounded.** `Max tasks per run` caps how many ready tasks one run ships (`/ship-task open <cap>`);
  the rest wait for the next run. Concurrency is **1** — tasks ship sequentially. Raising it needs
  worktrees (see [`parallel-work.md`](parallel-work.md)); do not raise it here.
- **PRs only.** Every task ends at an **open PR** the human validates and merges. A triggered run that
  reaches the visual-approval gate **parks** the task (no PR) and moves on — it never idles.
- **Stops with a reason, never hangs.** A headless run cannot answer a prompt. On a repeated block
  (DoR failure, RED gate, tests still failing after the debugger retries, review blockers) the task is
  recorded with its **run-trace stop reason** and the batch moves to the next task; the run summary
  lists every blocked/deferred task. Nothing waits for input.
- **Auditable after the fact.** Each delivered task carries a WP1 `### Run trace` block (skills
  invoked, review blockers/warnings, debugger retries, stop reason). `/retro` reads them to explain
  *why* an unattended sprint went the way it did.
- **Inert by default.** With `Mode: manual` no trigger exists. Turning it on is a deliberate,
  reviewed change.

---

## Wiring it (per CI adapter)

Keep the adapter matching `CI provider` in `.claude/context.md`; the trigger honours the
*Autonomy trigger* keys.

| Adapter | Trigger file | Fires on |
|---|---|---|
| `github/` | `autonomy-trigger.yml` | `schedule:` cron and/or `workflow_dispatch` (manual button) |
| `gitlab/` | a scheduled pipeline running the same command | pipeline schedule |
| `container/` | cron on the host invoking the headless runner | crontab |

Each runs the project's headless Claude Code invocation with the prompt `/ship-task open <cap>`. The
unattended forge token (`GH_TOKEN` / `GITLAB_TOKEN`, see *Version control & forge*) must be in the
environment so push + PR creation work without an interactive login.

> **Condition → mechanism.** `schedule` → cron; `event` (e.g. *task labeled ready*, *push to
> develop*) → the adapter's event hook (webhook / `on: push`). Both end in the same
> `/ship-task open <cap>` call — only the start signal differs.
