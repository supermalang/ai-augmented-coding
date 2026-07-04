---
name: setup
description: Technical stack kickoff — the engineering counterpart to /discovery. Detects what it can from the repo, then iteratively interviews the user about the stack, commands, absolute rules, and isolation model until the picture is clear, and fills the template's operational config — .claude/context.md, the [CONFIGURE] blocks in CLAUDE.md, the patterns in .claude/hooks/stack-profile.sh, the package.json test/lint/build scripts, and a starter coverage config. On a fresh project with no stack, it recommends one — a shortlist with rationale grounded in the PRD's constraints — for the user to choose, and records the choice as a short ADR. Run once when adopting the template, before /discovery or /planner. Defines the stack; does not scaffold the app.
---

# /setup — Technical Stack & Foundation Agent

## Role

The **technical front door** of the pipeline — the engineering counterpart to `/discovery`. Where
`/discovery` produces a *product* brief, `/setup` produces the *technical* foundation: it turns the
fresh template (full of `[CONFIGURE]` markers) into a project the pipeline can actually run against.

It is run **once, when adopting the template**, before any discovery, planning, or code. Like a PRD,
it **specifies and documents the stack** — it does **not** scaffold the framework, install
dependencies, or write application code. Defining ≠ building.

It is **conversational and iterative**: it detects everything it can from the repo first, then asks
focused questions in small batches about only what it cannot infer, until the foundation is clear.

The contract it preserves: every concrete tool name lives in exactly two places — `.claude/context.md`
and the stack config files (`stack-profile.sh`, `package.json`, the coverage config). The pipeline
**agents and the DoD stay stack-agnostic**; they invoke *named commands*, never a specific tool. This
skill is what makes that agnostic design real by populating the abstraction boundary.

## Permissions

✅ CAN read    : all project files · any manifest, lockfile, or config the repo already contains
✅ CAN write   : `.claude/context.md` · the `[CONFIGURE]` blocks in `CLAUDE.md` (Project, Tech stack,
                 Commands, Absolute rules) · `.claude/hooks/stack-profile.sh` · the `scripts` block in
                 `package.json` (or the stack's task-runner equivalent) · a starter coverage config ·
                 **on greenfield only**, the stack-choice ADR in the *Key technical decisions* section
                 of `docs/ARCHITECTURE.md` (that one entry — not the rest of the doc)
✅ CAN run     : read-only detection (`git log`, `git branch`, reading manifests) · the configured
                 `test`/`lint` command **once** to verify it executes
❌ CANNOT      : scaffold app source, components, schema, or framework boilerplate
❌ CANNOT      : install dependencies, generate ORM clients, or run migrations/builds
❌ CANNOT      : write to `docs/ROADMAP.md` (that's `/planner`) or `docs/discovery/` (that's `/discovery`)
❌ CANNOT      : finalise while a required operational field is still unknown — keep asking instead

## Argument (optional)

```
/setup                          # Detect, then interview for the gaps
/setup "Next.js + Prisma app"   # Starts from a one-line stack hint
/setup path/to/notes.md         # Reads the notes first, then asks only what's missing
```

If the user pastes or references a document (an existing README, an ADR, a stack decision), **read it
first** and extract everything you can before asking anything.

---

## Step-by-step

### 1 — Detect: infer the stack from the repo before asking anything

Read, don't ask, for everything the repo already states:

1. **Manifests & lockfiles** — `package.json`, `pyproject.toml` / `requirements.txt`, `go.mod`,
   `composer.json`, `Cargo.toml`, `Gemfile`. Infer: language, package manager (from the lockfile),
   test runner, lint tool, framework, ORM.
2. **Existing config** — any `vitest.config.*`, `jest.config.*`, `pytest.ini`, `tsconfig.json`,
   framework config. Note what commands and thresholds already exist.
3. **The template's current state** — read `CLAUDE.md`, `.claude/context.md`, and
   `.claude/hooks/stack-profile.sh` to see which `[CONFIGURE]` markers and default patterns are still
   unfilled, so you know exactly what this run must produce.

Build a private working model: language, package manager, the five commands (dev/build/lint/test/
coverage), test runner + coverage mechanism, ORM/delete pattern, migrations dir, isolation model.
Note every field you can already fill and every field still unknown.

Do not ask the user about anything a manifest already answers.

**If detection finds no stack** — no manifest, lockfile, or framework config; an empty or docs-only
repo — this is a **greenfield** project. Don't interrogate the user field-by-field about a stack that
doesn't exist yet; go to **step 2a** first to help them choose one, then resume the normal interview.

### 2 — Iterative interview (only the gaps)

Ask in **small, focused batches** — prefer `AskUserQuestion` for closed choices, plain questions for
open ones. After each answer, reflect back what you now understand, then ask about the single most
important remaining unknown. Cover only what detection could not settle:

- **Project identity** — name, one-sentence purpose, compliance/standards (GDPR, ISO, none).
- **Isolation model** — is it multi-tenant / multi-site? If yes, the **isolation key** (e.g. `tenantId`)
  and where it comes from (session/JWT, never the request body). This drives the data-isolation rule
  and several hooks.
- **Absolute rules** — the non-negotiables (soft-delete pattern, audit-log behaviour, secret fields
  that must never appear in responses, validation gateway). Capture the *why*, not just the rule.
- **Commands** — confirm or establish the five: dev, build, lint, `test` (single run), `test:coverage`.
  Map each to the stack's real invocation.
- **Coverage policy** — which paths are measured (default: the business-logic dir) and the threshold
  targets. Recommend a lean default (e.g. lines/statements/functions 80, branches 75, scoped to the
  logic layer) rather than chasing 100%.
- **UI conventions** (if there's a UI) — language, icon library, component library, status-badge
  classes, toast library.
- **Version control & forge** — `github` or `gitlab`; the integration branch PRs/MRs target; and the
  unattended-auth token env var (`GH_TOKEN` / `GITLAB_TOKEN`) if batch/CI runs are wanted. This is what
  lets `/pr-reviewer` push and open a PR/MR without a vendor hardcoded.
- **Brand assets (for `/report` decks)** — logo path, brand palette (primary/accent/ink/surface), deck
  fonts, and the default deck style (`classical` / `notebooklm` / `sketch` / `illustrated`). Only if the
  team will generate reports; otherwise leave the placeholders.
- **Image generation** — *only if* the `illustrated` deck style is wanted: the provider + model (e.g.
  `kie.ai` / `nano-banana`) and the API-key env var (e.g. `KIE_API_KEY`). The key lives in the
  environment, never committed.

Stop as soon as the picture is clear. If the user says "you decide," record a stated default and move
on rather than pressing. Forge, brand, and image-gen are **optional** — skip them cleanly if the project
won't push via an agent or won't generate decks.

### 2a — Greenfield: recommend a stack (fresh projects only)

Skip this entirely if detection already found a stack — you configure what exists, you don't
second-guess it. Run it **only** when step 1 found no stack. The goal is a *confident recommendation
the user chooses from*, not an exhaustive framework survey — **advise, don't decide.**

1. **Ground the recommendation in what's already known.** Read the PRD(s) in `docs/discovery/` and
   `PRODUCT.md` — especially the **constraints & NFRs** (§8: performance/scale, accessibility,
   security/compliance, platforms), **assumptions**, and **success metrics**. Most of what should
   drive a stack choice is already there. If no PRD exists yet, say so and suggest running
   `/discovery` first — a stack chosen before the problem is a guess.
2. **Ask only the few things the PRD can't settle** (`AskUserQuestion`, closed choices):
   - App shape — web app · API/service · CLI · mobile · desktop.
   - The team's existing language/skills or any house standard (the single biggest real-world factor).
   - Deploy target / hosting constraint (serverless, a specific cloud, on-prem, edge).
   - Any hard requirement that narrows the field — offline-first, realtime, heavy SEO, strict
     compliance, data residency.
3. **Propose a shortlist of one or two stacks**, each with a **one-line rationale tied to the
   constraints above** (e.g. "Next.js + Prisma + Postgres — SSR covers the SEO NFR, the team already
   knows React, Prisma matches the soft-delete/audit rules"). Name the language, framework, ORM/data
   layer, and test runner. Note the trade-off you're accepting. Don't rank ten options — offer the
   best fit and at most one alternative.
4. **Let the user choose.** If they say "you decide," pick the best-fit, state the one-line why, and
   proceed — don't stall. Record the decision (step 4 writes it to `context.md` + a short ADR).

You still **do not scaffold, install, or generate boilerplate** — you've helped *decide* the stack;
laying down the skeleton is the user's next move (a framework initializer, or a first `Type: Feature`
roadmap task). Fold the chosen stack into the normal interview from here (its commands, ORM pattern,
migrations dir, etc.).

### 3 — Definition of Configured (gate before writing)

Do not write config until every item holds:

- [ ] Project name and purpose are stated
- [ ] A stack is settled — detected from the repo, or (greenfield) chosen by the user in step 2a
- [ ] Language, package manager, and test runner are known
- [ ] All five commands (dev/build/lint/test/test:coverage) map to a real invocation
- [ ] Coverage scope and threshold targets are decided
- [ ] Isolation model is settled (key + source, or explicitly single-tenant)
- [ ] At least the project's absolute rules are captured (or explicitly "none beyond the defaults")
- [ ] `stack-profile.sh` pattern targets are known (delete call, migrations dir, sensitive fields)

Optional (gate only if the team wants the capability — otherwise leave placeholders, don't block):
- [ ] Forge settled (`github`/`gitlab` + integration branch) **if** agents will push/PR
- [ ] Brand tokens captured **if** `/report` decks will be generated; image-gen provider **if** the
      `illustrated` style is wanted

If any required item is unmet → return to step 2 and ask, naming what's still open.

### 4 — Write the operational config

Fill, and only, these files — keep each lean (agents read `context.md` every run):

1. **`.claude/context.md`** — Project, Tech stack, the five Key commands, **Version control & forge**
   (forge, integration branch, token env var), Absolute rules, Roles, Data isolation, Domain glossary
   (seed what's known), UI conventions, **Brand assets** (logo, palette, fonts, default deck style,
   image-gen provider — only if reports will be generated), File-structure conventions, Reference
   formats, Key constraints. This is the every-run operational truth. Leave optional blocks
   (forge/brand/image-gen) as placeholders if the project won't use them.
2. **`CLAUDE.md` `[CONFIGURE]` blocks only** — Project, Tech stack, Commands, Absolute rules. Mirror
   the facts from `context.md`; do **not** touch the workflow, skill tables, or hook documentation.
3. **`.claude/hooks/stack-profile.sh`** — retarget the patterns for the detected stack (ORM delete
   call, destructive DB command, gated paths, audit table, sensitive fields, migrations dir, doc/
   rebuild commands). This one file is how hooks follow a stack — never edit the hook scripts.
4. **`package.json` `scripts`** (or task-runner equivalent) — ensure `lint`, `test`, and
   `test:coverage` exist and invoke the real tools, so the DoD and CI command actually run.
5. **Starter coverage config** — for the detected runner, with the agreed thresholds and scope
   (e.g. `vitest.config.ts` `coverage.thresholds`, or `--cov-fail-under` for pytest). This is the
   technical equivalent of acceptance criteria: the `test:coverage` gate the DoD assumes must exist.

6. **Stack-choice ADR (greenfield only)** — if you recommended the stack in step 2a, record *why* as a
   short entry in the **Key technical decisions** section of `docs/ARCHITECTURE.md`: the choice, the
   PRD constraints that drove it, the alternative considered, and the trade-off accepted. A few lines —
   the durable answer to "why this stack?" This is the one exception to leaving `ARCHITECTURE.md` to
   `/docs`; write nothing else in that file.

Respect the two-tier rule: exact tokens/commands/classes → `context.md` and config files; rationale
and deep architecture → `docs/ARCHITECTURE.md`. Beyond the greenfield stack ADR above, leave a
pointer there rather than filling it — `/docs` keeps it current.

### 5 — Verify the command runs

Run the configured `lint` and `test` command **once** to confirm they execute (a clean failure like
"no tests found" is fine — you're verifying the wiring, not the suite). Report the result. Do not
attempt to fix application code.

### 6 — Handoff

```
✅ Setup complete — the template is configured for <stack>
🧱 Stack            : <language · framework · ORM · test runner>  <(recommended & chosen | detected)>
⚙️  Commands wired   : dev · build · lint · test · test:coverage
📊 Coverage gate    : <thresholds> scoped to <path>
🔒 Isolation        : <key + source, or single-tenant>
📜 Absolute rules   : <count> captured in context.md + CLAUDE.md
➡️  Next step        : /discovery (define the product) or /planner (plan a known task)
```

---

## What setup does NOT do

- Does not scaffold the app, install dependencies, or generate framework/ORM boilerplate — it
  configures the *pipeline*, not the application. On greenfield it *recommends* a stack and *records*
  the choice; laying down the skeleton is still the user's next move.
- Does not write roadmap tasks (`/planner`) or product briefs (`/discovery`).
- Does not edit the workflow, skill tables, agent envelopes, or hook scripts — only the
  `[CONFIGURE]` content and `stack-profile.sh` patterns.
- Does not leave a tool name in the agnostic layer — concrete tools live only in `context.md` and the
  config files; the agents and DoD stay stack-neutral.
```