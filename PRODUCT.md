# Product

> **[OPTIONAL — Tier-2 knowledge doc].** The standing product vision: *why* this product
> exists, *who* it's for, and what it will and won't do. Unlike the per-feature briefs in
> `docs/discovery/`, this is the one stable, big-picture document — fill it once, revisit
> rarely. Operational config (stack, rules, commands) lives in `.claude/context.md`, not here.
>
> **Read by:** `/discovery` (intake + keeps the index below current), `/planner` (checks new
> tasks align with the vision and respect non-goals). Both treat this file as optional — if
> it's absent they simply proceed.

---

## Vision

[One paragraph — the change this product makes in the world. The north star.]

## Who it's for

This table is the **persona index** — the lean summary. Each persona the product will keep designing
for gets a full HCD profile under `docs/personas/<slug>.md` (jobs, goals, pains/gains, context,
scenario), written by `/discovery`; link it from the last column.

| Persona | Job-to-be-done | Why they care | Profile |
|---|---|---|---|
| [Primary persona] | [What they're trying to accomplish] | [The pain it removes] | [docs/personas/&lt;slug&gt;.md](docs/personas/) |
| [Secondary persona] | … | … | — (JTBD-only) |

> Keep personas in sync with the roles in `.claude/context.md`. `/planner` validates every task's
> User-value persona against this table — a persona must exist here before a task can reference it.

## Problem

[What is hard, slow, or broken today — and the cost of leaving it unsolved.]

## Goals

- [Outcome the product is trying to achieve]
- …

## Non-goals (explicitly out of scope)

- [What this product deliberately does **not** do — the boundary that keeps scope honest]
- …

## Success metrics

- [Measurable signal that the product is working]
- …

---

## PRDs (index)

Each initiative gets a detailed **Product Requirements Document (PRD)** under
`docs/discovery/<slug>.md`, written by `/discovery`. This table is the map from the vision above to
those per-initiative PRDs.

| Initiative | PRD | Status |
|---|---|---|
| [Feature name] | [docs/discovery/&lt;slug&gt;.md](docs/discovery/) | Draft / Planned / Shipped |

> `/discovery` appends a row here each time it writes a new PRD.
