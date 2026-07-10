---
name: hotfix
description: Urgent production-incident fast-lane. Branches from the production branch, reproduces the bug as a failing regression test FIRST, applies the minimal fix, runs the relevant guards + a focused review, and opens a PR into production — never auto-merging. Fast means skipping ceremony (sprint/DoR/estimation), never safety (regression test, guards, human merge gate). After merge: back-merge production → develop and backfill the incident into a roadmap task + run trace. Use only for live-production emergencies.
---

# /hotfix — Incident fast-lane

Before starting, read `.claude/context.md` → *Hotfix / incident fast-lane* (production branch +
relevant-reviewer set) and *Version control & forge* (forge + open-PR command).

**The principle: fast means skipping *ceremony*, never *safety*.** A hotfix bypasses sprint planning,
DoR, and estimation — but it keeps the regression test, every guard hook, and the human merge gate,
because it patches *live* code. Nothing here grants a guard exemption; it *adds* a requirement (a test).

Usage: `/hotfix <short description of the production symptom>`

## Permissions

✅ CAN read    : all project files · git history
✅ CAN write   : the failing regression test · the minimal fix · the incident record · `docs/ROADMAP.md` (lightweight Fix entry) · `.current-task`
✅ CAN run     : tests · lint · relevant guards · `git` · `git push` · open a PR via the forge in `.claude/context.md`
❌ CANNOT      : branch from `develop` (must patch what's live) · skip the regression test · skip guards · **merge** (human gate) · close the incident before the back-merge PR exists

## Flow

### 1 — Branch from production (never develop)

Read the **production branch** (`.claude/context.md` → *Hotfix*, default `main`). Make sure it's current, then cut the hotfix branch:

```bash
git fetch origin
git switch <production-branch> && git pull --ff-only
git switch -c hotfix/<short-id>        # e.g. hotfix/login-500
```

Branching from `develop` is wrong — you must patch what is *live*. (`guard-git-flow` still applies.)

### 2 — Minimal incident record (no DoR/estimate ceremony) — and satisfy the gate

Write a **lightweight** incident record — id, symptom, severity — to `docs/incidents/<YYYY-MM-DD>-<id>.md`.
Then, because `guard-roadmap-gate` stays fully active (no exemption), add a **lightweight** roadmap
entry so gated edits are allowed — this is the fix's roadmap presence, not full ceremony:

- Add a `Type: Fix` line item to `docs/ROADMAP.md` (id, one-line symptom, `Severity`, `Schema impact: None` unless it isn't). No estimate/DoR fields needed — a fix entry is allowed to be lightweight.
- Write `.current-task` at the worktree root (line 1 = the fix id, line 3 = start timestamp from `date -u +%Y-%m-%dT%H:%M:%SZ`).

This keeps the roadmap gate satisfied the lightweight way — the emergency skips *ceremony*, not the *gate*.

### 3 — Reproduce as a failing test FIRST (mandatory — never skipped)

Write a regression test that **reproduces the bug and fails** against the current live code. This is
the one step urgency may never skip: it's what stops the bug silently returning. Run it, confirm it
**fails** (RED). Only then write the **minimal** fix — smallest change that makes the test pass; no
refactoring, no extra features. Re-run: the test now passes (GREEN) and the suite stays green.

> `guard-hotfix-test` blocks the push/PR if the branch adds no test file — so the test is not optional.

### 4 — Relevant guards + a focused review (never zero, never the full battery)

Run the reviewer subset that fits the **bug class** (`.claude/context.md` → *Hotfix* → relevant
reviewers) — e.g. `security-audit` for a security fix, `performance` for a query/perf fix, `ux-review`
+ `qa-tester` for a UI fix; at minimum `qa-tester`. Skip the reviewers that don't apply — that's the
speed. All guard hooks stay active regardless. Resolve any blocker before the PR.

### 5 — Open a PR into production (human merge gate unchanged)

```bash
git push -u origin hotfix/<short-id>          # guard-hotfix-test verifies a test is present
```

Open a PR/MR **against the production branch** (not `develop`) using the forge command in
`.claude/context.md`. Title `fix(hotfix): <symptom>`. In the body: symptom, severity, root cause, the
regression test, and the reviews run. **Never merge** — however urgent, the human merges (branch
protection + the human gate stand). Note in the PR that a **back-merge to `develop`** (step 6) and an
**incident backfill** (step 7) are required follow-ups.

### 6 — Back-merge production → develop (REQUIRED after merge)

Once the human merges the hotfix to production, the fix must reach `develop` too, or the next
`develop → main` promotion will silently reintroduce the bug. Open a back-merge PR:

```bash
git fetch origin
git switch -c chore/backmerge-hotfix-<id> origin/<production-branch>
git push -u origin chore/backmerge-hotfix-<id>
# open a PR: base = develop, head = chore/backmerge-hotfix-<id>  (title: "chore: back-merge hotfix <id> to develop")
```

The incident is **not closed** until this back-merge PR exists. (If the fix also needs to be applied
differently on `develop` due to drift, resolve conflicts in this PR — never by editing the hotfix.)

### 7 — Backfill the process (so the incident is tracked)

Reconcile the lightweight entry into a **proper roadmap `Type: Fix` task** (fuller description, root
cause, acceptance = the regression test) and append a **run trace** to its Delivery block so `/retro`
sees it:

```markdown
### Run trace
- **Skills invoked:** hotfix → <focused reviewers> → pr
- **Reviews:** <the subset run, with blockers/warnings>
- **Debugger retries:** <n>
- **Stop reason:** PR opened (hotfix)
- **Duration:** <from the incident timestamps>
```

Recurring incidents then surface as patterns in `/retro` (and feed `/hill-climb` if enabled). Remove
`.current-task` when done.

### 8 — Report back

```
🚑 Hotfix       : hotfix/<id> — <symptom>  (sev <n>)
🧪 Regression   : <test file> — RED→GREEN confirmed
🔎 Reviews      : <subset run> — <blockers resolved>
🔗 PR           : <url> → <production-branch>  (human merge — NOT merged by me)
➡️  Required next : merge → back-merge PR to develop → backfill roadmap task + run trace
```

## What /hotfix does NOT do

- Does not branch from `develop`, and does not target `develop` with the fix PR (production only).
- Does not skip the regression test, the guards, or the human merge gate — no exemptions.
- Does not auto-merge, however urgent.
- Does not close the incident before the back-merge PR exists.
- Does not run the full review battery — only the reviewers relevant to the bug class (but never zero).
