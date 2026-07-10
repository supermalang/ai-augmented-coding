# Runtime observability — vendor-neutral, default-off

Health of the **deployed app** (errors, key metrics, deploy markers, SLOs) — *not* the build-time
**run traces** (WP1), which record what the pipeline did. This folder is a **documented integration
point**, not live instrumentation: the template is stack-agnostic and has no app, so a project fills
the adapter for its backend when it turns observability on.

**Default OFF and inert.** While `.claude/context.md` → *Observability (runtime)* → `Enabled: false`,
[`emit.sh`](emit.sh) exits before loading anything — no emit, no cost, no dependency. The template
behaves exactly as if this folder were absent. Everything below applies **only when a project enables it**.

## The emit interface

One entrypoint, three event kinds — the whole vendor-neutral contract:

```bash
observability/emit.sh error  "<message>" ["<context>"]   # a structured runtime error
observability/emit.sh metric "<name>" "<value>"          # a key metric sample
observability/emit.sh deploy "<version>" ["<env>"]        # a deploy/version marker
```

`emit.sh` reads `Enabled` and `Sink` from `context.md`, then — when enabled — hands the event to the
**Sink command** (the adapter). It never knows which vendor is behind the sink.

## Adapter pattern (mirrors `ci-adapters/`)

The `Sink` in `context.md` points at one **adapter** — a command that receives `<kind> <args…>` and
forwards it to a backend. Reference adapters live in [`adapters/`](adapters/); **keep the one that
matches your backend, delete the rest**, and set `Sink` to it. No vendor is referenced in `emit.sh`
or anywhere in the core — the adapter is the only vendor-aware piece.

| Adapter | Forwards via |
|---|---|
| `adapters/webhook.sh` | HTTP POST of a JSON event to a `[CONFIGURE]` endpoint (`OBS_WEBHOOK_URL`) |
| `adapters/stdout.sh` | prints a structured JSON line (local dev / a log collector scrapes stdout) |
| `adapters/otel.md` | notes for wiring an OpenTelemetry/collector exporter in the project's own runtime |

## Enabling it (project checklist)

1. Set `Enabled: true` in `context.md` → *Observability (runtime)*.
2. Fill `Sink` (path to your chosen adapter), `Emit`, and `SLOs`.
3. Fill the adapter's `[CONFIGURE]` endpoint/credentials (via env — never commit secrets).
4. Call `emit.sh` from your app's error handler / deploy step (or wire the adapter into your runtime SDK).
5. Optional: turn on the **Health gate** (`Health gate: true`) — see [`docs/health-gate.md`](../docs/health-gate.md).

## What this is not

- **Not** the build-time run traces (`### Run trace` in the roadmap) — that is pipeline history.
- **Not** wired into `/ship-task` or `develop → main` promotion. The **Health gate** is a machine
  safety check at the **deploy boundary a project owns**; it adds no new human gate, and the three
  human gates (merge / bless / promote) are unchanged.
- **Not** a bound vendor — enabling picks an adapter; the core stays neutral.
