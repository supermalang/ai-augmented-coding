# Roadmap archive

Full task blocks for **delivered** tasks, swept out of the live `docs/ROADMAP.md` to keep it
proportional to *active* work (nearly every pipeline agent reads the roadmap each run).

- One file per sprint: `sprint-<N>.md`.
- Written by `/roadmap-status archive` (see `.claude/skills/roadmap-status/archive.mjs`), which moves
  each block whose `**Completion date:**` is set and leaves a one-line ledger row in the live file's
  **✅ Delivered (archived)** table.
- **Git history is the real source of truth** — this archive is a convenience for browsing shipped
  work without bloating the live roadmap. Archiving is lossless and idempotent.

Do not hand-edit these files during normal work; run the archive command instead.
