# Project Context

> Fill in this file when you adopt the template. Every pipeline agent reads it at the start
> of each task. Keep it concise — agents read it on every run.
>
> This is the **Tier-1 operational** doc: short facts every agent needs each run. Deep
> architectural detail (system shape, decisions, trust boundaries, hot paths, the standard API
> route pattern) belongs in the optional Tier-2 doc [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md),
> not here — keep the every-run file lean. Product vision lives in `PRODUCT.md`, design language
> in `DESIGN.md`. A fact belongs in exactly one place; don't duplicate across tiers.

---

## Project

**Name:** [Your project name]
**Description:** [One sentence — what it does, for whom]
**Compliance / standards:** [e.g. ISO 27001, GDPR, none]
**Multi-tenant / multi-site:** [yes/no — if yes, describe the isolation key, e.g. `tenantId`]

---

## Tech stack

[List key frameworks and versions — e.g.]
- Next.js 15 (App Router) · React 19 · TypeScript
- Prisma v5 (PostgreSQL)
- Tailwind CSS + shadcn/ui
- Vitest · Playwright

---

## Key commands

```bash
npm run dev          # dev server
npm run build        # production build
npm run lint         # ESLint
npm run test:run     # Vitest single run
npm run test:coverage # Vitest + coverage thresholds
```

---

## Absolute rules

> These are non-negotiable constraints enforced throughout the pipeline.
> Add, remove, or reword to match your project.

1. **[RULE NAME]** — [what must always / never happen, and why]
2. **[RULE NAME]** — [what must always / never happen, and why]
3. **Soft delete only** — never call `.delete()` on ORM models; set `deletedAt = new Date()` instead
4. **Audit log is insert-only** — never update or delete rows in the audit table
5. **Never expose secrets** — [field names that must never appear in API responses, e.g. `passwordHash`]

---

## Roles and access

| Role | Description | Access level |
|------|-------------|--------------|
| [ROLE_A] | [description] | [full / read-only / scoped] |
| [ROLE_B] | [description] | [full / read-only / scoped] |

---

## Data isolation

[Describe how data is scoped, e.g.:]
- Every database query must include `where: { tenantId, deletedAt: null }`
- `tenantId` comes from the JWT session, never from the request body

---

## Domain glossary

| Term | Definition |
|------|------------|
| [Term] | [What it means in this project] |
| [Term] | [What it means in this project] |

---

## UI conventions

- **Language:** [e.g. French / English / Arabic]
- **Icon library:** [e.g. lucide-react — no mixing]
- **Component library:** [e.g. shadcn/ui]
- **Status badge classes:** [document exact Tailwind classes per status, e.g. ACTIVE → `bg-green-100 text-green-800`]
- **Toast library:** [e.g. Sonner]

### Brand assets (reporting)

Exact values used by `/report` to brand PDF decks and PowerPoint exports. The *feel* is in `DESIGN.md`.

- **Logo:** [path, e.g. `assets/brand/logo.svg`]
- **Brand colors:** [primary `#......` · accent `#......` · ink/text `#......` · surface `#......`]
- **Deck fonts:** [heading font · body font — names that exist on the render machine or are embedded]
- **Default deck style:** [`classical` | `notebooklm` | `sketch` | `illustrated`]
- **Image generation (for `illustrated` style only):** [provider + model, e.g. `kie.ai` / `nano-banana`] · API key env var: [e.g. `KIE_API_KEY`] — *key lives in env, never committed*

---

## File structure conventions

```
src/app/          # Next.js App Router pages and API routes
src/lib/          # Pure business logic (tested with Vitest)
src/components/   # Shared UI components
prisma/           # Schema and migrations
tests/e2e/        # Playwright specs
```

---

## Reference formats

[Document any auto-generated reference numbers, e.g.:]
- Record ID format: `{PREFIX}-{YYYY}-{NNNNN}` (e.g. `ORD-2026-00042`)

---

## Key constraints for agents

- [Any architectural constraint agents must respect, e.g. "always paginate — never return unbounded lists"]
- [e.g. "all mutations must call createAuditLog()"]
- [e.g. "CCP-equivalent operations require re-authentication"]
