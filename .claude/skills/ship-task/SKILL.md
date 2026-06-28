---
name: ship-task
description: Autonomous end-to-end pipeline that ships a roadmap task to a PR. Validates DoR, creates branch, runs schema/coder(or debugger for Fix tasks)/test-writer/docs/reviews/PR agents in the correct order with automatic skip logic. Ships one task by ID, or batches the whole ready backlog with `/ship-task open` (dependency-gated, priority-ordered). Human touchpoints only on DoR failure, test failure, and final PR URL. Usage: /ship-task <TASK-ID> (e.g. /ship-task 10.3) or /ship-task open.
---

# ship-task — Autonomous Task Pipeline

Before starting, read `.claude/context.md` for project-specific rules, constraints, and conventions.

## Permissions

✅ CAN read    : all project files
✅ CAN run     : Workflow tool — invoking `/ship-task` is explicit multi-agent opt-in
✅ CAN delegate: all pipeline agent skills (schema-agent, coder, test-writer, debugger, docs, ux-review, perf-review, perf-measure, qa-tester, security-audit, dep-audit, pr-reviewer)
❌ CANNOT      : implement code directly — delegates to `/coder`
❌ CANNOT      : merge PRs — returns PR URL for human review
❌ CANNOT      : mark task [x] without all DoD criteria met

---

## How to use

```
/ship-task 10.3        # ship one task by ID
/ship-task open        # batch: ship every open, DoR-ready task whose dependencies are delivered
```

**Single task** — the ID must match an entry in `docs/ROADMAP.md`. If it does not exist, stop and tell the user to run `/planner` first.

**Batch (`open` / `all` / no ID)** — reads the roadmap and drains the ready backlog: each open task that satisfies the DoR **and** whose `Dependencies` are all delivered (`[x]`), ordered `P0 → P1 → P2` then by ID. It ships each through the same pipeline, **continues past** any task that blocks, and returns a summary (shipped / blocked / skipped-not-ready / waiting-on-deps). A task shipped in the run is *not* counted as a satisfied dependency — its PR is open but unmerged — so dependents are picked up on the next run after you merge.

**Type routing** — a task with `Type: Fix` routes the build step to `/debugger` (reproduce → root cause → minimal fix) instead of `/coder`; both get the RED regression test and the locate change-set. `Feature` (or absent) uses `/coder`.

---

## Pipeline overview

| Step | Agent | Runs when |
|------|-------|-----------|
| 0 | Validate | Always — reads roadmap, checks DoR; **stops if not met** |
| 1 | Setup | Always — writes `.current-task`, creates feature branch |
| 2 | Schema | `impactSchema = "Migration"` only |
| 3 | Test Writer (RED) | Always — writes tests from criteria, confirms they **fail** |
| 3b | Locate (scout) | Always — cheap read-only Haiku pass; scopes the change-set so the coder loads only what it needs |
| 4 | Coder | Always — implements until RED tests turn green, starting from the scout's change-set |
| 5 | Test Writer (GREEN) | Always — re-runs same tests |
| 5b | Debugger (self-repair) | If GREEN fails — auto root-causes and fixes, re-runs; up to 2 attempts before handing to a human |
| 6 | Docs | Task touches API, schema, or UI — updates README/API/CHANGELOG before the commit |
| 7 | Commit | Always — lint + commit implementation + tests + docs; recovery checkpoint |
| 8 | UX Review | Task touches UI components or pages [PROJECT CONVENTION — see .claude/context.md] |
| 9 | Perf Review (static) | Task touches database queries or async data fetching |
| 9b | Perf Measure | Perf-sensitive task (UI or DB) — bundle/Web Vitals/EXPLAIN vs budget |
| 10 | QA Tester | Always — parallel with the other reviews |
| 11 | Security Audit | Always — parallel |
| 11b | Dep Audit | Always — SCA scan for vulnerable dependencies (parallel) |
| — | Blocker gate | Always — **stops if any review returns blockers** |
| 12 | PR Reviewer | Always — verifies DoD, marks roadmap [x], opens PR |

All of steps 8–11b run **in parallel**; the blocker gate waits for them all.

---

## Invoking the Workflow

When this skill is invoked with `/ship-task <TASK-ID>`, call the Workflow tool immediately with `args` set to the task ID string (e.g. `"10.3"`) and the script below. Do not ask for confirmation — the user invoking `/ship-task` is an explicit opt-in for multi-agent orchestration.

```js
export const meta = {
  name: 'ship-task',
  description: 'Autonomous pipeline that ships a roadmap task to a PR — one task by ID, or the whole ready backlog with "open"',
  phases: [
    { title: 'Backlog' },
    { title: 'Validate' },
    { title: 'Setup' },
    { title: 'Schema' },
    { title: 'Implement' },
    { title: 'Document' },
    { title: 'Commit' },
    { title: 'Review' },
    { title: 'Ship' },
  ],
}

// Schemas first (shared by single-task and batch modes); shipOne() and the dispatcher follow them.

const TASK_INFO_SCHEMA = {
  type: 'object',
  required: ['taskBlock', 'taskTitle', 'impactSchema', 'taskType', 'touchesUI', 'touchesPrisma', 'dorMet', 'dorMissing'],
  properties: {
    taskBlock:     { type: 'string' },
    taskTitle:     { type: 'string' },
    impactSchema:  { type: 'string', enum: ['Migration', 'None', 'To confirm'] },
    taskType:      { type: 'string', enum: ['Fix', 'Feature'], description: '"Fix" routes the build to /debugger; "Feature" to /coder' },
    dependencies:  { type: 'array', items: { type: 'string' }, description: 'task IDs this blocks on' },
    touchesUI:     { type: 'boolean' },
    touchesPrisma: { type: 'boolean' },
    dorMet:        { type: 'boolean' },
    dorMissing:    { type: 'array', items: { type: 'string' } },
  },
}

const BACKLOG_SCHEMA = {
  type: 'object',
  required: ['tasks', 'doneIds'],
  properties: {
    doneIds: { type: 'array', items: { type: 'string' }, description: 'IDs of tasks already marked [x] / delivered' },
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'dorMet'],
        properties: {
          id:           { type: 'string' },
          title:        { type: 'string' },
          taskType:     { type: 'string', enum: ['Fix', 'Feature'] },
          priority:     { type: 'string' },
          dependencies: { type: 'array', items: { type: 'string' } },
          dorMet:       { type: 'boolean' },
        },
      },
    },
  },
}

const CODER_RESULT_SCHEMA = {
  type: 'object',
  required: ['filesChanged', 'touchesUI', 'touchesPrisma'],
  properties: {
    filesChanged:     { type: 'array', items: { type: 'string' } },
    touchesUI:        { type: 'boolean' },
    touchesPrisma:    { type: 'boolean' },
    structuralChange: { type: 'boolean', description: 'true if any module/file was added, moved, renamed, or deleted (not just edited) — triggers a code-map refresh' },
    summary:          { type: 'string' },
  },
}

const LOCATE_SCHEMA = {
  type: 'object',
  required: ['targets', 'editOrder'],
  properties: {
    targets:    { type: 'array', items: { type: 'string' }, description: 'files to edit, with line ranges where known (e.g. "src/lib/x.ts:40-72")' },
    callPath:   { type: 'array', items: { type: 'string' }, description: 'entry → change point, as file:line hops' },
    readForContext: { type: 'array', items: { type: 'string' }, description: 'files to read but not edit' },
    editOrder:  { type: 'array', items: { type: 'string' }, description: 'recommended order of edits (target paths)' },
    ripples:    { type: 'array', items: { type: 'string' }, description: 'shared types/signatures/tests that may need to follow' },
  },
}

const TEST_RED_SCHEMA = {
  type: 'object',
  required: ['testFiles', 'testCount', 'failCount', 'redConfirmed'],
  properties: {
    testFiles:    { type: 'array', items: { type: 'string' } },
    testCount:    { type: 'number' },
    failCount:    { type: 'number' },
    redConfirmed: { type: 'boolean', description: 'true if at least one test fails (expected in RED phase)' },
    warning:      { type: 'string', description: 'set if all tests pass vacuously' },
  },
}

const TEST_GREEN_SCHEMA = {
  type: 'object',
  required: ['testsPassed', 'failures'],
  properties: {
    testsPassed: { type: 'boolean' },
    failures:    { type: 'array', items: { type: 'string' } },
  },
}

const DOCS_RESULT_SCHEMA = {
  type: 'object',
  required: ['docFiles', 'updated'],
  properties: {
    docFiles: { type: 'array', items: { type: 'string' }, description: 'doc files created or modified' },
    updated:  { type: 'boolean', description: 'true if any documentation was changed' },
    summary:  { type: 'string' },
  },
}

const REVIEW_RESULT_SCHEMA = {
  type: 'object',
  required: ['label', 'blockers', 'warnings'],
  properties: {
    label:    { type: 'string' },
    blockers: { type: 'array', items: { type: 'string' }, description: 'Must be fixed before merge' },
    warnings: { type: 'array', items: { type: 'string' }, description: 'Worth fixing, not blocking' },
  },
}

// The full single-task pipeline as a function, so batch mode can loop it in-process
// (no workflow nesting, no registry dependency). Returns a status object per task.
async function shipOne(TASK_ID) {

// ── Phase 0: Validate DoR ────────────────────────────────────────────────
phase('Validate')
log('Reading roadmap and validating DoR for task ' + TASK_ID + '…')

const taskInfo = await agent(
  'Read docs/ROADMAP.md. Find the task block for task ID "' + TASK_ID + '" ' +
  '(look for "**' + TASK_ID + ' —" or "**' + TASK_ID + '.**").\n' +
  'Extract and return:\n' +
  '- taskBlock: the full markdown block for this task (from its heading to the next task heading)\n' +
  '- taskTitle: the short title after the em dash\n' +
  '- impactSchema: the value after "Schema impact:" — return exactly "Migration", "None", or "To confirm"\n' +
  '- touchesUI: true if the task description mentions UI, page, form, modal, component, or paths that match the UI source directories defined in .claude/context.md\n' +
  '- touchesPrisma: true if the task description mentions schema, API route, database, or ORM queries\n' +
  '- taskType: the value after "Type:" — return exactly "Fix" or "Feature"; if the field is absent, return "Feature"\n' +
  '- dependencies: array of task IDs listed after "Dependencies:" (empty array if "None" or absent)\n' +
  '- dorMet: true only if ALL of the following are present in the task block:\n' +
  '  1. A task ID is assigned (the block exists)\n' +
  '  2. Schema impact is NOT "To confirm"\n' +
  '  3. At least 2 acceptance criteria bullet points exist\n' +
  '  4. The task is NOT already marked [x]\n' +
  '  5. The task block contains a non-empty description\n' +
  '- dorMissing: list each unmet DoR criterion as a string (empty array if dorMet is true)',
  { schema: TASK_INFO_SCHEMA, phase: 'Validate' }
)

if (!taskInfo) return { status: 'error', reason: 'Could not read task ' + TASK_ID + ' from roadmap. Does it exist?' }

if (!taskInfo.dorMet) {
  log('🚫 DoR not met for task ' + TASK_ID + ': ' + taskInfo.dorMissing.join(', '))
  return { status: 'blocked', reason: 'Definition of Ready not satisfied', taskId: TASK_ID, missing: taskInfo.dorMissing }
}

log('✅ DoR satisfied — "' + taskInfo.taskTitle + '"')

// ── Phase 1: Setup ───────────────────────────────────────────────────────
phase('Setup')
const branchSlug = TASK_ID.replace(/\./g, '-')
await agent(
  'You are setting up the dev environment for task ' + TASK_ID + '.\n' +
  '1. Write the string "' + TASK_ID + '" (no quotes, no trailing newline) to the file .current-task at the project root.\n' +
  '2. Run: git switch -c feature/task-' + branchSlug + '\n' +
  '   If that branch already exists, run: git switch feature/task-' + branchSlug + '\n' +
  '3. Confirm both steps succeeded.',
  { phase: 'Setup' }
)

// ── Phase 2: Schema migration (conditional) ──────────────────────────────
if (taskInfo.impactSchema === 'Migration') {
  phase('Schema')
  log('Schema migration required — running schema-agent…')
  await agent(
    'Read .claude/skills/schema-agent/SKILL.md and follow it exactly.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n\n' +
    'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
    'Complete the full schema-agent workflow: design the migration, apply it, update the schema cheatsheet.',
    { phase: 'Schema', agentType: 'schema-agent' }
  )
}

// ── Phase 3: Tests — RED ─────────────────────────────────────────────────
phase('Implement')
log('Running test-writer (RED phase)…')
const redResult = await agent(
  'Read .claude/skills/test-writer/SKILL.md and follow it exactly.\n' +
  'MODE: RED — you are running BEFORE implementation. Write tests from acceptance criteria only.\n' +
  'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n\n' +
  'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
  'Instructions:\n' +
  '1. Do NOT read implementation files — derive tests from acceptance criteria only\n' +
  '2. Write unit tests and E2E specs per the project test conventions in .claude/context.md\n' +
  '3. Run the unit test suite\n' +
  '4. Tests SHOULD fail — the implementation does not exist yet\n' +
  'Report: testFiles (array of paths written), testCount (number), failCount (number), ' +
  'redConfirmed (true if failCount > 0), and a warning string if all tests pass vacuously.',
  { schema: TEST_RED_SCHEMA, phase: 'Implement', label: 'test-writer (RED)', agentType: 'test-writer' }
)

if (!redResult) return { status: 'error', reason: 'Test-writer (RED) agent failed for task ' + TASK_ID }
if (redResult.warning) log('⚠️  ' + redResult.warning)
// Hard gate: RED tests MUST fail before any implementation. A test that already passes is either
// vacuous or reverse-engineered from existing code — it proves nothing and would sail through GREEN.
// Block rather than ship a hollow test. Critical for Fix tasks, where the buggy implementation
// already exists at RED time, so a code-conforming test would pass and bless the bug.
if (!redResult.redConfirmed || (redResult.failCount || 0) < 1) {
  log('🚫 RED gate: no test failed before implementation — tests look vacuous or conform to existing code, not the criteria')
  return {
    status: 'blocked',
    reason: 'RED phase produced no failing test. Tests must be derived from acceptance criteria and fail before implementation exists (a passing RED test proves nothing).',
    taskId: TASK_ID,
    testFiles: redResult.testFiles,
    warning: redResult.warning,
  }
}
log('🔴 RED phase: ' + redResult.testCount + ' tests written, ' + redResult.failCount + ' failing (expected)')

// ── Phase 4: Locate (cheap scout) then Implement ──────────────────────────
// A read-only Haiku scout scopes the change-set first, so the coder loads only
// what it needs instead of re-discovering the codebase structure itself.
log('Running locate scout…')
const locateResult = await agent(
  'Read .claude/skills/locate/SKILL.md and follow it exactly.\n' +
  'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n\n' +
  'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
  'Scope the implementation change-set for this task: the minimal files to edit (with line ranges), ' +
  'the call path from entry point to change point, files to read for context, the edit order, and any ripples. ' +
  'If the task block above has a "Change-set (locate)" field from planning (and it is not "N/A — greenfield"), ' +
  'verify and REFINE it to precise line ranges rather than rebuilding from scratch. ' +
  'Do NOT edit anything — you are a scout.\n' +
  'Return: targets, callPath, readForContext, editOrder, ripples.',
  { schema: LOCATE_SCHEMA, phase: 'Implement', label: 'locate', agentType: 'locate' }
)
if (locateResult) log('🧭 Located ' + locateResult.targets.length + ' target file(s)')

const locateHint = locateResult
  ? '\n\nChange-set from the locate scout (start here; verify, then implement):\n' +
    '- Targets: ' + JSON.stringify(locateResult.targets) + '\n' +
    '- Call path: ' + JSON.stringify(locateResult.callPath || []) + '\n' +
    '- Read for context: ' + JSON.stringify(locateResult.readForContext || []) + '\n' +
    '- Edit order: ' + JSON.stringify(locateResult.editOrder) + '\n' +
    '- Ripples to watch: ' + JSON.stringify(locateResult.ripples || []) + '\n'
  : ''

// Build routing: Fix tasks go to /debugger (root cause + minimal fix), Feature tasks to /coder.
// Both receive the same RED tests and the locate scout's change-set.
const isFix = taskInfo.taskType === 'Fix'
log(isFix ? 'Fix task — routing the build to /debugger (root cause + minimal fix)…' : 'Running coder…')
const coderResult = isFix
  ? await agent(
      'Read .claude/skills/debugger/SKILL.md and follow it exactly.\n' +
      'Active task (FIX): ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
      'A failing regression test already captures this bug (RED): ' + JSON.stringify(redResult.testFiles) + '\n' +
      locateHint + '\n' +
      'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
      'Reproduce, isolate the ROOT CAUSE, and apply the MINIMAL fix so the failing regression test(s) pass. ' +
      'Do NOT modify the test files — they are the contract. Do NOT add features or refactor unrelated code.\n' +
      'When done, report: which files you changed (array of paths), touchesUI (bool), touchesPrisma (bool), ' +
      'structuralChange (bool — true if you added, moved, renamed, or deleted any file/module, not just edited), ' +
      'and a one-sentence summary of the fix and its root cause.',
      { schema: CODER_RESULT_SCHEMA, phase: 'Implement', label: 'debugger (fix)', agentType: 'debugger' }
    )
  : await agent(
      'Read .claude/skills/coder/SKILL.md and follow it exactly.\n' +
      'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
      'Tests already written (RED phase): ' + JSON.stringify(redResult.testFiles) + '\n' +
      locateHint + '\n' +
      'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
      'Implement the complete task. The test files listed above already exist and are failing — ' +
      'your goal is to make them pass. Do NOT modify the test files.\n' +
      'When done, report: which files you changed (array of paths), ' +
      'whether you touched UI source files (touchesUI bool), ' +
      'whether you touched database queries (touchesPrisma bool), ' +
      'structuralChange (bool — true if you added, moved, renamed, or deleted any file/module, not just edited), ' +
      'and a one-sentence summary of what was implemented.',
      { schema: CODER_RESULT_SCHEMA, phase: 'Implement', label: 'coder', agentType: 'coder' }
    )

if (!coderResult) return { status: 'error', reason: (isFix ? 'Debugger' : 'Coder') + ' agent failed for task ' + TASK_ID }

// ── Phase 5: Tests — GREEN (with /debugger self-repair loop) ──────────────
async function runGreen() {
  return await agent(
    'Read .claude/skills/test-writer/SKILL.md and follow it exactly.\n' +
    'MODE: GREEN — the implementation is now complete. Run the existing tests without modifying them.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
    'Test files to run: ' + JSON.stringify(redResult.testFiles) + '\n\n' +
    'Instructions:\n' +
    '1. Do NOT modify any test file\n' +
    '2. Run the full unit test suite\n' +
    '3. All tests SHOULD pass now\n' +
    'Report: testsPassed (bool), failures (array of failing test names or messages).',
    { schema: TEST_GREEN_SCHEMA, phase: 'Implement', label: 'test-writer (GREEN)', agentType: 'test-writer' }
  )
}

log('Running test-writer (GREEN phase)…')
let greenResult = await runGreen()

// Self-repair: if tests fail, dispatch /debugger to root-cause and fix, then re-run.
// Bounded — after MAX_FIX_ATTEMPTS the pipeline hands back to a human.
const MAX_FIX_ATTEMPTS = 2
let fixAttempts = 0
while ((!greenResult || !greenResult.testsPassed) && fixAttempts < MAX_FIX_ATTEMPTS) {
  fixAttempts++
  const failures = greenResult ? greenResult.failures : ['test-writer agent failed']
  log('🔧 GREEN failing — dispatching /debugger (auto-fix ' + fixAttempts + '/' + MAX_FIX_ATTEMPTS + ')…')
  await agent(
    'Read .claude/skills/debugger/SKILL.md and follow it exactly.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
    'The implementation is complete but these tests still fail:\n' + JSON.stringify(failures) + '\n\n' +
    'Reproduce, find the ROOT CAUSE, and apply the minimal fix to the IMPLEMENTATION so the failing tests pass. ' +
    'Do NOT modify the test files — they are the contract. Do NOT add features.',
    { phase: 'Implement', label: 'debugger (fix #' + fixAttempts + ')', agentType: 'debugger' }
  )
  greenResult = await runGreen()
}

if (!greenResult || !greenResult.testsPassed) {
  const failures = greenResult ? greenResult.failures : ['agent failed']
  log('🚫 Tests still failing after ' + MAX_FIX_ATTEMPTS + ' auto-fix attempt(s) — needs human review')
  return { status: 'blocked', reason: 'Tests not passing after implementation + ' + MAX_FIX_ATTEMPTS + ' debugger attempts', taskId: TASK_ID, failures: failures }
}
log('✅ GREEN phase: all tests passing' + (fixAttempts > 0 ? ' (after ' + fixAttempts + ' auto-fix)' : ''))

// ── Phase: Documentation (conditional) ───────────────────────────────────
// Update docs when the change touches an interface or user-facing surface.
let docFiles = []
if (taskInfo.touchesPrisma || coderResult.touchesPrisma || taskInfo.touchesUI || coderResult.touchesUI || coderResult.structuralChange) {
  phase('Document')
  log('Running docs agent…')
  const docsResult = await agent(
    'Read .claude/skills/docs/SKILL.md and follow it exactly.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
    'Files changed: ' + JSON.stringify(coderResult.filesChanged) + '\n\n' +
    'Update README, API reference, schema cheatsheet, and CHANGELOG to reflect these changes. ' +
    (coderResult.structuralChange ? 'Modules were added/moved/renamed/removed — also refresh the Code map (navigation) table + dependency diagram in docs/ARCHITECTURE.md so /locate stays accurate. ' : '') +
    'Do NOT touch application logic, tests, schema definitions, or docs/ROADMAP.md.\n' +
    'If nothing user-facing or interface-facing changed, make no edits and return updated=false.\n' +
    'Report: docFiles (array of doc paths changed), updated (bool), and a one-sentence summary.',
    { schema: DOCS_RESULT_SCHEMA, phase: 'Document', label: 'docs', agentType: 'docs' }
  )
  if (docsResult && docsResult.updated) {
    docFiles = docsResult.docFiles
    log('📘 Docs updated: ' + docFiles.join(', '))
  } else {
    log('📘 No documentation changes needed')
  }
}

// ── Commit: checkpoint before reviews ────────────────────────────────────
phase('Commit')
log('Committing implementation + tests…')
const allFiles = coderResult.filesChanged.concat(redResult.testFiles).concat(docFiles)
await agent(
  'Create a conventional commit for task ' + TASK_ID + '.\n' +
  'Files to stage: ' + JSON.stringify(allFiles) + '\n\n' +
  'Steps:\n' +
  '1. Run the project lint command (see .claude/context.md for the exact command)\n' +
  '2. Run: git add ' + allFiles.map(function(f) { return '"' + f + '"' }).join(' ') + '\n' +
  '3. Commit using the Conventional Commits format defined in .claude/context.md.\n' +
  'Confirm the commit SHA.',
  { phase: 'Commit', agentType: 'commit' }
)
log('✅ Implementation committed — reviews can now run safely')

// ── Parallel reviews ──────────────────────────────────────────────────────
phase('Review')
const needsUX   = taskInfo.touchesUI   || coderResult.touchesUI
const needsPerf = taskInfo.touchesPrisma || coderResult.touchesPrisma
const reviewTasks = []

if (needsUX) {
  reviewTasks.push(function() {
    return agent(
      'Read .claude/skills/ux-review/SKILL.md and follow it exactly.\n' +
      'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
      'Files changed: ' + JSON.stringify(coderResult.filesChanged) + '\n' +
      'Run the full 7-dimension UX review.\n' +
      'Return label="ux-review", blockers (array of must-fix issues), warnings (array of nice-to-fix issues).',
      { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'ux-review', agentType: 'ux-review' }
    )
  })
}

if (needsPerf) {
  reviewTasks.push(function() {
    return agent(
      'Read .claude/skills/perf-review/SKILL.md and follow it exactly.\n' +
      'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
      'Files changed: ' + JSON.stringify(coderResult.filesChanged) + '\n' +
      'Run the full performance review: N+1 queries, unbounded queries, missing pagination, over-fetching, async patterns.\n' +
      'Return label="perf-review", blockers (array of must-fix issues), warnings (array of nice-to-fix issues).',
      { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'perf-review', agentType: 'perf-review' }
    )
  })
}

reviewTasks.push(function() {
  return agent(
    'Read .claude/skills/qa-tester/SKILL.md and follow it exactly.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n\n' +
    'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
    'Run the full UAT checklist and visual screenshot review.\n' +
    'Return label="qa-tester", blockers (array of must-fix issues), warnings (array of nice-to-fix issues).',
    { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'qa-tester', agentType: 'qa-tester' }
  )
})

reviewTasks.push(function() {
  return agent(
    'Read .claude/skills/security-audit/SKILL.md and follow it exactly.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
    'Files changed: ' + JSON.stringify(coderResult.filesChanged) + '\n' +
    'Run the full OWASP Top 10 + project absolute rules security audit.\n' +
    'Return label="security-audit", blockers (array of must-fix violations), warnings (array of nice-to-fix issues).',
    { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'security-audit', agentType: 'security-audit' }
  )
})

// Dependency/SCA scan — always (OWASP A06; code review cannot catch vulnerable libraries).
reviewTasks.push(function() {
  return agent(
    'Read .claude/skills/dep-audit/SKILL.md and follow it exactly.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
    'Run the dependency/SCA audit using the audit command from .claude/context.md. ' +
    'Treat Critical/High vulnerabilities that have a non-major fix available as blockers; ' +
    'major-bump-only fixes and outdated (non-security) packages are warnings. ' +
    'Do NOT apply major version bumps. If no audit command is configured, return no blockers and one warning saying so.\n' +
    'Return label="dep-audit", blockers (array), warnings (array).',
    { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'dep-audit', agentType: 'dep-audit' }
  )
})

// Measured performance — only when the task is perf-sensitive (UI bundle/Web Vitals, or DB queries).
if (needsPerf || needsUX) {
  reviewTasks.push(function() {
    return agent(
      'Read .claude/skills/perf-measure/SKILL.md and follow it exactly.\n' +
      'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
      'Files changed: ' + JSON.stringify(coderResult.filesChanged) + '\n' +
      'Measure against the budgets in .claude/context.md: bundle size, Core Web Vitals on affected routes, ' +
      'and query EXPLAIN on hot paths. Treat a budget breach as a blocker; near-budget as a warning. ' +
      'If the app cannot be built or run in this environment, return no blockers and one warning explaining why ' +
      '(so a transient/headless limitation never falsely blocks the PR).\n' +
      'Return label="perf-measure", blockers (array), warnings (array).',
      { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'perf-measure', agentType: 'perf-measure' }
    )
  })
}

const reviewResults = await parallel(reviewTasks)
const succeeded = reviewResults.filter(Boolean)
log('Reviews complete — ' + succeeded.length + '/' + reviewTasks.length + ' agents returned results')

const allBlockers = succeeded.flatMap(function(r) { return r.blockers })
const allWarnings = succeeded.flatMap(function(r) { return r.warnings })

if (allWarnings.length > 0) log('⚠️  Warnings: ' + allWarnings.join(' | '))

if (allBlockers.length > 0) {
  log('🚫 ' + allBlockers.length + ' blocker(s) found — pipeline stopped before PR')
  return {
    status: 'blocked',
    reason: 'Review blockers must be resolved before opening a PR',
    taskId: TASK_ID,
    blockers: allBlockers,
    warnings: allWarnings,
  }
}
log('✅ No blockers — proceeding to Ship')

// ── Phase 9: Ship ────────────────────────────────────────────────────────
phase('Ship')
await agent(
  'Read .claude/skills/pr-reviewer/SKILL.md and follow it exactly.\n' +
  'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n\n' +
  'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
  'Verify all DoD criteria are met. Mark the task [x] in docs/ROADMAP.md (update sprint table and global status). ' +
  'Run lint and tests. Open a PR to the integration branch with a clear summary. Return the PR URL.',
  { phase: 'Ship', agentType: 'pr-reviewer' }
)

log('🎉 Task ' + TASK_ID + ' — automated pipeline complete, PR opened. Human UAT + merge are yours.')
return { status: 'done', taskId: TASK_ID, awaiting: 'human UAT + merge on the PR' }

} // end shipOne

// ── Dispatch: single task, or batch over the ready backlog ─────────────────
const INPUT = (typeof args === 'string' ? args : '').trim()
const isBatch = INPUT === '' || /^(open|all|ready)$/i.test(INPUT)
if (!isBatch) return await shipOne(INPUT)

// Batch mode: drain every open, DoR-ready task whose dependencies are already delivered.
phase('Backlog')
log('Batch mode — scanning roadmap for open, DoR-ready tasks…')
const backlog = await agent(
  'Read docs/ROADMAP.md. Return:\n' +
  '- doneIds: IDs of every task already marked [x] / delivered.\n' +
  '- tasks: every task NOT marked [x], each with: id, title, ' +
  'taskType ("Fix"/"Feature"; "Feature" if absent), priority ("P0"/"P1"/"P2" or empty string), ' +
  'dependencies (array of task IDs after "Dependencies:", empty if None/absent), ' +
  'and dorMet (true only if it satisfies the Definition of Ready at the top of the roadmap).',
  { schema: BACKLOG_SCHEMA, phase: 'Backlog' }
)
if (!backlog || !backlog.tasks || backlog.tasks.length === 0) {
  return { status: 'idle', reason: 'No open tasks found in the roadmap.' }
}

const done = new Set(backlog.doneIds || [])
const rankOf = { P0: 0, P1: 1, P2: 2 }
const rank = function(p) { return rankOf[p] != null ? rankOf[p] : 3 }
const depsMet = function(t) { return (t.dependencies || []).every(function(d) { return done.has(d) }) }

// A task shipped in THIS run is NOT a satisfied dependency: its PR is open but unmerged,
// so a dependent built now would lack its code. Dependents wait for the next run (after merge).
const notReady = backlog.tasks.filter(function(t) { return !t.dorMet })
const blockedByDeps = backlog.tasks.filter(function(t) { return t.dorMet && !depsMet(t) })
const ready = backlog.tasks
  .filter(function(t) { return t.dorMet && depsMet(t) })
  .sort(function(a, b) { return rank(a.priority) - rank(b.priority) || String(a.id).localeCompare(String(b.id)) })

log('Backlog: ' + ready.length + ' ready · ' + blockedByDeps.length + ' waiting on dependencies · ' + notReady.length + ' not DoR-ready')
if (notReady.length) log('⏭️  Not DoR-ready (run /planner): ' + notReady.map(function(t) { return t.id }).join(', '))
if (blockedByDeps.length) log('⛓️  Waiting on unmerged dependencies: ' + blockedByDeps.map(function(t) { return t.id }).join(', '))

const results = []
for (const t of ready) {
  log('▶ Shipping ' + t.id + (t.title ? ' — ' + t.title : '') + ' [' + (t.taskType || 'Feature') + ']')
  const r = await shipOne(t.id)
  results.push({ id: t.id, status: (r && r.status) || 'error', detail: r })
}

const shipped = results.filter(function(r) { return r.status === 'done' })
const blocked = results.filter(function(r) { return r.status === 'blocked' })
log('🏁 Batch complete — ' + shipped.length + ' PR(s) opened, ' + blocked.length + ' blocked')
return {
  status: 'batch-complete',
  shipped: shipped.map(function(r) { return r.id }),
  blocked: blocked.map(function(r) { return { id: r.id, detail: r.detail } }),
  skippedNotReady: notReady.map(function(t) { return t.id }),
  skippedDeps: blockedByDeps.map(function(t) { return t.id }),
  awaiting: 'human UAT + merge on each opened PR',
}
```

---

## Human touchpoints

The pipeline returns control to you only when:

| Situation | What to do |
|-----------|------------|
| DoR not met | Fix the missing fields in `docs/ROADMAP.md` via `/planner`, then re-run `/ship-task <ID>` |
| RED gate — no failing test | The RED tests passed before any implementation (vacuous, or reverse-engineered from existing code). Rewrite them from the acceptance criteria so they fail first, then re-run |
| Tests still failing after auto-fix | `/debugger` already tried twice and couldn't make them pass — review the failures, fix manually, then re-run |
| Review blockers | A review (UX/perf/QA/security/dep/perf-measure) found a must-fix issue — resolve it, then re-run |
| PR URL returned | Run **human UAT** against the PR — tick the UAT checklist in the PR body, then merge |

All other steps — branch creation, schema migration, implementation, doc updates, the debugger self-repair loop, and all six parallel reviews — run without prompting.

**In batch mode (`/ship-task open`)** a single task hitting one of these gates does **not** stop the run — that task is recorded (blocked / not-ready / waiting-on-deps) and the orchestrator moves to the next ready task, returning the full summary at the end. Fix the recorded items and re-run `/ship-task open` to pick them up.

---

## Cross-references

- Task not in roadmap yet: `/planner`
- Check roadmap progress: `/roadmap-status`
- Audit a branch manually: `/pr-reviewer` (audit mode)
- Run the pipeline step-by-step: see project CLAUDE.md pipeline table
