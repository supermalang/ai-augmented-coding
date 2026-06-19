# claude-pipeline-template

A reusable Claude Code multi-agent development pipeline. Drop it into any project to get:

- **Autonomous task execution** — `/ship-task <ID>` chains all agents from planning to PR with no human input between steps
- **TDD by default** — tests are written from acceptance criteria *before* the coder touches a file
- **Structured review gates** — security, UX, performance, and QA reviews run in parallel; any blocker stops the pipeline before the PR opens
- **Shell-enforced guards** — hooks block edits without an active task, commits to protected branches, and destructive DB operations
- **Coverage enforcement** — Vitest thresholds fail CI if coverage drops

---

## Setup (5 minutes)

### 1. Copy the template into your project

```bash
# Option A — use as a GitHub/GitLab template repository (recommended)
# Click "Use this template" in the UI, clone your new repo.

# Option B — copy files into an existing project
git clone https://[your-gitlab]/claude-pipeline-template temp-template
cp -r temp-template/.claude your-project/
cp -r temp-template/.github your-project/
cp temp-template/CLAUDE.md your-project/
cp temp-template/docs/ROADMAP.md your-project/docs/  # if docs/ exists
cp temp-template/.gitignore your-project/  # merge, don't overwrite
rm -rf temp-template
```

### 2. Fill in `.claude/context.md`

This is the only file that changes per project. Every pipeline agent reads it at the start of each task. Fill in:

- Project name and description
- Tech stack and key commands
- Absolute rules (non-negotiable constraints)
- Data isolation key (e.g. `tenantId`, `orgId`)
- Roles and access levels
- UI language and component conventions

### 3. Fill in `CLAUDE.md`

Update the sections marked `[CONFIGURE]`:
- Project description
- Tech stack
- Commands
- Architecture overview
- Absolute rules (same as `context.md` — keep in sync)

### 4. Adapt the hooks

Review `.claude/hooks/` and adapt these three to your project's conventions:
- `guard-soft-delete.sh` — change the grep pattern to match your ORM's delete method
- `guard-audit-log.sh` — change the table/model name to your audit log
- `guard-expose-hash.sh` — change the field names to your sensitive fields

All other hooks work as-is.

### 5. Adapt the CI workflow

Edit `.github/workflows/ci.yml`:
- Remove the `Generate ORM types` step if you don't use Prisma
- Update env vars in the `Build` step
- Adjust the `test:coverage` script name if different in your `package.json`

### 6. Initialise your roadmap

Edit `docs/ROADMAP.md`:
- Set the date
- Add your domain names to the Global status table
- Plan your first sprint

---

## Usage

### Start a task autonomously

```
/ship-task 1.1
```

The pipeline will:
1. Validate DoR (stops here if any field is missing)
2. Create a feature branch and set `.current-task`
3. Run migrations if needed
4. Write tests (RED — must fail)
5. Implement (until tests turn green)
6. Update docs if the API, schema, or UI changed
7. Commit the implementation
8. Run UX, perf, QA, and security reviews in parallel
9. Stop if any review returns blockers
10. Open a PR

Human touchpoints: DoR failure → fix the roadmap. Test failure → fix the code. PR URL → merge when ready.

### Plan a new task

```
/planner
```

Or just describe what you want — if no matching task exists in the roadmap, `/planner` is invoked automatically.

### Check roadmap progress

```
/roadmap-status
```

### Start a sprint

```
/sprint-start
```

Audits all planned tasks for DoR before the sprint begins.

---

## Pipeline overview

| Step | Agent | Runs when |
|------|-------|-----------|
| 0 | Validate | Always — DoR check |
| 1 | Setup | Always — branch + `.current-task` |
| 2 | Schema | `impactSchema = Migration` |
| 3 | Test Writer (RED) | Always — writes tests, confirms they fail |
| 4 | Coder | Always — implements to make tests pass |
| 5 | Test Writer (GREEN) | Always — confirms all tests pass |
| 6 | Commit | Always — lint + commit before reviews |
| 7 | UX Review | Task touches UI |
| 8 | Perf Review | Task touches ORM queries or API routes |
| 9 | QA Tester | Always |
| 10 | Security Review | Always |
| — | Blocker gate | Stops pipeline if any review returns blockers |
| 11 | PR Reviewer | Always — marks roadmap done, opens PR |

---

## File structure

```
.claude/
  context.md          ← fill this in per project (read by all agents)
  settings.json       ← hook configuration
  hooks/              ← shell gates (12 hooks)
  skills/             ← 19 agent skills
    discovery/        ← requirements/PRD/HCD kickoff
    ship-task/        ← autonomous orchestrator
    planner/          ← roadmap task creation
    start-task/       ← DoR validation + branch
    coder/            ← implementation
    test-writer/      ← TDD (RED + GREEN modes)
    schema-agent/     ← migrations
    ux-review/        ← UI review
    perf-review/      ← query performance
    qa-tester/        ← UAT + screenshots
    security-audit/   ← OWASP + absolute rules
    refactor/         ← behaviour-preserving cleanup
    debugger/         ← reproduce + root-cause + fix
    docs/             ← README/API/CHANGELOG updates
    webapp-testing/   ← live browser verification (throwaway)
    pr-reviewer/      ← DoD + PR opening (+ audit mode)
    sprint-start/     ← sprint DoR audit
    commit/           ← conventional commits
    roadmap-status/   ← roadmap progress
.github/
  workflows/
    ci.yml            ← lint + test:coverage + build on every PR
docs/
  ROADMAP.md          ← DoR / DoD / task template + sprint planning
CLAUDE.md             ← project instructions for Claude Code
.gitignore            ← includes .current-task
```

---

## What to customise per project

| File | What to change |
|------|---------------|
| `.claude/context.md` | Everything — this is the per-project configuration |
| `CLAUDE.md` | `[CONFIGURE]` sections — stack, commands, architecture |
| `.claude/hooks/guard-soft-delete.sh` | ORM delete method pattern |
| `.claude/hooks/guard-audit-log.sh` | Audit table/model name |
| `.claude/hooks/guard-expose-hash.sh` | Sensitive field names |
| `.github/workflows/ci.yml` | ORM generate command, env vars, build command |
| `docs/ROADMAP.md` | Domain names in the global status table |

Everything else works as-is.
