# ROADMAP

*Dernière mise à jour : 2026-07-03*

---

## Definition of Ready (DoR)

A task must satisfy **all** of the following before any code is written. The pipeline hard-stops if any item is missing.

- [ ] All template fields filled and non-empty
- [ ] Acceptance criteria: at least 3, concrete and verifiable
- [ ] Story is **Independent and Small** — deliverable in a single sprint with no hidden dependency on unplanned work; if not, split it (INVEST I + S)
- [ ] Schema impact declared (`Migration` or `None`)
- [ ] Dependencies identified (or explicitly `None`)
- [ ] Wireframe or mockup referenced (or `N/A` with justification for non-UI tasks)
- [ ] Risk level declared (`Low` / `Medium` / `High`)

> **Hard stop:** the `guard-roadmap-gate.sh` hook blocks all edits to `src/`, `tests/`, and the schema file if `.current-task` is not set or the task ID is not found in this file.

---

## Definition of Done (DoD)

A task is done only when **all** of the following are true:

- [ ] All acceptance criteria verifiably met
- [ ] Tests written and passing at the layers the task needs (`test:coverage` above thresholds):
  - [ ] Unit — for new/changed business logic
  - [ ] Component — for new/changed UI components (states, props, interaction)
  - [ ] Integration — for new/changed API routes / DB access (real test DB)
  - [ ] E2E — for new/changed user-facing flows
  - [ ] Accessibility (axe) — no violations on new/changed UI
- [ ] No lint errors (`npm run lint`)
- [ ] Code reviewed (security, performance, UX if applicable)
- [ ] Roadmap task marked `[x]` with completion date
- [ ] PR/MR opened and linked

---

## Sprint rituals (cadence-level checks)

The DoR/DoD above are **per-task** gates. Some work is **per-sprint**, not per-task — it can't be a
task checkbox, so it lives here, verified by the sprint rituals that bracket a sprint.

**Sprint entry — checked by `/sprint-start`:**
- [ ] Every planned task satisfies the **task DoR**
- [ ] The **story map** is current — the user journey is mapped and every journey gap is planned or consciously deferred (`/story-map`). **Hard gate** (blocks the sprint) on the first sprint or any sprint adding new user-facing journeys; a reminder otherwise

**Sprint exit — checked by `/report` + `/retro`:**
- [ ] Every task taken into the sprint is DoD-done `[x]` or explicitly carried over
- [ ] **Usability** checked on the user-facing features shipped this sprint — heuristic pass at minimum, real-user sessions when scheduled (`/usability-test`); findings filed as `/planner` tasks
- [ ] Progress **report** generated for the review (`/report`)
- [ ] **Retrospective** held and action items captured (`/retro`)

> Why here and not the DoD: story mapping and usability testing are about the *product/journey across
> many tasks*, are periodic, and (for real-user testing) need humans — so they're sprint-cadence checks,
> not per-task gates. Their *outputs* become tasks, which then pass the normal DoD.

---

## Task Template

Copy this block when creating a new task via `/planner`.

```markdown
### [ID] — [Short task title]

**Sprint:** Sprint N
**Write date:** YYYY-MM-DD
**Planned date:** YYYY-MM-DD
**Completion date:** —
**Type:** Feature | Fix  *(Fix = bug on already-shipped behaviour → orchestrator routes the build to `/debugger`)*
**Risk:** Low | Medium | High
**Priority:** P0 | P1 | P2  *(P0 = must ship this sprint / blocking · P1 = important, not blocking · P2 = nice to have)*
**Dependencies:** <task IDs this blocks on, comma-separated> | None  *(batch `/ship-task open` skips a task until every dependency is delivered `[x]`)*

**Description**
One paragraph — what this task does, not how.

**User value**
As a [persona], I want [action] so that [benefit].

**Acceptance criteria**
- [ ] Criterion 1 — concrete and verifiable
- [ ] Criterion 2 — nominal case
- [ ] Criterion 3 — edge or error case

**Schema impact:** None — [reason] | Migration — [what changes]

**Components:** `src/app/...` · `src/lib/...`
**API:** `POST /api/...` · `GET /api/...`

**Change-set (locate):** N/A — greenfield | *for change-type tasks, coarse scout output reused by `/coder`:*
- Targets: `src/...` (areas to modify) · Call path: entry → change point · Ripples: shared types / signatures / tests likely affected

**Code tasks**
1. [Implementation sub-task]
2. [Implementation sub-task]

**Unit tests**
File: `src/lib/[module]/[file].test.ts`
| Function | Cases |
|---|---|
| `functionName` | nominal · edge · error |

**Component tests** *(if the task adds/changes UI — else `N/A`)*
File: `src/components/[Component].test.tsx`
| Component | States / interactions |
|---|---|
| `Component` | renders · empty · error · disabled · onAction fires · axe clean |

**Integration tests** *(if the task adds/changes an API route or DB access — else `N/A`)*
File: `tests/integration/[route].test.ts`
| Endpoint / flow | Cases (real test DB) |
|---|---|
| `POST /api/...` | persists + scoped to isolation key · validation error · soft-delete respected |

**E2E tests**
File: `tests/e2e/[feature].spec.ts`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | [state] | [action] | [expected result] |

**UAT:** [What the user sees or does in the browser to verify this works]
**QA:** — (to be signed off)
**Delivery:** — *(filled by `/pr-reviewer`: Commit · PR · Started · Delivered · Cycle time — timestamps ISO 8601 UTC)*
```

---

## Global status

| Domain | Planned | In progress | Done |
|--------|---------|-------------|------|
| Visual baseline review (tooling) | 5 | 0 | 0 |
| Pipeline tooling | 1 | 0 | 0 |

---

## 🏃 Sprint 1 — Visual Baseline Review (opt-in)

An opt-in, tiered visual-regression capability for the pipeline, **disabled by default** to keep the
template stack-agnostic. Tier 1 = Playwright full-route screenshots; Tier 2 adds Storybook
component isolation; Tier 3 adds a clickable local review app. Human visual approval is the final,
**non-blocking** async gate before PR merge.

| Task | Status | Delivered |
|------|--------|-----------|
| VBR-1 Visual testing enablement + Tier 1 scaffolding | ⬜ | — |
| VBR-2 Agent guardrails + approval-state reader | ⬜ | — |
| VBR-3 Pipeline wiring (qa-tester · pr-reviewer · ship-task) | ⬜ | — |
| VBR-4 Tier 2 — Storybook component-isolation option | ⬜ | — |
| VBR-5 Tier 3 — custom local review app | ⬜ | — |

<!-- Add task blocks below using the template above -->

### VBR-1 — Visual testing enablement + Tier 1 scaffolding

**Sprint:** Sprint 1
**Write date:** 2026-07-03
**Planned date:** 2026-07-17
**Completion date:** —
**Type:** Feature
**Risk:** Medium *(scaffolds a pinned container + config; determinism-sensitive, but no app-runtime install)*
**Priority:** P0
**Dependencies:** None

**Description**
Add a `/visual-setup` scaffolding skill + matching agent that lets an adopting project **opt in** to
visual baseline review. It runs a short enable interview, records the choice in `.claude/context.md`,
and — for the default Tier 1 — scaffolds a **pinned Playwright container**, a visual-testing config,
and an example full-route screenshot spec. It **verifies** runtime prerequisites (Node, Playwright
browsers/system libs) and prints remediation guidance when missing; it must **never** imperatively
install runtimes on the host. Off by default: absent the flag, nothing in the pipeline changes.

**User value**
As a developer adopting this template, I want to enable deterministic visual baseline testing with one
guided command, so that I get reproducible screenshot baselines without hand-wiring containers or
risking a non-deterministic local setup.

**Acceptance criteria**
- [ ] Running `/visual-setup` on a project with no visual config runs an interview and writes a `Visual testing:` block to `.claude/context.md` recording `enabled: true`, the chosen `tier` (default `1`), the pinned image tag, and the baseline/report locations.
- [ ] Tier 1 scaffold produces: a pinned Playwright container definition (image tag pinned, e.g. `mcr.microsoft.com/playwright:vX.Y.Z`), a visual Playwright config (fixed viewport, animations disabled, OS-suffixed baselines), and at least one runnable example `*.visual.spec.ts` using `toHaveScreenshot` against a served route.
- [ ] Prerequisite verification: when Node or the Playwright browser deps are absent, the skill reports each missing item with a concrete remediation line and **exits without attempting an install**; when present, it reports ready.
- [ ] Determinism is documented and enforced by config: baselines are captured only in the pinned image, baseline filenames carry the platform suffix, and the scaffold notes "CI must use the identical image".
- [ ] The scaffolded visual config sets `workers` **explicitly** (never auto-detected inside the container, which misreports host cores) — sized to the container's allocated CPU via an env var (e.g. `PW_WORKERS`), with `fullyParallel: true`; the container definition documents its vCPU/RAM budget and the per-worker sizing rule (~1 vCPU + ~1.5 GB RAM per worker), plus the `--shard=i/n` option for splitting a large suite across CI runners.
- [ ] Idempotent: re-running `/visual-setup` on an already-enabled project detects the existing flag and offers to change tier rather than duplicating config.
- [ ] With the flag absent (default), no other pipeline agent changes behaviour (Tier 0 = fully disabled).

**Schema impact:** None — tooling only, no data model.

**Components:** `.claude/skills/visual-setup/SKILL.md` · `.claude/agents/visual-setup.md` · `.claude/context.md` (new `Visual testing` block) · scaffold templates under `.claude/skills/visual-setup/templates/` (container def, `playwright.visual.config.*`, example spec) · `CLAUDE.md` (skills/agents tables)

**API:** N/A — no HTTP routes.

**Change-set (locate):** N/A — greenfield (new skill + agent + templates; touches existing `context.md`/`CLAUDE.md` tables only additively)

**Code tasks**
1. Author `.claude/agents/visual-setup.md` (thin frontmatter: least-privilege tools — Read/Write/Edit/Bash/Glob/Grep; model Sonnet — pointing at the skill).
2. Write `SKILL.md`: enable interview (tier selection, served-URL question), prerequisite verification (detect-only, remediation, no install), context.md flag writer (idempotent), Tier 1 scaffolder.
3. Add scaffold templates: pinned container definition (documented vCPU/RAM budget), `playwright.visual.config` (fixed viewport, `animations: 'disabled'`, explicit `PW_WORKERS`-driven `workers`, `fullyParallel: true`, snapshot path/suffix, small `maxDiffPixelRatio`), example full-route `*.visual.spec.ts`.
4. Register the skill + agent in `CLAUDE.md` tables and document Tier 0/1 and the determinism rule.

**Unit tests**
File: `.claude/skills/visual-setup/tests/verify-prereqs.test.sh`
| Function | Cases |
|---|---|
| prereq check | all present → ready · Node missing → remediation + non-install exit · browsers missing → remediation |
| flag writer | writes block when absent · idempotent no-dup on re-run |

**Component tests** *(N/A — no UI component; the scaffolded config is verified by VBR-1 unit/E2E, review-app UI is VBR-5)*

**Integration tests** *(N/A — no API route or DB access)*

**E2E tests**
File: manual scenario recorded in `.claude/skills/visual-setup/tests/README.md`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | Fresh project, no flag | Run `/visual-setup`, choose Tier 1 | context.md flag written; container + config + example spec present; example spec runs and creates a baseline in the pinned image |
| 2 | Node/browsers absent | Run `/visual-setup` | Reports missing prereqs with remediation; no install attempted; exits cleanly |

**UAT:** Developer runs `/visual-setup`, answers the interview, and sees a working example visual spec plus a `Visual testing` block in `.claude/context.md`; running the example produces a baseline PNG under the configured location.
**QA:** — (to be signed off)
**Delivery:** —

---

### VBR-2 — Agent guardrails + approval-state reader

**Sprint:** Sprint 1
**Write date:** 2026-07-03
**Planned date:** 2026-07-17
**Completion date:** —
**Type:** Feature
**Risk:** Medium *(hard-block hook — must be pure-bash + fail-closed like the existing write-gates)*
**Priority:** P0
**Dependencies:** VBR-1

**Description**
Two agent-facing pieces that make human approval a durable, machine-readable artifact. (1) A guard
hook that **blocks any agent from running `playwright … --update-snapshots`** (or equivalent
re-baseline), so only a human at the terminal or the review app may bless baselines. (2) A
`/visual-review` skill that **reads** the approval record (`visual-approvals.json`) plus the PNG
git-diff and reports each baseline as `approved` / `rejected` / `pending` — the read-only state other
agents consume. Agents never re-baseline; they only observe the record.

**User value**
As a pipeline maintainer, I want agents to be structurally unable to auto-bless screenshots and to have
one canonical way to read approval state, so that a human always owns the final visual sign-off and the
rest of the pipeline can act on it deterministically.

**Acceptance criteria**
- [ ] `guard-visual-update.sh` blocks a Bash command matching `--update-snapshots` (and the Playwright update invocation) with a non-zero exit and an explanatory message, and is registered as a PreToolUse hook in `.claude/settings.json`.
- [ ] The guard is **pure-bash and fails closed** — on any parse failure it blocks (consistent with `guard-roadmap-gate`/`guard-bash-write`), and its match pattern lives in `.claude/hooks/stack-profile.sh`, not hard-coded in the hook.
- [ ] The guard does **not** block a human's interactive terminal run outside an agent context (documented mechanism, e.g. only gates tool-issued Bash), and does not block the review app's re-baseline path.
- [ ] `/visual-review` reads `visual-approvals.json` + `git diff --name-only` on baseline PNGs and emits a structured summary: counts + per-baseline status (`approved`/`rejected`/`pending`) with the associated task ID.
- [ ] `visual-approvals.json` schema is defined and documented (keyed by baseline/test id → `{decision, task, capturedImage}`); `/visual-review` treats a changed-but-unrecorded PNG as `pending` and a `rejected` entry as blocking.
- [ ] `/visual-review` is read-only (no Edit/Write of baselines) and exits with a distinct status when anything is `pending` or `rejected`.

**Schema impact:** None — `visual-approvals.json` is a repo artifact, not a DB migration.

**Components:** `.claude/hooks/guard-visual-update.sh` · `.claude/hooks/stack-profile.sh` (new pattern) · `.claude/settings.json` (PreToolUse registration) · `.claude/skills/visual-review/SKILL.md` · `.claude/agents/visual-review.md` · `CLAUDE.md` (hooks + skills tables)

**API:** N/A.

**Change-set (locate):** N/A — greenfield hook + skill; edits `settings.json`, `stack-profile.sh`, `CLAUDE.md` additively.

**Code tasks**
1. Add the re-baseline match pattern to `stack-profile.sh`.
2. Write `guard-visual-update.sh` in pure bash, fail-closed, block on match; register in `settings.json` PreToolUse (Bash).
3. Define + document the `visual-approvals.json` schema.
4. Author `/visual-review` skill + read-only agent (Read/Bash/Glob/Grep) that reports approved/rejected/pending.
5. Update `CLAUDE.md` hook + skill tables.

**Unit tests**
File: `.claude/hooks/tests/guard-visual-update.test.sh`
| Function | Cases |
|---|---|
| guard | `--update-snapshots` present → block (exit≠0) · unrelated `playwright test` → allow · malformed input → block (fail-closed) |
| review reader | all recorded+approved → clean · one changed PNG unrecorded → pending · rejected entry → blocking status |

**Component tests** *(N/A — no UI)*

**Integration tests** *(N/A — no API/DB; the hook is exercised by the bash unit tests above)*

**E2E tests**
File: manual scenario in `.claude/hooks/tests/README.md`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | Agent context | Agent attempts `playwright test --update-snapshots` | Blocked with guidance; no PNGs change |
| 2 | One PNG changed, no approval record | Run `/visual-review` | Reports 1 pending; non-zero/pending status |

**UAT:** Maintainer confirms an agent cannot re-baseline (guard blocks it) and that `/visual-review` prints an accurate approved/rejected/pending summary tied to task IDs.
**QA:** — (to be signed off)
**Delivery:** —

---

### VBR-3 — Pipeline wiring (qa-tester · pr-reviewer · ship-task)

**Sprint:** Sprint 1
**Write date:** 2026-07-03
**Planned date:** 2026-07-24
**Completion date:** —
**Type:** Feature
**Risk:** Medium *(changes gate semantics in existing orchestration skills)*
**Priority:** P0
**Dependencies:** VBR-1, VBR-2

**Description**
Wire visual approval into the existing pipeline with the agreed semantics. `/qa-tester` runs the visual
suite: functional failures block, but a **visual diff is not a failure — it is flagged "pending human
approval"** via the approval record. Human approval is the **final gate before merge**: `/pr-reviewer`
proceeds only when `/visual-review` reports nothing `pending` and nothing `rejected`. `/ship-task` is
**non-blocking** — when a task is pending visual approval it **parks** the task and moves on to other
open tasks; on a later run, once the approval record exists, the parked task resumes to merge.

**User value**
As a developer using `/ship-task`, I want visual changes to route to me for approval without stalling the
pipeline, so that automated work keeps flowing on other tasks while I remain the final sign-off on how
the UI looks before anything merges.

**Acceptance criteria**
- [ ] `/qa-tester`, when visual testing is enabled, runs the visual suite; a functional/assertion failure blocks as today, while a pure visual diff is recorded as `pending` (never reported as a hard failure) and surfaced to the human.
- [ ] `/pr-reviewer` calls `/visual-review` as a DoD gate and refuses to open/merge the PR while any baseline is `pending` or `rejected`; it proceeds only on all-approved (or visual testing disabled).
- [ ] `/pr-reviewer` records the count of updated/approved baselines in the PR body (the "why these changed" note), sourced from the task and the approval record.
- [ ] `/ship-task` treats "pending visual approval" as a **park** state: it does not idle/block on it, marks the task parked, and continues to the next eligible open task; a parked task is resumed automatically once the approval record shows all-approved.
- [ ] When visual testing is disabled (Tier 0), all three skills behave exactly as before (no new gate).
- [ ] The park/resume state is persisted where `/ship-task` can read it across runs (documented location), so approval done between runs is picked up.

**Schema impact:** None.

**Components:** `.claude/skills/qa-tester/SKILL.md` · `.claude/skills/pr-reviewer/SKILL.md` · `.claude/skills/ship-task/SKILL.md` · `CLAUDE.md` (pipeline step table) · possibly `.current-task`/park-state artifact doc

**API:** N/A.

**Change-set (locate):** *change-type — refine with `/locate` before coding.*
- Targets: the three skill files' gate/step sections · Call path: `ship-task` → `qa-tester` (flag pending) → park → later run → `pr-reviewer` → `visual-review` gate → merge · Ripples: any doc describing the pipeline order (CLAUDE.md step table), the `.current-task` lifecycle

**Code tasks**
1. `/qa-tester`: add "run visual suite when enabled; record diffs as pending, don't fail on them" step (gated on the context.md flag).
2. `/pr-reviewer`: add `/visual-review` DoD gate + PR-body approval summary.
3. `/ship-task`: add park-on-pending + resume-when-approved logic and the persisted park state.
4. Update `CLAUDE.md` pipeline step table + note the async human gate.

**Unit tests**
File: `.claude/skills/*/tests/*.sh` (gate-logic smoke checks where scriptable)
| Function | Cases |
|---|---|
| pr gate | all approved → proceed · any pending → refuse · any rejected → refuse · disabled → proceed |
| ship park | pending → park + advance · approval appears → resume |

**Component tests** *(N/A — orchestration skills, no UI)*

**Integration tests** *(N/A — no API/DB; behaviour verified by the manual E2E below)*

**E2E tests**
File: manual scenario in `docs/` pipeline notes
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | Enabled, UI task with a visual change | `/ship-task <id>` | Task parked as pending; ship-task advances to next task; no merge |
| 2 | Approval record all-approved | Re-run `/ship-task` / `/pr-reviewer` | Gate passes; PR opened/merged with approval summary in body |
| 3 | Visual testing disabled | Run pipeline | No new gate; identical to pre-feature behaviour |

**UAT:** Developer runs `/ship-task` on a UI change, sees the task parked for their approval while other tasks progress, approves, and on the next run the PR is opened with the approved-baselines note.
**QA:** — (to be signed off)
**Delivery:** —

---

### VBR-4 — Tier 2: Storybook component-isolation option

**Sprint:** Sprint 1
**Write date:** 2026-07-03
**Planned date:** 2026-07-31
**Completion date:** —
**Type:** Feature
**Risk:** Medium *(framework-coupled scaffolding — must degrade gracefully across stacks)*
**Priority:** P1
**Dependencies:** VBR-1

**Description**
Extend `/visual-setup` with an opt-in Tier 2 that adds **Storybook** for component-isolation visual
tests: static `storybook build` output served and screenshotted by Playwright in the same pinned image,
so component-level baselines join the route-level ones. Because Storybook setup is framework-specific,
Tier 2 detects the UI framework and scaffolds the matching Storybook config, falling back to clear
guidance when the framework is unsupported — Tier 1 remains fully functional without it.

**User value**
As a developer with a component-heavy UI, I want per-component, per-state visual baselines in isolation,
so that a visual diff points at the exact component and state that changed rather than a whole page.

**Acceptance criteria**
- [ ] Choosing Tier 2 in `/visual-setup` scaffolds Storybook config appropriate to the detected framework plus an example `*.stories.*` and a Playwright visual spec that screenshots a **static** `storybook build` (no long-lived dev server needed in CI).
- [ ] Story screenshots are captured in the **same pinned image** as Tier 1 (identical determinism + OS-suffixed baselines); local == CI.
- [ ] When the UI framework is not detected/supported, Tier 2 does not half-scaffold: it reports what's unsupported and leaves the project on a working Tier 1.
- [ ] The context.md flag records `tier: 2` and the Storybook build/output location; `/visual-review` and the pipeline gates treat story baselines identically to route baselines.
- [ ] Example story renders in interactive Storybook (`storybook dev`) for the human, and the same story produces a baseline via the Playwright spec.

**Schema impact:** None.

**Components:** `.claude/skills/visual-setup/SKILL.md` (Tier 2 branch) · new templates: Storybook config + example `*.stories.*` + story visual spec · `.claude/context.md` flag (`tier: 2` fields) · `CLAUDE.md` (tier docs)

**API:** N/A.

**Change-set (locate):** N/A — greenfield additive branch on the VBR-1 skill; new templates only.

**Code tasks**
1. Add framework detection + Tier 2 branch to `/visual-setup`.
2. Add Storybook config templates + example story + static-build Playwright visual spec.
3. Extend the context.md flag writer with Tier 2 fields.
4. Document Tier 2, the static-build flow, and the graceful-fallback behaviour in `CLAUDE.md`.

**Unit tests**
File: `.claude/skills/visual-setup/tests/tier2.test.sh`
| Function | Cases |
|---|---|
| framework detect | supported → scaffolds · unsupported → reports + stays Tier 1 |
| flag writer | tier:2 fields written · build/output path recorded |

**Component tests** *(N/A here — the scaffolded example story is the artifact; its rendering is verified by the E2E baseline scenario)*

**Integration tests** *(N/A — no API/DB)*

**E2E tests**
File: manual scenario in `.claude/skills/visual-setup/tests/README.md`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | Tier 1 enabled, supported framework | `/visual-setup` → choose Tier 2 | Storybook config + example story + story visual spec scaffolded; `storybook build` + spec produces a component baseline in the pinned image |
| 2 | Unsupported framework | Choose Tier 2 | Reports unsupported; project remains working on Tier 1 |

**UAT:** Developer opens Storybook, interacts with the example component in isolation, then runs the visual spec and gets a committed component baseline captured in the pinned image.
**QA:** — (to be signed off)
**Delivery:** —

---

### VBR-5 — Tier 3: custom local review app

**Sprint:** Sprint 1
**Write date:** 2026-07-03
**Planned date:** 2026-08-07
**Completion date:** —
**Type:** Feature
**Risk:** Medium *(introduces a served local app + the re-baseline write path; must preserve env parity)*
**Priority:** P1
**Dependencies:** VBR-1, VBR-2

**Description**
Add an opt-in Tier 3 thin local review app — a small served Node app giving the clickable
**baseline-vs-candidate side-by-side with Approve / Reject** UI (the pattern from the reference
screenshot). Crucially it serves **container-rendered** candidate PNGs so the human approves the exact
pixels CI will produce (approval-environment parity), and on Approve it writes the `visual-approvals.json`
record and re-baselines the approved PNG — the one sanctioned write path outside the terminal, which the
VBR-2 guard explicitly permits.

**User value**
As a developer, I want a local web page where I can see each changed screenshot side-by-side and click
Approve or Reject, so that blessing baselines is a quick visual review instead of hand-running
`--update-snapshots`, while still producing the same durable git record agents read.

**Acceptance criteria**
- [ ] `/visual-setup` Tier 3 scaffolds a runnable local review app (thin Node server) launchable with a documented command; the context.md flag records `tier: 3` and the app's location.
- [ ] The app lists every baseline with a visual diff and shows **previous baseline vs new candidate side-by-side** (plus the "why changed" note from the associated task), matching the reference layout.
- [ ] Candidate images shown are **container-rendered** (captured in the pinned image), so an approval cannot introduce a local-vs-CI pixel mismatch; the app documents/enforces that it reads the pinned-image output, not a local render.
- [ ] Clicking **Approve** writes/updates `visual-approvals.json` (decision + task id) and re-baselines that PNG; **Reject** records a `rejected` decision without re-baselining. Both are picked up by `/visual-review`.
- [ ] The re-baseline write path is allowed past the VBR-2 guard (only this app + a human terminal may re-baseline), and agents still cannot.
- [ ] The app is Tier-3-only: it is absent/never required at Tiers 0–2, and the pipeline works without it (terminal approval remains valid).

**Schema impact:** None.

**Components:** new review-app source under a scaffolded location (e.g. `.claude/skills/visual-setup/templates/review-app/`) · `.claude/skills/visual-setup/SKILL.md` (Tier 3 branch) · `.claude/context.md` flag (`tier: 3`) · integration with `visual-approvals.json` + VBR-2 guard allowance · `CLAUDE.md` (tier docs)

**API:** Local app only — `GET /` (review UI) · `GET /api/diffs` (list baselines + diffs) · `POST /api/approve` · `POST /api/reject`. *(Local dev server, not a project HTTP surface.)*

**Change-set (locate):** N/A — greenfield app template + additive Tier 3 branch.

**Code tasks**
1. Build the thin review-app template (server + minimal UI: side-by-side, Approve/Reject, why-changed note).
2. Wire endpoints to read container-rendered diffs and to write `visual-approvals.json` + re-baseline on approve.
3. Ensure the app's re-baseline path is permitted by the VBR-2 guard while agent paths stay blocked.
4. Add the Tier 3 branch + flag fields to `/visual-setup`; document launch + parity requirement in `CLAUDE.md`.

**Unit tests**
File: review-app `*.test.*` (server logic)
| Function | Cases |
|---|---|
| list diffs | returns changed baselines with candidate+baseline paths |
| approve | writes approval record + re-baselines · reject → records rejected, no re-baseline |
| parity guard | refuses/ō warns if candidate not from pinned-image output |

**Component tests**
File: review-app UI component test
| Component | States / interactions |
|---|---|
| ReviewCard | renders side-by-side · Approve fires + posts · Reject fires + posts · empty (no diffs) · axe clean |

**Integration tests**
File: review-app integration test
| Endpoint / flow | Cases |
|---|---|
| `POST /api/approve` | updates `visual-approvals.json` + PNG re-baselined on disk; `/visual-review` then reports approved |
| `POST /api/reject` | records rejected; `/visual-review` reports blocking |

**E2E tests**
File: manual scenario in `.claude/skills/visual-setup/templates/review-app/README.md`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | Tier 3, one changed baseline | Launch app, click Approve | `visual-approvals.json` records approved; PNG re-baselined; `/visual-review` → approved; guard did not block the app |
| 2 | One changed baseline | Click Reject | Recorded rejected; no re-baseline; `/pr-reviewer` gate refuses to merge |

**UAT:** Developer launches the review app, sees each changed screenshot side-by-side with the why-changed note, clicks Approve/Reject, and those decisions flow through `/visual-review` into the `/pr-reviewer` merge gate — matching the reference screenshot experience, with parity to CI pixels.
**QA:** — (to be signed off)
**Delivery:** —

---

## 🏃 Sprint 2 — Pipeline scaling

| Task | Status | Delivered |
|------|--------|-----------|
| RB-1 Roadmap scaling: archive done tasks + selective reads | ⬜ | — |

### RB-1 — Roadmap scaling: archive done tasks + selective reads

**Sprint:** Sprint 2
**Write date:** 2026-07-03
**Planned date:** 2026-07-17
**Completion date:** —
**Type:** Feature
**Risk:** Medium *(archiving rewrites the roadmap structure many agents depend on — must be lossless + idempotent)*
**Priority:** P1
**Dependencies:** None

**Description**
Keep `docs/ROADMAP.md` proportional to *active work* rather than *cumulative history*. Today the file
is read (often in full) by nearly every agent — `/planner`, `/start-task`, `/ship-task` (validate +
batch), `/pr-reviewer`, `/roadmap-status` — so on a long-lived project it grows past thousands of
lines and taxes every run's tokens while making block extraction slow and error-prone. Two moves:
(1) an **archive** mode in `/roadmap-status` that sweeps completed `[x]` task blocks into
`docs/roadmap/archive/sprint-<N>.md` leaving a one-line ledger entry in the live file; (2) update the
**read-instructions** in the consuming agents so they read a slice (the one task block, or the
status/ledger tables) instead of the whole file. Git history preserves full blocks regardless.

**User value**
As a pipeline maintainer on a long-running project, I want the live roadmap to stay small and agents to
read only the slice they need, so that every agent run stays fast and cheap no matter how much work has
already shipped.

**Acceptance criteria**
- [ ] `/roadmap-status archive` moves every `[x]` task block out of `docs/ROADMAP.md` into `docs/roadmap/archive/sprint-<N>.md` (grouped by the task's sprint) and leaves a compact ledger row in the live file: `| <ID> | <title> | ✅ <date> | <PR> |`.
- [ ] **Lossless round-trip** — every archived block is written to the archive byte-for-byte (heading through last field); nothing is dropped or truncated; the archive file is valid markdown and readable on its own.
- [ ] **Idempotent** — re-running `archive` with no newly-done tasks makes no changes; running it twice never duplicates a block or a ledger row.
- [ ] After archiving, the live `docs/ROADMAP.md` contains only the static header (DoR/DoD/Template), active + planned task blocks, the sprint status tables, and the done-ledger — no full `[x]` blocks.
- [ ] The consuming agents' read-instructions are updated to read selectively: `/start-task` and `/ship-task` (validate) locate the single task block by ID (grep + offset/limit) rather than the whole file; `/ship-task` batch reads the status/ledger tables + only non-done blocks; `/pr-reviewer` reads the target block + status table; `/planner` reads the header + current sprint. The static DoR/DoD/Template header stays in `docs/ROADMAP.md`.
- [ ] **No-op safety** — on an empty roadmap or one with zero `[x]` tasks, `archive` reports "nothing to archive" and changes nothing; it never creates an empty archive file.
- [ ] The archive convention (location, ledger format, that git holds full history) is documented in `CLAUDE.md` and `.claude/context.md` (Generated files & artifacts).

**Schema impact:** None — documentation/tooling only, no data model.

**Components:** `.claude/skills/roadmap-status/SKILL.md` (new `archive` mode + `archive.mjs`) · `.claude/skills/start-task/SKILL.md` · `.claude/skills/ship-task/SKILL.md` · `.claude/skills/pr-reviewer/SKILL.md` · `.claude/skills/planner/SKILL.md` (read-instructions) · `docs/roadmap/archive/` (new) · `CLAUDE.md` · `.claude/context.md`

**API:** N/A — no HTTP routes.

**Change-set (locate):** *change-type — refine with `/locate` before coding.*
- Targets: the five skill files' roadmap-read steps · `roadmap-status/SKILL.md` gains the archive procedure · Call path: `/roadmap-status archive` → parse `[x]` blocks → append to archive → replace with ledger row → rewrite live file · Ripples: any doc describing the roadmap layout (CLAUDE.md two-tier table, context.md artifacts table); the ledger table shape the batch scan reads

**Code tasks**
1. Define the archive layout + ledger row format; create `docs/roadmap/archive/` with a short README.
2. Add the `archive` procedure to `/roadmap-status` (identify done blocks by Completion date, append losslessly, replace with ledger row, idempotent + no-op guards).
3. Update read-instructions in `/start-task`, `/ship-task`, `/pr-reviewer`, `/planner` to read selectively (single block by ID / tables / current sprint).
4. Document the archive convention in `CLAUDE.md` and `.claude/context.md`.

**Unit tests**
File: `.claude/skills/roadmap-status/tests/archive.test.mjs`
| Function | Cases |
|---|---|
| archive sweep | one delivered block → moved to archive + ledger row left · lossless (archived content equals original block) · mixed done/open → only done moved |
| idempotency | re-run with nothing new → zero changes · never duplicates a block/row |
| no-op | empty roadmap → "nothing to archive", no archive file created · zero delivered → no change |

**Component tests** *(N/A — no UI)*

**Integration tests** *(N/A — no API/DB; behaviour verified by the fixture tests above)*

**E2E tests**
File: manual scenario in `.claude/skills/roadmap-status/tests/README.md`
| # | Initial state | Action | Assertion |
|---|---|---|---|
| 1 | Roadmap with several delivered + open tasks | `/roadmap-status archive` | Live file keeps only active/planned + ledger; `docs/roadmap/archive/sprint-N.md` holds the full done blocks; re-run is a no-op |
| 2 | Long roadmap after archive | `/start-task <open-id>` | Locates the task block without reading the whole file |

**UAT:** Maintainer runs `/roadmap-status archive` on a bloated roadmap and sees the live file shrink to active work + a done-ledger, with the full history intact under `docs/roadmap/archive/`; a re-run reports nothing to archive.
**QA:** — (to be signed off)
**Delivery:** —
