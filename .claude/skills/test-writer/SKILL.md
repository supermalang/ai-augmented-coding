---
name: test-writer
description: Write unit tests and E2E tests for the active roadmap task. Supports two TDD modes — RED (before /coder, derives tests from acceptance criteria, confirms they fail) and GREEN (after /coder, runs same tests, confirms they pass). The mode is specified in the agent prompt.
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

1. Read the task block from `docs/ROADMAP.md` — extract acceptance criteria, unit test table, E2E scenarios
2. Do NOT read implementation files — derive tests from criteria alone
3. Write unit tests and E2E specs (see patterns below)
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

1. Read the task block in `docs/ROADMAP.md` — extract **Acceptance criteria**, **Unit tests**, and **E2E tests**
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
- Capture screenshots on key assertions:
  ```ts
  await expect(page).toHaveScreenshot('feature-nominal.png')
  ```
- Use the E2E test command from `.claude/context.md`

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
📸 Screenshots: Z captures generated
➡️  Next step : /ux-review (if UI) → /perf-review (if DB queries) → /qa-tester
```
