---
name: code-map
description: Regenerate the codebase router index at .claude/code-map.md — a lean, machine-generated map of "where does this live and what depends on what?" that /planner and /locate read before grepping the tree. Deterministic script (no LLM tokens to generate); stack-agnostic. Run after adding/moving/renaming modules, or when the freshness hook nudges.
---

# /code-map — Router-index generator

Regenerates [`.claude/code-map.md`](../../code-map.md), the **mechanical** map of the codebase:
one row per area with its key files, file count, and heuristic dependency edges. It is the fast
answer to *"where does this live, and what depends on it?"* — so `/planner` and `/locate` read
~40 lines instead of grepping the whole tree.

This is a **script**, not an LLM step — generating the map costs ≈zero tokens; the payoff is the
cheap *read* downstream. It is complementary to the hand-curated `## Code map (navigation)` table
in `docs/ARCHITECTURE.md` (which carries the semantics a script can't infer — responsibility,
public-API entry points). A fact lives in one place: structure/edges here, semantics there.

## When to run

- After a module is **added, moved, or renamed** (the freshness hook `remind-code-map.sh` nudges
  when a file appears in a new area).
- At the start of a session on a codebase you haven't just been editing, if the stamp looks stale.
- Never needs running for pure edits *within* an existing file — structure hasn't changed.

## How

Run the command configured in `.claude/hooks/stack-profile.sh` (`STACK_CODE_MAP_CMD`), which
defaults to the portable zero-dependency generator:

```bash
node .claude/skills/code-map/generate.mjs            # regenerate
node .claude/skills/code-map/generate.mjs --check    # exit 0 fresh / 1 stale, no write
node .claude/skills/code-map/generate.mjs --depth 2  # grouping granularity (default 2 path segments)
```

The default generator is stack-agnostic: `git ls-files` → group by directory → grep
`import`/`require`/`from` lines → resolve to groups (reads `tsconfig`/`jsconfig` path aliases when
present, else best-suffix-match). An adopting project can override `STACK_CODE_MAP_CMD` to plug in
a real graph tool (madge, dependency-cruiser, pydeps) for exact edges.

## Notes

- The output file is **generated** — never hand-edit it (the header says so). Re-run instead.
- Edges are a **heuristic**: a strong hint, not gospel. Alias resolution across unusual configs can
  miss an edge — verify against the tree when precision matters.
- The map is **committed** so a fresh clone has it without a build step; the `tree-stamp` in the
  header makes staleness detectable (`--check`).
