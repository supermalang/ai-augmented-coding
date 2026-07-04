#!/usr/bin/env node
// generate.mjs — regenerate .claude/code-map.md, a lean, machine-generated "router index"
// of the codebase. Node built-ins only. Stack-agnostic (no language toolchain required).
//
// WHY: /planner and /locate need to answer "where does this live, and what depends on it?"
// without grepping the whole tree each run. A hand-written map rots; this one is regenerated
// from the actual tracked files, so it can't drift silently. Generating it is a *script*
// (≈zero LLM tokens); the win is that agents then READ ~40 lines instead of exploring.
//
// This is the MECHANICAL index (groups, key files, heuristic edges). It is complementary to
// the hand-curated `## Code map (navigation)` table in docs/ARCHITECTURE.md, which carries
// the semantics a script can't infer (responsibility, public-API entry points).
//
// HOW: `git ls-files` → group by directory → grep import/require/from lines → resolve to
// groups → write the map, stamped with a content hash so staleness is detectable.
//
// Usage:
//   node .claude/skills/code-map/generate.mjs            # regenerate the map
//   node .claude/skills/code-map/generate.mjs --check    # exit 0 if fresh, 1 if stale (no write)
//   node .claude/skills/code-map/generate.mjs --depth 2 --out .claude/code-map.md

import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, extname, posix } from 'node:path';
import { createHash } from 'node:crypto';
import { execSync } from 'node:child_process';

// ── args ────────────────────────────────────────────────────────────────────
function arg(name, def) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : def;
}
const CHECK = process.argv.includes('--check');
const ROOT = (process.env.CLAUDE_PROJECT_DIR || process.cwd()).replace(/\\/g, '/');
const OUT = arg('--out', '.claude/code-map.md');
const DEPTH = parseInt(arg('--depth', '2'), 10);
const OUT_ABS = posix.join(ROOT, OUT);

// Source extensions we treat as "code" (grouped + scanned for edges). Broad on purpose —
// the pipeline is stack-agnostic. Non-code tracked files are ignored for the map.
const CODE_EXT = new Set([
  'ts', 'tsx', 'js', 'jsx', 'mjs', 'cjs', 'vue', 'svelte', 'astro',
  'py', 'go', 'rb', 'php', 'java', 'kt', 'kts', 'rs', 'scala', 'swift',
  'c', 'cc', 'cpp', 'cxx', 'h', 'hpp', 'cs', 'ex', 'exs', 'dart',
]);

// ── 1. list tracked files (git), fall back to a filesystem walk ───────────────
function trackedFiles() {
  try {
    const out = execSync('git ls-files', { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    return out.split('\n').map((s) => s.trim()).filter(Boolean);
  } catch {
    const IGNORE = new Set(['.git', 'node_modules', 'dist', 'build', 'out', '.next', 'coverage', 'vendor', 'target', '__pycache__', '.venv', 'venv']);
    const acc = [];
    (function walk(dir) {
      let entries;
      try { entries = readdirSync(join(ROOT, dir), { withFileTypes: true }); } catch { return; }
      for (const e of entries) {
        if (IGNORE.has(e.name)) continue;
        const rel = dir ? `${dir}/${e.name}` : e.name;
        if (e.isDirectory()) walk(rel);
        else if (e.isFile()) acc.push(rel);
      }
    })('');
    return acc;
  }
}

// Content stamp: hash the tracked (mode, blob-sha, path) tuples so the stamp changes whenever
// tracked content or the file set changes. Falls back to a hash of the path list off-git.
function contentStamp(files) {
  try {
    const out = execSync('git ls-files -s', { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    return createHash('sha256').update(out).digest('hex').slice(0, 12);
  } catch {
    return createHash('sha256').update(files.slice().sort().join('\n')).digest('hex').slice(0, 12);
  }
}

const ext = (p) => extname(p).slice(1).toLowerCase();
const isCode = (p) => CODE_EXT.has(ext(p));

// ── 2. group by directory (first DEPTH segments) ──────────────────────────────
function groupOf(path) {
  const segs = path.split('/');
  if (segs.length === 1) return '(root)';
  return segs.slice(0, Math.min(DEPTH, segs.length - 1)).join('/');
}

// ── 3. resolve an import specifier to a tracked file (heuristic) ───────────────
function loadAliases() {
  // Read tsconfig/jsconfig compilerOptions.paths + baseUrl for @/-style aliases.
  for (const name of ['tsconfig.json', 'jsconfig.json']) {
    const p = posix.join(ROOT, name);
    if (!existsSync(p)) continue;
    try {
      // tolerate comments/trailing commas commonly found in tsconfig
      const raw = readFileSync(p, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1').replace(/,(\s*[}\]])/g, '$1');
      const cfg = JSON.parse(raw);
      const co = cfg.compilerOptions || {};
      const baseUrl = (co.baseUrl || '.').replace(/\\/g, '/');
      const paths = co.paths || {};
      const rules = [];
      for (const [k, v] of Object.entries(paths)) {
        if (!Array.isArray(v) || !v.length) continue;
        rules.push({ prefix: k.replace(/\*$/, ''), target: posix.join(baseUrl, v[0].replace(/\*$/, '')) });
      }
      return rules;
    } catch { /* ignore malformed config */ }
  }
  return [];
}

function makeResolver(fileSet) {
  const aliases = loadAliases();
  // Try candidate path (no ext) against the tracked-file set: exact, +ext, /index+ext.
  const exts = [...CODE_EXT];
  function tryPath(cand) {
    cand = posix.normalize(cand).replace(/^\.\//, '');
    if (fileSet.has(cand)) return cand;
    for (const e of exts) if (fileSet.has(`${cand}.${e}`)) return `${cand}.${e}`;
    for (const e of exts) if (fileSet.has(`${cand}/index.${e}`)) return `${cand}/index.${e}`;
    for (const e of exts) if (fileSet.has(`${cand}/__init__.${e}`)) return `${cand}/__init__.${e}`;
    return null;
  }
  // Suffix match: a bare/dotted spec that ends at a real file (last-resort heuristic).
  function suffixMatch(spec) {
    for (const e of exts) {
      const want = `${spec}.${e}`;
      for (const f of fileSet) if (f === want || f.endsWith(`/${want}`)) return f;
    }
    for (const f of fileSet) if (f === spec || f.endsWith(`/${spec}`)) return f;
    return null;
  }
  return function resolve(spec, fromFile) {
    if (!spec) return null;
    if (spec.startsWith('.')) {
      return tryPath(posix.join(dirname(fromFile), spec));
    }
    for (const r of aliases) {
      if (spec === r.prefix.replace(/\/$/, '') || spec.startsWith(r.prefix)) {
        const hit = tryPath(posix.join(r.target, spec.slice(r.prefix.length)));
        if (hit) return hit;
      }
    }
    // Python dotted module (no slash) → path form.
    if (!spec.includes('/') && spec.includes('.')) {
      const hit = tryPath(spec.replace(/\./g, '/'));
      if (hit) return hit;
    }
    return suffixMatch(spec);
  };
}

// ── 4. scan a file for import specifiers ──────────────────────────────────────
const IMPORT_RES = [
  /\bimport\b[^'"\n]*?['"]([^'"\n]+)['"]/g,      // JS/TS: import x from 'y' | import 'y'
  /\bexport\b[^'"\n]*?\bfrom\b\s*['"]([^'"\n]+)['"]/g, // JS/TS: export … from 'y'
  /\brequire\(\s*['"]([^'"\n]+)['"]\s*\)/g,       // CJS: require('y')
  /^\s*from\s+([.\w]+)\s+import\b/gm,             // Python: from a.b import c
];
function specsIn(text) {
  const out = new Set();
  for (const re of IMPORT_RES) {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(text))) out.add(m[1]);
  }
  return out;
}

// ── build ─────────────────────────────────────────────────────────────────────
const allFiles = trackedFiles();
const stamp = contentStamp(allFiles);

// --check: compare stamp to the existing map's stamp; no write.
if (CHECK) {
  if (!existsSync(OUT_ABS)) { console.log('stale: no map yet'); process.exit(1); }
  const cur = readFileSync(OUT_ABS, 'utf8');
  const m = cur.match(/tree-stamp:\s*([0-9a-f]+)/);
  if (m && m[1] === stamp) { console.log('fresh'); process.exit(0); }
  console.log('stale'); process.exit(1);
}

const codeFiles = allFiles.filter(isCode);
const fileSet = new Set(allFiles);
const resolve = makeResolver(fileSet);

const groups = new Map(); // group -> { files:[], deps:Set, inDeg:Map(file->n) }
const g = (name) => {
  if (!groups.has(name)) groups.set(name, { files: [], deps: new Set(), inDeg: new Map() });
  return groups.get(name);
};
for (const f of codeFiles) g(groupOf(f)).files.push(f);

// edges
for (const f of codeFiles) {
  const from = groupOf(f);
  let text;
  try { text = readFileSync(posix.join(ROOT, f), 'utf8'); } catch { continue; }
  for (const spec of specsIn(text)) {
    const target = resolve(spec, f);
    if (!target || target === f) continue;
    const to = groupOf(target);
    if (to !== from) g(from).deps.add(to);
    const gt = g(to);
    gt.inDeg.set(target, (gt.inDeg.get(target) || 0) + 1);
  }
}

// key files per group: highest in-degree, then shallowest path, then name.
function keyFiles(group, n = 3) {
  const gg = groups.get(group);
  const scored = gg.files.slice().sort((a, b) => {
    const da = gg.inDeg.get(a) || 0, db = gg.inDeg.get(b) || 0;
    if (db !== da) return db - da;
    const sa = a.split('/').length, sb = b.split('/').length;
    if (sa !== sb) return sa - sb;
    return a.localeCompare(b);
  });
  return scored.slice(0, n).map((p) => p.split('/').pop());
}

// ── 5. render ───────────────────────────────────────────────────────────────
const names = [...groups.keys()].sort((a, b) => groups.get(b).files.length - groups.get(a).files.length || a.localeCompare(b));
const lines = [];
lines.push('# Code map (generated — do not edit by hand)');
lines.push('');
lines.push(`> Machine-generated router index of the codebase — the fast answer to *"where does this`);
lines.push('> live, and what depends on what?"* **read this before grepping the tree.** Regenerate with');
lines.push('> `/code-map` (or the `STACK_CODE_MAP_CMD` in `.claude/hooks/stack-profile.sh`). Edges are a');
lines.push('> heuristic (import/require/from grep + alias resolution) — treat them as a strong hint, not');
lines.push('> gospel; verify against the tree when precision matters. For the *semantics* a script can\'t');
lines.push('> infer (responsibility, public-API entry points), see the hand-curated `## Code map');
lines.push('> (navigation)` table in `docs/ARCHITECTURE.md`.');
lines.push('>');
lines.push(`> tree-stamp: ${stamp} · groups: ${names.length} · code files: ${codeFiles.length}`);
lines.push('');
lines.push('| Area | Key files | Files | Depends on |');
lines.push('|---|---|---|---|');
for (const name of names) {
  const gg = groups.get(name);
  const kf = keyFiles(name).join(', ') || '—';
  const deps = [...gg.deps].sort().join(', ') || '—';
  lines.push(`| \`${name}\` | ${kf} | ${gg.files.length} | ${deps} |`);
}
lines.push('');

writeFileSync(OUT_ABS, lines.join('\n'), 'utf8');
console.log(`✅ code-map: ${names.length} areas, ${codeFiles.length} code files → ${OUT} (stamp ${stamp})`);
