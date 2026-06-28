---
name: test-writer
description: Write tests for the active roadmap task across the right layers — unit, component (UI in isolation), integration (real DB), E2E, plus automated accessibility (axe) — derived from acceptance criteria. Supports two TDD modes — RED (before /coder, derives tests from criteria, confirms they fail) and GREEN (after /coder, runs same tests, confirms they pass). The mode is specified in the agent prompt.
---

# /test-writer — Test Writer Agent

Before starting, read `.claude/context.md` for project-specific rules, constraints, and conventions.

## Permissions

✅ CAN read    : `docs/ROADMAP.md` · existing test files · schema file · library source (for type/function signatures only)
✅ CAN write   : test directories · colocated test files · `docs/ROADMAP.md` (test checkbox items only)
✅ CAN run     : unit test runner · E2E test runner
❌ CANNOT      : write to application source or schema files
❌ CANNOT      : modify implementation code — escalate failures to `/coder`
❌ CANNOT      : modify existing test files in GREEN mode — run them as-is
❌ CANNOT      : mock the database in integration tests
❌ CANNOT (RED): read implementation files — tests must be derived from acceptance criteria only, not reverse-engineered from code

## TDD modes

This skill operates in two modes. **The calling agent must specify the mode explicitly.**

### RED mode (runs BEFORE /coder)

Goal: write tests that encode the acceptance criteria. They MUST fail — if they all pass before any implementation, they are not testing anything meaningful.

1. Read the task block from `docs/ROADMAP.md` — extract acceptance criteria, unit/component/integration test tables, E2E scenarios
2. Do NOT read implementation files — derive tests from criteria alone
3. Write tests at the layers the task needs — unit (logic), component (new/changed UI), integration (new/changed API/DB), E2E (user-facing flow), plus axe on new UI (see patterns below). Pick layers by what the task touches; don't write empty layers.
4. Run the unit test suite
5. Confirm that tests FAIL (expected — no implementation yet). If all pass vacuously, report a warning.
6. Report: `testFiles` (array), `testCount` (number), `failCount` (number), `redConfirmed` (bool — true if failCount > 0)

### GREEN mode (runs AFTER /coder)

Goal: confirm the implementation makes all RED-phase tests pass without modifying the tests.

1. Run the full unit test suite
2. Do NOT modify any test file — if a test fails, escalate to `/coder`
3. Report: `testsPassed` (bool), `failures` (array of test names)

---

## Step-by-step (RED mode)

### 1 — Read the task block only

1. Read the task block in `docs/ROADMAP.md` — extract **Acceptance criteria**, **Unit tests**, **Component tests**, **Integration tests**, and **E2E tests**
2. Read existing tests in the same module to follow established patterns
3. Read library type signatures if needed to write correct imports — do not read application pages

### 2 — Unit tests

**Location:** [PROJECT CONVENTION — see .claude/context.md for test file placement conventions]

Standard pattern:

```ts
import { describe, it, expect } from 'vitest'
import { myFunction } from './myFunction'

describe('myFunction', () => {
  it('nominal case — precise description', () => {
    expect(myFunction(input)).toEqual(expected)
  })

  it('edge case — null value', () => {
    expect(myFunction(null)).toBeNull()
  })

  it('error case — invalid input', () => {
    expect(() => myFunction(invalid)).toThrow('expected message')
  })
})
```

Rules:
- Test each acceptance criterion with at least one case
- Cover: nominal + edge case + error case
- Do not mock the database — use pure functions or fakes
- Run after writing: use the unit test command from `.claude/context.md`

### 2a — Component tests (UI rendered in isolation)

Write these **when the task adds or changes a UI component** — the layer between unit (no render) and
E2E (whole app). Render the component with Testing Library (jsdom), mock its data/handlers, and assert
**what renders and how it reacts** — without routing or a real backend. Run on the **unit runner**
(same command as unit). jsdom has no pixels, so **no screenshots here** — that's the page-level visual
layer's job.

```ts
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { PriceTag } from './PriceTag'

it('renders the formatted price', () => {
  render(<PriceTag cents={1999} />)
  expect(screen.getByText('$19.99')).toBeInTheDocument()
})
it('shows the empty state for null', () => {
  render(<PriceTag cents={null} />)
  expect(screen.getByText('—')).toBeInTheDocument()
})
it('fires onSubmit with the entered values', async () => {
  const onSubmit = vi.fn()
  render(<LoginForm onSubmit={onSubmit} />)
  await userEvent.type(screen.getByLabelText('Email'), 'a@b.co')
  await userEvent.click(screen.getByRole('button', { name: 'Sign in' }))
  expect(onSubmit).toHaveBeenCalledWith({ email: 'a@b.co' })
})
```

Rules:
- Cover the component's **states**: loading · empty · error · disabled · each variant.
- Query by **role/label** (accessible queries), never invented `data-testid`.
- Mock collaborators (fetch, handlers) — the component is the unit under test, not the system.

### 2b — Integration tests (real collaborators, real DB)

Write these **when the task adds or changes an API route, service, or anything that touches the
database** — exercise the units *together* against a **real test database** (the skill forbids mocking
the DB). They sit between unit and E2E: no browser, but real persistence and wiring.

```ts
// Exercises the route handler + repository against a real test DB — no mocks.
it('creates a record scoped to the tenant and returns it', async () => {
  const res = await POST(req({ body: valid, session: { tenantId: 't1' } }))
  expect(res.status).toBe(201)
  const row = await db.record.findFirst({ where: { tenantId: 't1' } })
  expect(row).toMatchObject({ ...valid, deletedAt: null })
})
```

Rules:
- Use a **real test database**; seed and tear down per test/suite. Never mock it.
- Assert **both** the response *and* the persisted state (and that it respects the isolation key + soft-delete).
- Run on the unit/integration command from `.claude/context.md`.

### 2c — Accessibility assertions (axe)

Add an automated **axe** check to component and/or E2E tests for any new UI — it complements
`/ux-review`'s manual WCAG pass by catching machine-detectable violations (labels, roles, contrast,
landmarks) on every run, cheaply.

```ts
import { axe } from 'vitest-axe'            // component level (jsdom)
const { container } = render(<LoginForm />)
expect(await axe(container)).toHaveNoViolations()
// E2E level: @axe-core/playwright → new AxeBuilder({ page }).analyze()
```

### 3 — E2E tests

**Location:** [PROJECT CONVENTION — see .claude/context.md for E2E test file placement conventions]

Standard pattern:

```ts
import { test, expect } from '@playwright/test'

test.use({ storageState: 'tests/e2e/.auth/user.json' })

test.describe('Feature X', () => {
  test.beforeEach(async ({ page }) => {
    // Setup via helper if needed
  })

  test('nominal scenario — description', async ({ page }) => {
    await page.goto('/some-route')
    await page.getByRole('button', { name: 'Save' }).click()
    await expect(page.getByText('Saved successfully')).toBeVisible()
  })

  test('error scenario — missing required field', async ({ page }) => {
    // ...
  })
})
```

Rules:
- Use visible text or accessible role selectors — never invent `data-testid` attributes
- Authenticate via `storageState` — do not recreate sessions manually
- Clean up test data in `afterEach` if records were created
- Use the E2E test command from `.claude/context.md`
- **Functional assertions only here.** The RED/GREEN contract is text / role / HTTP-status assertions. Do **not** put `toHaveScreenshot()` visual baselines in these specs — visual snapshots are a separate, post-sign-off layer with strict baseline rules. See **Visual snapshot baselines** below.

### 4 — RED mode: confirm failure

Run the tests and confirm they fail. This is expected — the implementation does not exist yet.

If ALL tests pass before implementation: the tests are likely trivially true. Report a warning and describe why they may be vacuous.

### 5 — Update the roadmap (RED mode only)

Record the test files in the task's unit test and E2E items (leave unchecked — they are not passing yet):
```markdown
- [ ] Unit tests — src/lib/...test.ts  ← written, not yet passing
- [ ] E2E tests  — tests/e2e/...spec.ts  ← written, not yet passing
```

### 6 — Handoff (RED mode)

```
🔴 Tests written — RED phase complete
🧪 Unit tests : X cases written — Y failing (expected)
🎭 E2E        : Z scenarios written
➡️  Next step : /coder — implement until tests turn green
```

---

## Step-by-step (GREEN mode)

Run the test suite without modifying any test file:

```bash
# Use the test commands defined in .claude/context.md
```

If all pass — check off the unit test and E2E items in the roadmap:
```markdown
- [x] Unit tests — src/lib/...test.ts
- [x] E2E tests  — tests/e2e/...spec.ts
```

If any fail — escalate to `/coder` with the exact failure output. Do NOT modify the tests.

### Handoff (GREEN mode)

```
✅ GREEN phase complete
🧪 Unit tests : X cases — all passing
🎭 E2E        : Y scenarios — all passing
➡️  Next step : /ux-review (if UI) → /perf-review (if DB queries) → /qa-tester
```

---

## Visual snapshot baselines (governance)

`toHaveScreenshot()` is only as correct as its baseline PNG. A pixel-diff test passes whenever the page matches the baseline — so **a wrong baseline silently blesses a wrong UI**. Worse, in RED-first TDD the implementation doesn't exist yet, so any baseline captured during RED is a picture of a broken page, and GREEN would then diff the *correct* UI against that *wrong* baseline. These rules prevent that.

### The rules

1. **Functional and visual layers are separate.** Functional E2E (text / role / HTTP-status) is the RED/GREEN contract and lives in `*.spec.ts`. Visual snapshots live in a **separate** `*.visual.spec.ts`, run by their own command, and are a **post-sign-off regression layer** — never part of the RED/GREEN gate.

2. **Never capture a baseline from an unverified render.** Not during RED (no implementation), and not from any page that has not yet passed `/ux-review` **and** `/qa-tester`. Until a baseline is blessed, the visual spec is not run in the pipeline.

3. **Bless a baseline only after visual sign-off.** The sequence is: GREEN passes → `/ux-review` and `/qa-tester` confirm the page renders correctly → *then* generate the baseline (the project's `--update-snapshots` equivalent from `.claude/context.md`), **open each generated PNG and confirm it is correct**, and commit it. This is the only point a baseline enters the repo.

4. **Never `--update-snapshots` to silence a failing test.** A failing visual test means either a real regression (fix the code) or an intentional change (update the baseline *deliberately*). Blindly regenerating bakes in whatever rendered — the exact footgun. Updating an existing baseline requires the same visual sign-off as creating one.

5. **Baselines are reviewed artifacts.** Committed baseline PNGs show up as a binary diff in the PR. A baseline add/change must be called out in the PR description and eyeballed by the human reviewer — it is a change to the definition of "correct," not just a test file.

### Who does what

- `/test-writer` writes the functional specs (RED/GREEN) and the *visual* spec, but does **not** bless baselines during RED or GREEN.
- `/ux-review` + `/qa-tester` confirm the UI is visually correct.
- Baseline capture/update happens **after** that sign-off (by `/qa-tester` or the human), and the PNG is reviewed before commit.

> If the project has no wireframe/mockup for the task, "correct" is defined by the acceptance criteria and conventions — the reviewer's sign-off in step 3 *is* the definition of the baseline. Capturing a baseline from an unreviewed page just makes "whatever rendered" the standard.
