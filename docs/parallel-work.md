# Manual parallel work with git worktrees

Sometimes you want two Claude sessions running at once — one per task. Git **worktrees** make that
safe to *execute*: each worktree is its own working directory checked out to its own branch, all
sharing one `.git`. Two sessions, two directories, no branch-switch churn.

This is a **manual** workflow. The pipeline does **not** orchestrate parallel worktrees, and the
autonomous trigger's concurrency stays at 1 — you drive the fan-out by hand.

---

## The one durable rule

> **Run parallel worktrees only on tasks with disjoint file sets.**

Worktrees isolate *execution* (separate dirs, separate ephemeral state) — they do **not** make
dependent or overlapping tasks safe to parallelize. This is exactly INVEST's *Independent*: if two
tasks touch the same files, doing them in parallel invites merge conflicts and lost work, and no tool
can prevent that for you. Split or sequence overlapping tasks instead.

An advisory hook (`warn-worktree-overlap.sh`) will **warn** you — never block — when a file you edit
is also changed in a sibling worktree, naming its branch. Treat that warning as a prompt to
coordinate; it does not stop the edit.

---

## Setup

From the main checkout, create one worktree per task, each on its own feature branch:

```bash
# one worktree + branch per task, in a sibling directory
git worktree add ../task-A feature/task-A
git worktree add ../task-B feature/task-B
```

Then open **one Claude session per worktree directory** (`../task-A`, `../task-B`). Each session's
`CLAUDE_PROJECT_DIR` is its own worktree root, so all gates, `.current-task`, and generated state stay
per-worktree.

When a task is done and its PR is merged, remove the worktree:

```bash
git worktree remove ../task-A
git worktree prune          # clean up any stale administrative entries
```

---

## Why it's safe (and where it isn't)

**Isolated automatically — nothing to configure:**

- **Branch & staged-diff gates** — each worktree has its own `HEAD` and index, so `guard-branch`,
  `guard-git-flow`, and `guard-commit-message` already decide per worktree.
- **Ephemeral / generated state** — `.current-task`, `.scratch/**`, `visual-review/results/**`,
  `out/**`, and run traces all resolve from the **worktree root** (`git rev-parse --show-toplevel`;
  hooks read `$CLAUDE_PROJECT_DIR`, which is that root). Two worktrees never read or clobber each
  other's ephemeral files. See the *Generated files & artifacts* table in
  [`.claude/context.md`](../.claude/context.md).

**Needs a per-worktree scheme — configure once (see [`.claude/context.md`](../.claude/context.md) →
*Parallel worktrees*):**

- **Dev-server port & test-DB name** — two worktrees booting a server or test DB would fight over the
  same port/name. Derive a `WORKTREE_ID` (default: the worktree dir basename) and fold it into a
  per-worktree port (base + small deterministic offset) and DB name (`<base>_<WORKTREE_ID>`). The
  **main** worktree keeps the base values, so single-worktree use is unchanged. The visual-report
  server (`.claude/skills/visual-report/open-report.sh`) already does this for its report port.

**Not protected by tooling — your responsibility:**

- **Overlapping file sets.** The overlap hook warns, but it cannot see another worktree's *future*
  edits, and overlap is sometimes intentional. The disjoint-files rule above is the real guard.

---

## Checklist

- [ ] Each parallel task has a **disjoint** file set (INVEST-independent).
- [ ] One worktree + one branch + one session per task.
- [ ] A per-worktree port/DB scheme is configured if you run servers or test DBs concurrently.
- [ ] Heed (don't ignore) the `warn-worktree-overlap` advisory — coordinate before editing a shared file.
- [ ] `git worktree remove` + `git worktree prune` when a task's PR is merged.
