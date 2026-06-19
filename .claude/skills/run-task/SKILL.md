---
name: run-task
description: Autonomous end-to-end pipeline for a roadmap task. Validates DoR, creates branch, runs schema/coder/test-writer/reviews/PR agents in the correct order with automatic skip logic. Human touchpoints only on DoR failure, test failure, and final PR URL. Usage: /run-task <TASK-ID> (e.g. /run-task 10.3).
---

# run-task — Autonomous Task Pipeline

Before starting, read `.claude/context.md` for project-specific rules, constraints, and conventions.

## Permissions

✅ CAN read    : all project files
✅ CAN run     : Workflow tool — invoking `/run-task` is explicit multi-agent opt-in
✅ CAN delegate: all pipeline agent skills (schema-agent, coder, test-writer, ux-review, perf-review, qa-tester, security-review, pr-reviewer)
❌ CANNOT      : implement code directly — delegates to `/coder`
❌ CANNOT      : merge PRs — returns PR URL for human review
❌ CANNOT      : mark task [x] without all DoD criteria met

---

## How to use

```
/run-task 10.3
```

The task ID must match an entry in `docs/ROADMAP.md`. If the task does not exist, stop and tell the user to run `/planner` first.

---

## Pipeline overview

| Step | Agent | Runs when |
|------|-------|-----------|
| 0 | Validate | Always — reads roadmap, checks DoR; **stops if not met** |
| 1 | Setup | Always — writes `.current-task`, creates feature branch |
| 2 | Schema | `impactSchema = "Migration"` only |
| 3 | Test Writer (RED) | Always — writes tests from criteria, confirms they **fail** |
| 4 | Coder | Always — implements until RED tests turn green |
| 5 | Test Writer (GREEN) | Always — re-runs same tests; **stops if still failing** |
| 6 | Commit | Always — lint + commit implementation + tests; recovery checkpoint |
| 7 | UX Review | Task touches UI components or pages [PROJECT CONVENTION — see .claude/context.md] |
| 8 | Perf Review | Task touches database queries or async data fetching |
| 9 | QA Tester | Always — parallel with security review |
| 10 | Security Review | Always — parallel with QA tester |
| — | Blocker gate | Always — **stops if any review returns blockers** |
| 11 | PR Reviewer | Always — verifies DoD, marks roadmap [x], opens PR |

---

## Invoking the Workflow

When this skill is invoked with `/run-task <TASK-ID>`, call the Workflow tool immediately with `args` set to the task ID string (e.g. `"10.3"`) and the script below. Do not ask for confirmation — the user invoking `/run-task` is an explicit opt-in for multi-agent orchestration.

```js
export const meta = {
  name: 'run-task',
  description: 'Autonomous end-to-end pipeline for a roadmap task',
  phases: [
    { title: 'Validate' },
    { title: 'Setup' },
    { title: 'Schema' },
    { title: 'Implement' },
    { title: 'Commit' },
    { title: 'Review' },
    { title: 'Ship' },
  ],
}

const TASK_ID = args
if (!TASK_ID) return { status: 'error', reason: 'No task ID provided. Usage: /run-task <ID>' }

const TASK_INFO_SCHEMA = {
  type: 'object',
  required: ['taskBlock', 'taskTitle', 'impactSchema', 'touchesUI', 'touchesPrisma', 'dorMet', 'dorMissing'],
  properties: {
    taskBlock:     { type: 'string' },
    taskTitle:     { type: 'string' },
    impactSchema:  { type: 'string', enum: ['Migration', 'None', 'To confirm'] },
    touchesUI:     { type: 'boolean' },
    touchesPrisma: { type: 'boolean' },
    dorMet:        { type: 'boolean' },
    dorMissing:    { type: 'array', items: { type: 'string' } },
  },
}

const CODER_RESULT_SCHEMA = {
  type: 'object',
  required: ['filesChanged', 'touchesUI', 'touchesPrisma'],
  properties: {
    filesChanged:  { type: 'array', items: { type: 'string' } },
    touchesUI:     { type: 'boolean' },
    touchesPrisma: { type: 'boolean' },
    summary:       { type: 'string' },
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

const REVIEW_RESULT_SCHEMA = {
  type: 'object',
  required: ['label', 'blockers', 'warnings'],
  properties: {
    label:    { type: 'string' },
    blockers: { type: 'array', items: { type: 'string' }, description: 'Must be fixed before merge' },
    warnings: { type: 'array', items: { type: 'string' }, description: 'Worth fixing, not blocking' },
  },
}

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
    { phase: 'Schema' }
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
  { schema: TEST_RED_SCHEMA, phase: 'Implement', label: 'test-writer (RED)' }
)

if (!redResult) return { status: 'error', reason: 'Test-writer (RED) agent failed for task ' + TASK_ID }
if (redResult.warning) log('⚠️  ' + redResult.warning)
log('🔴 RED phase: ' + redResult.testCount + ' tests written, ' + redResult.failCount + ' failing (expected)')

// ── Phase 4: Implement ────────────────────────────────────────────────────
log('Running coder…')
const coderResult = await agent(
  'Read .claude/skills/coder/SKILL.md and follow it exactly.\n' +
  'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
  'Tests already written (RED phase): ' + JSON.stringify(redResult.testFiles) + '\n\n' +
  'Full task block:\n' + taskInfo.taskBlock + '\n\n' +
  'Implement the complete task. The test files listed above already exist and are failing — ' +
  'your goal is to make them pass. Do NOT modify the test files.\n' +
  'When done, report: which files you changed (array of paths), ' +
  'whether you touched UI source files (touchesUI bool), ' +
  'whether you touched database queries (touchesPrisma bool), ' +
  'and a one-sentence summary of what was implemented.',
  { schema: CODER_RESULT_SCHEMA, phase: 'Implement', label: 'coder' }
)

if (!coderResult) return { status: 'error', reason: 'Coder agent failed for task ' + TASK_ID }

// ── Phase 5: Tests — GREEN ────────────────────────────────────────────────
log('Running test-writer (GREEN phase)…')
const greenResult = await agent(
  'Read .claude/skills/test-writer/SKILL.md and follow it exactly.\n' +
  'MODE: GREEN — the implementation is now complete. Run the existing tests without modifying them.\n' +
  'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
  'Test files to run: ' + JSON.stringify(redResult.testFiles) + '\n\n' +
  'Instructions:\n' +
  '1. Do NOT modify any test file\n' +
  '2. Run the full unit test suite\n' +
  '3. All tests SHOULD pass now\n' +
  '4. If any fail, escalate to coder — report the exact failure messages\n' +
  'Report: testsPassed (bool), failures (array of failing test names or messages).',
  { schema: TEST_GREEN_SCHEMA, phase: 'Implement', label: 'test-writer (GREEN)' }
)

if (!greenResult || !greenResult.testsPassed) {
  const failures = greenResult ? greenResult.failures : ['agent failed']
  log('🚫 Tests failing after implementation: ' + failures.join(', '))
  return { status: 'blocked', reason: 'Tests not passing after implementation — fix the code then re-run', taskId: TASK_ID, failures: failures }
}
log('✅ GREEN phase: all tests passing')

// ── Commit: checkpoint before reviews ────────────────────────────────────
phase('Commit')
log('Committing implementation + tests…')
const allFiles = coderResult.filesChanged.concat(redResult.testFiles)
await agent(
  'Create a conventional commit for task ' + TASK_ID + '.\n' +
  'Files to stage: ' + JSON.stringify(allFiles) + '\n\n' +
  'Steps:\n' +
  '1. Run the project lint command (see .claude/context.md for the exact command)\n' +
  '2. Run: git add ' + allFiles.map(function(f) { return '"' + f + '"' }).join(' ') + '\n' +
  '3. Commit using the Conventional Commits format defined in .claude/context.md.\n' +
  'Confirm the commit SHA.',
  { phase: 'Commit' }
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
      { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'ux-review' }
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
      { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'perf-review' }
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
    { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'qa-tester' }
  )
})

reviewTasks.push(function() {
  return agent(
    'Read .claude/skills/security-review/SKILL.md and follow it exactly.\n' +
    'Active task: ' + TASK_ID + ' — ' + taskInfo.taskTitle + '\n' +
    'Files changed: ' + JSON.stringify(coderResult.filesChanged) + '\n' +
    'Run the full OWASP Top 10 + project absolute rules security audit.\n' +
    'Return label="security-review", blockers (array of must-fix violations), warnings (array of nice-to-fix issues).',
    { schema: REVIEW_RESULT_SCHEMA, phase: 'Review', label: 'security-review' }
  )
})

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
  { phase: 'Ship' }
)

log('🎉 Task ' + TASK_ID + ' complete — PR opened')
return { status: 'done', taskId: TASK_ID }
```

---

## Human touchpoints

The pipeline returns control to you only when:

| Situation | What to do |
|-----------|------------|
| DoR not met | Fix the missing fields in `docs/ROADMAP.md` via `/planner`, then re-run `/run-task <ID>` |
| Tests failing | The coder's implementation has a bug — review the failures, fix the code, then re-run |
| PR URL returned | Review the PR and merge when ready |

All other steps — branch creation, schema migration, implementation, all reviews — run without prompting.

---

## Cross-references

- Task not in roadmap yet: `/planner`
- Check roadmap progress: `/parity-gaps`
- Audit a branch manually: `/pr-review`
- Run the pipeline step-by-step: see project CLAUDE.md pipeline table
