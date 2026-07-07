# Testing

> **[OPTIONAL — Tier-2 knowledge doc].** The standing *testing philosophy and guidelines*: what to
> test, at which layer, how much, and why. It is deliberately **stack-agnostic** — it names tools as
> *recommendations*, not mandates. The concrete choices for this project (test runner, e2e tool,
> commands) live in `.claude/context.md` under **Tech stack** and **Key commands** (operational, read
> every run); this file holds the *reasoning* behind how they're used.
>
> **Read by:** `/test-writer` (what durable coverage to author and where), `/qa-tester` (what to
> verify and how thin to keep e2e), `/visual-setup` + `/visual-report` (the visual layer), `/coder`
> (what to test alongside a change). Kept current by `/docs`. All treat it as optional — if absent,
> they fall back to `.claude/context.md`.

---

## The frame — the Testing Trophy

Invest by **return on confidence per unit of maintenance cost**, not by test count. The Testing
Trophy (Kent C. Dodds) captures this better than the old pyramid for modern web apps: a wide static
base, the **most weight in integration**, less in unit and e2e, with a thin, high-value top.

```
        /  e2e  \        ← thin: only critical user journeys
       /---------\
      / integration\     ← HEAVIEST: features working together
     /--------------\
    /      unit      \    ← pure logic, edge cases
   /------------------\
  /   static analysis  \  ← widest, cheapest: types + lint
 /----------------------\
```

The reasoning: static analysis and integration tests catch the most real defects for the least
upkeep. E2e and visual tests are expensive to write and *maintain* (they break on unrelated UI
churn), so they earn their place only for flows where a break would actually hurt. **A thin e2e
layer is a sign of health, not a gap** — provided the layers beneath it are full.

---

## Defining critical journeys

"Critical" is a **business judgment, not a code-derived fact** — an agent cannot reliably infer it
from the source, and shouldn't pretend to. The human decides; the roadmap records the decision. The
signal flows through docs that already exist:

**`PRODUCT.md` (what the product is for) → `docs/story-map.md` (`/story-map` lays out user journeys)
→ `docs/ROADMAP.md` (tasks with acceptance criteria).**

A journey is **critical** when a break would cause real damage — revenue-blocking, data-corrupting,
or lock-you-out flows: authentication, the primary create/update path, anything touching money or a
system of record. Everything else is covered lower in the trophy (integration/unit), not with e2e.

### The two-part rule of thumb

1. **Can you write the acceptance criterion?** If you can't state, in testable terms, what "done"
   looks like, it isn't a defined journey yet — define it before covering it.
2. **Would breaking it hurt?** If a silent failure wouldn't cause real damage, it isn't critical —
   keep it out of the thin e2e/visual top and cover it (if at all) with cheaper integration tests.

Both true → critical journey → gets an e2e spec (and a visual baseline if the *look* matters). Only
one or neither → do not spend e2e/visual on it.

### What makes an acceptance criterion testable

Write each as an **observable outcome**, ideally Given / When / Then — a condition, an action, and a
result someone (or a test) can verify. Avoid adjectives that can't be asserted.

| Weak (not testable) | Strong (testable) |
|---|---|
| "Login should work well" | "Given valid credentials, when the user submits the login form, then they land on the dashboard and see their name in the header." |
| "The order page is fast" | "When the order list loads with 100 rows, the page is interactive within 2s." |
| "Errors are handled nicely" | "Given an invalid amount, when the user submits, then an inline error names the field and no record is created." |

If you can't yet phrase it this way, that's fine — the Planner will ask (see below). The point is
that a **vague criterion is a signal to clarify, not a thing to test around.**

### Mapping journeys to layers

- **Critical journey** → one e2e spec for the happy path + key failure; visual baseline only if the
  rendered appearance is itself part of "correct."
- **Supporting behaviour** → integration tests (the bulk of the trophy).
- **Pure logic / edge cases** → unit tests.

Keep the e2e/visual set small and named — a short, explicit list of journeys beats broad, shallow
coverage that breaks on every UI change.

---

## Layers — what each proves, and how heavily to invest

| Layer | Proves | Tool (recommendation) | Weight | Committed |
|---|---|---|---|---|
| **Static** | It compiles; no obvious defects | **[CONFIGURE]** — types + linter | widest | ✅ config |
| **Unit** | Pure logic is correct at the edges | **[CONFIGURE]** — unit runner | medium | ✅ |
| **Integration** | Units work *together* (module + its collaborators, real or close-to-real deps) | **[CONFIGURE]** — same runner | **heaviest** | ✅ |
| **E2E** | A real user journey works end-to-end in a browser | **[CONFIGURE]** — e2e/browser tool | **thin** | ✅ |
| **Visual** | The UI still *looks* right (pixel regression) | **[CONFIGURE]** — screenshot baselines | **thin** | ✅ baselines |
| **Accessibility** | No WCAG A/AA violations (an assertion *inside* e2e — not a separate suite) | **[CONFIGURE]** — a11y engine | rides e2e | ✅ |
| **Security** | No secrets, no obvious vulns, deps are clean | `/security-audit` · `/dep-audit` · guards | continuous | ✅ |
| **Performance** | Hot paths stay within budget | `/performance` (review + measure) | targeted | ✅ |

> **[CONFIGURE]** placeholders are filled in `.claude/context.md`, not here. Example fillers a
> project might choose: a typed language + linter for static; one runner for unit **and**
> integration (fewer moving parts); a single browser engine for e2e/visual (headless build for
> speed); an axe-style engine for a11y. Pick per stack — the *shape* above is what stays constant.

---

## Guidelines per layer

**Static — make it free and mandatory.** Types and lint run on every edit and in CI. This is the
cheapest confidence you will ever buy; treat a type error as a failing test.

**Unit — for logic, not glue.** Test pure functions, calculations, edge cases, and error paths.
Don't unit-test framework wiring or trivial getters — that's maintenance with no confidence return.

**Integration — put the bulk here.** Test a feature with its real collaborators (or close stand-ins:
in-memory DB, local services), asserting observable behaviour rather than internal calls. This is
where most regressions are caught for the least brittleness. If you're unsure which layer a new test
belongs in, default here.

**E2E — reserve for critical journeys.** Login, primary create/update flows, anything that would
cause real damage if silently broken. Prefer role/label selectors over CSS (they double as
accessibility checks and survive refactors). Reach authenticated state the *same* way every spec
does — a shared logged-in session (e.g. a saved storage state from a one-time setup), never
credentials hardcoded in specs; read secrets from env. Keep the count low on purpose.

**Visual — thin, deterministic, full-route.** Full-route screenshot baselines for a handful of key
screens. Determinism rule: baselines carry a per-OS suffix, so **capture and bless on the same OS
your CI runs on**. Screenshots are *inspection* (the diff report shows expected/actual/diff, served
by `/visual-report`); *approval* is a deliberate human re-baseline + commit — never automated. See
`/visual-setup`, `/visual-report`, and the `guard-visual-update` gate. There is deliberately no
component-isolation (Storybook) or click-through review-app tier — full-route screenshots are the
whole surface.

**Accessibility — an assertion, not a suite.** Owned by **`/test-writer`**: it derives an **axe**
assertion of **zero** WCAG 2.1 A/AA violations from the task's acceptance criteria and puts it
*inside* the existing e2e/component specs — no new folder, no standalone a11y suite. Any per-call
rule-disable must reference a ticket, or the list becomes where accessibility quietly dies. For many
enterprise and public-sector buyers this is a procurement requirement, so treat it as first-class.
(The mechanics — tags, scoping, the assertion shape — live in `/test-writer`, not here.)

**Security & performance — already wired.** These are continuous in this template via agents and
guards, not something you bolt on per feature. Keep secrets in env (the secret-scan guard enforces
it), audit dependencies regularly, and measure hot paths against a budget rather than guessing.

---

## Two modes of browser testing — don't confuse them

| Mode | Purpose | Lifecycle | Home |
|---|---|---|---|
| **Throwaway verification** | "Does this render / work right now?" during development | disposable | `.scratch/` (gitignored) — see `/webapp-testing` |
| **Committed specs** | Durable regression coverage | committed | `tests/e2e/` + visual baselines — see `/test-writer` |

Iterate in the throwaway loop while building; promote to a committed spec only once a behaviour or
screen stabilises and is worth defending. This keeps the durable suite lean instead of accreting
every exploratory check.

---

## Anti-patterns to guard against

- **Top-heavy trophy.** Over-investing in e2e/visual because they're satisfying to watch, while
  integration coverage stays sparse. Most *new* confidence should come from the integration layer.
- **Testing implementation, not behaviour.** Asserting internal calls/DOM structure makes tests
  break on safe refactors. Assert what a user or caller observes.
- **Brittle selectors.** CSS/xpath tied to layout. Prefer role/label/text.
- **Snapshot sprawl.** A baseline for every screen at every size. Bless a curated few.
- **Silent a11y debt.** A growing rule-disable list with no tickets.
- **New test roots.** Coverage belongs in the declared homes (`tests/e2e/`, visual baselines dir,
  `.scratch/`). Don't invent parallel folders — separation is by *lifecycle*, already defined in
  `.claude/context.md` → Generated files & artifacts.

---

## Cross-references

- Operational choices (runner, e2e tool, commands): `.claude/context.md`
- Author durable specs: `/test-writer` · Live/throwaway verification: `/webapp-testing`
- Verify a task's acceptance + keep e2e thin: `/qa-tester`
- Visual: `/visual-setup` (enable) · `/visual-report` (run & inspect) · `/visual-review` (gate)
- Guards: `guard-visual-update` (no agent re-baselining) · `guard-secret-scan` · `guard-test-files`
