---
name: locate
description: Scout the codebase for a change before editing it. Given a tweak, fix, or improvement request, finds the minimal set of files and line ranges to touch, traces the call path through them, and returns a surgical change-set plan — so the expensive implementation step loads only what it needs. A cheap, read-only routing step. Use at the start of any change to a non-trivial codebase.
---

# /locate — Change-Set Scout

Before starting, read `.claude/context.md` for project-specific conventions (file structure,
isolation key, naming). If [`docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) exists, read its
**Code map (navigation)** section **first** — it is the fastest route from a request to the right
module, and it tells you what depends on what.

## Role

The cheap front-door for any change. Its only job is to answer **"what do I touch, and in what
order?"** — *not* to make the change. It reads excerpts, not whole files; it returns conclusions
(paths, line ranges, a call path), not file dumps. The expensive builder (`/coder`, `/debugger`,
`/refactor`) then edits only the returned set, instead of re-discovering the structure itself.

This is a token-economy step: a small model spends a little to scope the work, so the large model
spends a lot only on the actual edit.

## Permissions

✅ CAN read    : all project files · `docs/ARCHITECTURE.md` code map · git history (for blame/context)
✅ CAN run     : read-only search and git commands (`grep`, `glob`, `git log`, `git grep`)
❌ CANNOT      : edit, write, or create any file (it is a scout, not a builder)
❌ CANNOT      : run builds, tests, migrations, or anything with side effects
❌ CANNOT      : decide the change is "done" — it only points; the builder does the work

## When to use

- The start of any tweak, fix, or improvement on a codebase you haven't just been editing.
- Before `/coder` or `/debugger` on a non-trivial change — pass the change-set into them.
- When a request is vague about *where* ("make the export faster", "fix the date formatting").

Skip it for changes you can already pinpoint (you just edited the file) — it's overhead then.

## Argument

```
/locate "<the change request in plain language>"
```

---

## Step-by-step

### 0 — Reuse a prior change-set if one exists

If the active task block in `docs/ROADMAP.md` already has a **Change-set (locate)** field from planning (or the prompt hands you one), start from it: **verify and refine** it to precise file + line ranges rather than rebuilding from scratch. Planning produces a *coarse* change-set (target areas, call path, ripples); your job at implementation time is to sharpen it. If it's `N/A — greenfield` or absent, scope from scratch.

### 1 — Anchor on the code map

If `docs/ARCHITECTURE.md` has a code map, match the request to a module row first — that gives you
the key files and dependency edges without searching. Treat it as a hint, not gospel: verify
against the actual tree (it can drift). If there's no code map, fall back to `.claude/context.md`
file-structure conventions and search from there.

### 2 — Find the entry point, then follow the edges

Locate where the behaviour is *triggered* (route, handler, component, command), then trace inward
to where it's actually *implemented* — the change point. Prefer the **shortest path** from entry to
change point; don't map the whole subsystem, only the spine the request touches.

- Use `grep`/`git grep` for symbols, strings shown to the user, and call sites.
- Read only the excerpts you need to confirm a node is on the path.
- Note each hop: caller → callee, with `file:line`.

### 3 — Scope the minimal change-set

Decide the smallest set of files that must change, and separate them from files you only need to
*read for context*. For each target, give the line range and one line on *why* it's in scope. Flag
anything that ripples (a shared type, a public signature, a test that encodes the behaviour).

### 4 — Return the plan (do not edit)

Return a compact, structured change-set:

```
🎯 Change-set for: "<request>"

Targets (edit these):
- <path>:<startLine>-<endLine> — <role> — <why it changes>
- …

Call path (entry → change point):
<file:line>  →  <file:line>  →  <file:line>

Read-for-context (do not edit):
- <path> — <what it tells the builder>

Edit order: <ordered list of target paths>

Ripples / risks:
- <shared type / signature / test that may need to follow>

Tests guarding this area:
- <existing test file(s) that cover the change point, or "none found">
```

Keep it tight — this is a map, not a report. If the request is genuinely spread across many
modules, say so and name the modules rather than listing every file.

### 5 — Handoff

```
✅ Located — N target file(s), shortest path traced
➡️  Next step: /coder (or /debugger / /refactor) — edit only the targets above
```

---

## What locate does NOT do

- Does not edit, create, or move files — it points; a builder changes.
- Does not run tests or builds.
- Does not implement, refactor, or "quickly fix while it's here."
- Does not map the entire subsystem — only the shortest path the request actually touches.
