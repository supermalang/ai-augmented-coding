# Health gate + rollback (spec) — default off

A **post-deploy machine safety check**: after a release deploys, run a smoke/health check against the
project's SLOs; if it fails, **auto-rollback** to the previous release and record the incident. This
is the piece that later makes auto-deploy to production *safe* — but it ships as a **disabled spec**
until a project has both a deploy pipeline and an observability sink.

**Default OFF.** `.claude/context.md` → *Observability (runtime)* → `Health gate: false`. While off,
[`observability/health-gate.sh`](../observability/health-gate.sh) is a no-op and nothing changes.

## Where it lives — and where it does NOT

- **Lives at the deploy boundary the project owns** — its deploy/release pipeline calls the health
  gate as a post-deploy step.
- **NOT wired into `/ship-task`** and **NOT into `develop → main` promotion.** The pipeline still ends
  at an open PR a human merges; promotion stays human. The health gate adds a *machine* check at
  deploy time, **not a new human gate** — the three human gates (merge / bless / promote) are unchanged.

## The contract (when a project enables it)

1. **Deploy** the release (project's own step).
2. **Check** — run `HEALTH_CHECK_CMD`: a smoke/health probe that evaluates the live release against the
   `SLOs` in `context.md` (e.g. error-rate and p95 latency over a short window). Exit 0 = healthy.
3. **Pass** → done; optionally emit a `deploy` marker via [`emit.sh`](../observability/emit.sh).
4. **Fail** → run `ROLLBACK_CMD` to revert to the last known-good release, **record the incident**
   (`emit.sh error …`), and exit non-zero so the pipeline marks the release failed.

```bash
# At the project's deploy boundary, after the deploy step (only acts when Health gate: true):
observability/health-gate.sh "$RELEASE_VERSION"
```

## Configuration

| Key | Where | Meaning |
|---|---|---|
| `Health gate` | `context.md` → Observability | `true` to arm the gate (default `false`) |
| `SLOs` | `context.md` → Observability | the thresholds the check evaluates against |
| `HEALTH_CHECK_CMD` | env / deploy pipeline | `[CONFIGURE]` the smoke/health probe (exit 0 = healthy) |
| `ROLLBACK_CMD` | env / deploy pipeline | `[CONFIGURE]` revert to previous release |
| `Sink` | `context.md` → Observability | where the recorded incident goes (adapter) |

## Why it stays off in the template

The template is stack-agnostic and has no app, deploy pipeline, or sink. Arming a health gate without
those would create a half-configured failing state — the opposite of the Tier-0-inert principle. A
project turns it on deliberately once it has a real deploy target and a configured sink.
