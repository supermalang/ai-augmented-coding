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

| Persona | Job-to-be-done | Why they care |
|---|---|---|
| [Primary persona] | [What they're trying to accomplish] | [The pain it removes] |
| [Secondary persona] | … | … |

> Keep personas in sync with the roles in `.claude/context.md`.

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

## Feature briefs (index)

Each initiative gets a detailed product brief under `docs/discovery/<slug>.md`, written by
`/discovery`. This table is the map from the vision above to those per-feature briefs.

| Initiative | Brief | Status |
|---|---|---|
| [Feature name] | [docs/discovery/&lt;slug&gt;.md](docs/discovery/) | Draft / Planned / Shipped |

> `/discovery` appends a row here each time it writes a new brief.
