// archive.test.mjs — fixture tests for the roadmap archiver. Node built-ins only.
// Run: node .claude/skills/roadmap-status/tests/archive.test.mjs
import { mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { archiveRoadmap, parseBlocks } from '../archive.mjs';

let pass = 0, fail = 0;
const ok = (c, m) => c ? (pass++, console.log('  ✓ ' + m)) : (fail++, console.log('  ✗ ' + m));

const DONE = `### RB-9 — A delivered task

**Sprint:** Sprint 1
**Completion date:** 2026-07-01
**Type:** Feature

**Description**
Something shipped.

**Delivery**
- Commit : abc1234
- PR     : #42
`;

const OPEN = `### RB-10 — An open task

**Sprint:** Sprint 1
**Completion date:** —
**Type:** Feature

**Description**
Not done yet.
`;

const HEADER = `# ROADMAP

## Task Template

(static header stays put)

---

## 🏃 Sprint 1 — Demo

| Task | Status | Delivered |
|------|--------|-----------|
| RB-9 A delivered task | ✓ | 2026-07-01 |
| RB-10 An open task | ⬜ | — |

`;

function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'rb-'));
  const roadmapPath = join(root, 'ROADMAP.md');
  const archiveDir = join(root, 'archive');
  writeFileSync(roadmapPath, HEADER + DONE + '\n---\n\n' + OPEN + '\n');
  return { root, roadmapPath, archiveDir };
}

// 1 — parseBlocks finds both task blocks
{
  const blocks = parseBlocks((HEADER + DONE + '\n---\n\n' + OPEN).split('\n'));
  ok(blocks.length === 2, 'parseBlocks: finds 2 task blocks');
  ok(blocks[0].id === 'RB-9' && blocks[1].id === 'RB-10', 'parseBlocks: extracts ids in order');
}

// 2 — archives only the delivered task; open task stays
{
  const { root, roadmapPath, archiveDir } = fixture();
  const res = archiveRoadmap({ roadmapPath, archiveDir });
  const live = readFileSync(roadmapPath, 'utf8');
  ok(res.archived.length === 1 && res.archived[0] === 'RB-9', 'archive: only the delivered task archived');
  ok(!live.includes('### RB-9 —'), 'archive: delivered block removed from live file');
  ok(live.includes('### RB-10 —'), 'archive: open block kept in live file');
  ok(live.includes('(static header stays put)'), 'archive: static header preserved');

  // lossless: archive holds the full original block
  const archived = readFileSync(join(archiveDir, 'sprint-1.md'), 'utf8');
  ok(archived.includes('### RB-9 — A delivered task') && archived.includes('- PR     : #42'),
     'archive: block preserved losslessly (heading → last field)');

  // ledger row present with id, date, PR
  ok(/\| RB-9 \| A delivered task \| ✅ 2026-07-01 \| #42 \|/.test(live), 'archive: compact ledger row written');

  rmSync(root, { recursive: true, force: true });
}

// 3 — idempotent: re-run makes no changes and never duplicates
{
  const { root, roadmapPath, archiveDir } = fixture();
  archiveRoadmap({ roadmapPath, archiveDir });
  const after1 = readFileSync(roadmapPath, 'utf8');
  const arch1 = readFileSync(join(archiveDir, 'sprint-1.md'), 'utf8');
  const res2 = archiveRoadmap({ roadmapPath, archiveDir });
  const after2 = readFileSync(roadmapPath, 'utf8');
  const arch2 = readFileSync(join(archiveDir, 'sprint-1.md'), 'utf8');
  ok(res2.archived.length === 0, 'idempotent: second run archives nothing');
  ok(after1 === after2, 'idempotent: live file unchanged on re-run');
  ok(arch1 === arch2, 'idempotent: archive file unchanged on re-run');
  ok((after2.match(/\| RB-9 \|/g) || []).length === 1, 'idempotent: ledger row not duplicated');
  rmSync(root, { recursive: true, force: true });
}

// 4 — no-op: all-open roadmap changes nothing, creates no archive
{
  const root = mkdtempSync(join(tmpdir(), 'rb-'));
  const roadmapPath = join(root, 'ROADMAP.md');
  const archiveDir = join(root, 'archive');
  writeFileSync(roadmapPath, HEADER + OPEN + '\n');
  const before = readFileSync(roadmapPath, 'utf8');
  const res = archiveRoadmap({ roadmapPath, archiveDir });
  ok(res.archived.length === 0 && res.reason === 'nothing to archive', 'no-op: reports nothing to archive');
  ok(readFileSync(roadmapPath, 'utf8') === before, 'no-op: live file untouched');
  ok(!existsSync(archiveDir), 'no-op: no archive dir/file created');
  rmSync(root, { recursive: true, force: true });
}

console.log(`\narchive.test.mjs — ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
