# Architecture

> **[OPTIONAL — Tier-2 knowledge doc].** The deep technical reference: system shape, key
> components, data model, and the decisions behind them. It is read **when a task needs it**,
> not on every run — that's the difference from `.claude/context.md`, which stays short because
> every agent loads it each time. `.claude/context.md` holds the *operational* facts (commands,
> stack, rules); this file holds the *architectural* ones (how the system is put together and why).
> Keep the two from overlapping: when in doubt, short operational fact → `context.md`, deep
> explanation → here.
>
> **Read by:** `/coder`, `/schema-agent`, `/perf-review`, `/security-audit` (for system shape,
> data model, hot paths, and trust boundaries) and kept current by `/docs`. All treat this file
> as optional — if it's absent they fall back to `.claude/context.md`.

---

## System overview

**[CONFIGURE]** — describe the domain model, key relationships, and route structure. A
`/diagram architecture` Mermaid diagram here is worth a page of prose.

## Components

**[CONFIGURE]** — the major building blocks (services, layers, modules) and how they talk to
each other.

## Key technical decisions

**[CONFIGURE]** — the choices a new contributor (human or agent) would otherwise have to
reverse-engineer. One short entry each: *decision · why · trade-off accepted*.

---

## Key constraint: data isolation

**[CONFIGURE]** — document your isolation key (e.g. `tenantId`, `orgId`, `siteId`) and the rule:
every Prisma/ORM query must scope data to the active context. Document where this value comes
from (e.g. JWT session). (Operational summary also lives in `.claude/context.md`; the rationale
and edge cases live here.)

## Auth flow

**[CONFIGURE]** — describe your auth provider, session shape, and how to access it server-side.

## Standard API route pattern

```ts
// [CONFIGURE] — paste your standard API route boilerplate here so all agents follow it
const session = await getSession()
if (!session?.user?.id) return Response.json({ error: 'Unauthorized' }, { status: 401 })
// validate with Zod
// query with isolation key
// audit log on mutations
```

---

## Data model / schema reference

**[CONFIGURE]** — link to your schema cheatsheet or summarise key models here. Refresh the ERD
with `/diagram erd` whenever the model changes shape.

## Trust boundaries

**[CONFIGURE]** — where untrusted input enters the system (user input, uploads, third-party
webhooks, inter-service calls). `/security-audit` uses this to focus its review.

## Performance-sensitive paths

**[CONFIGURE]** — the hot paths and scale assumptions (expected row counts, traffic shape) that
`/perf-review` and `/perf-measure` should weigh changes against.
