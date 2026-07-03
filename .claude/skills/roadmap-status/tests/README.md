# roadmap-status — archive tests

## Automated (node)

`archive.test.mjs` covers the archiver against markdown fixtures — the invariants that make it safe
to run on a real roadmap:

```bash
node .claude/skills/roadmap-status/tests/archive.test.mjs
```

Asserts: block parsing; only delivered (`Completion date` set) tasks archived; open tasks + static
header preserved; **lossless** (archived block equals the original text); **idempotent** (re-run
changes nothing, no duplicate ledger rows); **no-op** on an all-open roadmap (no archive file created).

## Manual (E2E)

| # | Initial state | Action | Expected |
|---|---|---|---|
| 1 | Roadmap with several delivered + open tasks | `node .claude/skills/roadmap-status/archive.mjs` | Live file keeps only active/planned blocks + the `✅ Delivered (archived)` ledger; `docs/roadmap/archive/sprint-N.md` holds the full delivered blocks; re-run prints "nothing to archive" |
| 2 | Long roadmap after archive | `/start-task <open-id>` | Locates the task block by grepping to it, without reading the whole file |
