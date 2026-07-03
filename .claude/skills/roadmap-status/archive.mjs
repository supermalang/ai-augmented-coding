#!/usr/bin/env node
// archive.mjs — sweep completed task blocks out of docs/ROADMAP.md into a per-sprint
// archive, leaving a compact one-line ledger entry in the live file. Node built-ins only.
//
// Keeps the LIVE roadmap proportional to active work: nearly every agent reads ROADMAP.md,
// so cumulative done-history must not bloat it. Git preserves full history regardless; the
// archive file is a convenience, not the source of truth.
//
// A task block is ARCHIVABLE when its `**Completion date:**` holds a real date (not `—`) —
// the single unambiguous "this shipped" marker (/pr-reviewer sets it at delivery).
//
// Guarantees: lossless (archived block == original block text), idempotent (re-run = no-op
// once a block is moved), and a true no-op on an empty / all-open roadmap (no files created).
//
// Usage: node archive.mjs [--roadmap <path>] [--archive-dir <dir>]

import { readFileSync, writeFileSync, existsSync, mkdirSync, appendFileSync } from 'node:fs';
import { join, dirname } from 'node:path';

const DATE_RE = /\d{4}-\d{2}-\d{2}/;

function arg(name, def) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : def;
}

/** Split the roadmap into task blocks. A block runs from `### <ID> — …` to the next
 *  `### ` / `## ` heading (or EOF). Returns {id,title,text,startLine,endLine}. */
export function parseBlocks(lines) {
  const blocks = [];
  let cur = null;
  const push = (endLine) => {
    if (!cur) return;
    cur.endLine = endLine;
    cur.text = lines.slice(cur.startLine, endLine).join('\n');
    blocks.push(cur);
    cur = null;
  };
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(/^###\s+(\S+)\s+—\s+(.*)$/);
    if (h) { push(i); cur = { id: h[1], title: h[2].trim(), startLine: i }; continue; }
    if (cur && /^##\s+/.test(lines[i])) push(i); // a section heading ends the current block
  }
  push(lines.length);
  return blocks;
}

function fieldOf(text, label) {
  const m = text.match(new RegExp('\\*\\*' + label + ':\\*\\*\\s*(.+)'));
  return m ? m[1].trim() : '';
}

function prOf(text) {
  const m = text.match(/^-\s*PR\s*:\s*(.+)$/m);
  return m ? m[1].trim().replace(/\(fill in.*\)/, '').trim() || '—' : '—';
}

function sprintOf(text) {
  const s = fieldOf(text, 'Sprint'); // e.g. "Sprint 1"
  const m = s.match(/(\d+)/);
  return m ? m[1] : 'unsorted';
}

/** Trim trailing blank lines and a trailing `---` separator from a block's text. */
function stripSeparator(text) {
  return text.replace(/\n+\s*---\s*$/,'').replace(/\s+$/,'') + '\n';
}

export function archiveRoadmap({ roadmapPath, archiveDir }) {
  if (!existsSync(roadmapPath)) return { archived: [], reason: 'no roadmap file' };
  const original = readFileSync(roadmapPath, 'utf8');
  const lines = original.split('\n');
  const blocks = parseBlocks(lines);

  const archivable = blocks.filter((b) => DATE_RE.test(fieldOf(b.text, 'Completion date')));
  if (archivable.length === 0) return { archived: [], reason: 'nothing to archive' };

  // Remove archivable blocks from the live text (splice from the bottom up to keep indices valid).
  let liveLines = lines.slice();
  const ledger = [];
  for (const b of [...archivable].sort((a, z) => z.startLine - a.startLine)) {
    const sprint = sprintOf(b.text);
    const date = (fieldOf(b.text, 'Completion date').match(DATE_RE) || ['—'])[0];
    const pr = prOf(b.text);
    ledger.push({ id: b.id, title: b.title, date, pr, sprint });

    // Append losslessly to the sprint archive (skip if that id is already archived → idempotent).
    const archiveFile = join(archiveDir, `sprint-${sprint}.md`);
    mkdirSync(archiveDir, { recursive: true });
    const existing = existsSync(archiveFile) ? readFileSync(archiveFile, 'utf8') : '';
    if (!existing.includes(`### ${b.id} —`)) {
      if (!existing) appendFileSync(archiveFile, `# Sprint ${sprint} — archived (delivered) tasks\n\n> Full history also in git. Live roadmap keeps only the ledger row.\n\n`);
      appendFileSync(archiveFile, stripSeparator(b.text) + '\n---\n\n');
    }
    liveLines.splice(b.startLine, b.endLine - b.startLine);
  }

  // Ensure a Delivered-ledger table exists; add a row per archived task (no duplicates).
  let live = liveLines.join('\n');
  const LEDGER_HEAD = '## ✅ Delivered (archived)';
  if (!live.includes(LEDGER_HEAD)) {
    live = live.replace(/\s*$/, '') + `\n\n---\n\n${LEDGER_HEAD}\n\n` +
      '> Full task blocks live in `docs/roadmap/archive/` and in git history.\n\n' +
      '| ID | Title | Done | PR |\n|----|-------|------|----|\n';
  }
  for (const e of ledger.reverse()) {
    const row = `| ${e.id} | ${e.title} | ✅ ${e.date} | ${e.pr} |`;
    if (!live.includes(`| ${e.id} |`)) {
      // insert right after the ledger table header separator line
      live = live.replace(/(## ✅ Delivered \(archived\)[\s\S]*?\|----\|-------\|------\|----\|\n)/, `$1${row}\n`);
    }
  }

  writeFileSync(roadmapPath, live.replace(/\n{3,}/g, '\n\n'));
  return { archived: ledger.map((e) => e.id) };
}

// CLI
if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('archive.mjs')) {
  const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const roadmapPath = arg('--roadmap', join(root, 'docs/ROADMAP.md'));
  const archiveDir = arg('--archive-dir', join(dirname(roadmapPath), 'roadmap/archive'));
  const res = archiveRoadmap({ roadmapPath, archiveDir });
  if (res.archived.length) console.log(`Archived ${res.archived.length} task(s): ${res.archived.join(', ')}`);
  else console.log(res.reason === 'nothing to archive' ? 'Nothing to archive — no delivered tasks in the live roadmap.' : res.reason);
}
