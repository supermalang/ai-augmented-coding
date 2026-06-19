---
name: pr-review
description: Review a PR (or current branch) against the project's conventions — tenant isolation, absolute rules, UI conventions, offline compliance, input validation. Use when the user asks to review code, audit a PR, or sanity-check a branch before opening a PR.
---

# /pr-review — PR Review Checklist

Before starting, read `.claude/context.md` for project-specific rules, constraints, and conventions.

## Permissions

✅ CAN read    : all project files · full git diff
✅ CAN run     : `git diff` · `git log` · lint · tests (read-only validation)
❌ CANNOT      : write to any file
❌ CANNOT      : push, merge, or open PRs (use `/pr-reviewer` for the full pipeline gate)
❌ CANNOT      : fix issues found — report only, let the user or `/coder` apply fixes

> Distinction: `/pr-review` is a read-only audit checklist. `/pr-reviewer` is the full pipeline gate that verifies DoD, updates the roadmap, and opens the PR.

---

[PROJECT CONVENTION — see .claude/context.md for the full tech stack, integration branch name, and test runner]

Triggers: "review this PR", "audit my changes", "sanity-check before pushing", or before opening a PR to the integration branch.

## Survey the diff first

```bash
git status
git diff <integration-branch>...HEAD --stat
git log <integration-branch>..HEAD --oneline
```

## Checklist

Work through each section. Cite [file:line](file#Lline) for every finding.

### 1. Absolute rules — blockers if violated

[PROJECT RULE — see .claude/context.md for the complete list of absolute rules with their exact names and descriptions]

The following are examples of absolute rules a project might define. Replace with the actual rules from `.claude/context.md`:

- [ ] **Soft delete** — no hard-delete ORM calls anywhere in the diff. Deletions must set `deletedAt = new Date()`.
- [ ] **Audit log insert-only** — no UPDATE/DELETE on the audit log table. Only the audit helper inserts.
- [ ] **Tenant/scope filter** — every database query has the scoping field in its filter. No unscoped `findMany` (except explicit admin routes).
- [ ] **No sensitive field exposure** — password hashes or equivalent fields must not appear in any API response body.
- [ ] **Input validation** — every new API route parses the body/params with the validation library before touching the database.

### 2. Auth and session

- [ ] Every API route checks the session/token and returns 401 if missing or invalid.
- [ ] The tenant/scope ID comes from the verified session — never from the request body.
- [ ] No secrets (database URL, auth secret, API keys) in source files.

### 3. API route pattern

Each route should follow the standard shape from `.claude/context.md`:
- Auth check → input validation → scoped database query → audit log on mutations

### 4. UI conventions

[PROJECT CONVENTION — see .claude/context.md for UI language, badge classes, icon library, and icon size standards]

- [ ] All user-visible text is in the required language — no violations in the diff.
- [ ] Status badges use the exact classes defined in `.claude/context.md` — no invented variants.
- [ ] Icons come from the approved icon library only.
- [ ] Icon sizes follow the standards defined in `.claude/context.md`.

### 5. Schema / migrations

- [ ] Schema change ships with a new migration file in the same PR.
- [ ] No edits to an already-applied migration file.
- [ ] ORM client was regenerated after schema changes.
- [ ] Generated documentation files were NOT hand-edited.

### 6. Offline compliance (if applicable)

[PROJECT CONVENTION — see .claude/context.md for offline/queue architecture if present]

- [ ] New write paths that could fail on a flaky network use the offline queue rather than erroring.
- [ ] Queue entries are never trusted for the tenant scope ID — the server always writes from the session.

### 7. Generated docs

- [ ] If the schema or any API route changed: confirm the docs generation command was run and generated files were updated.

### 8. Tests

- [ ] New business logic has a colocated test file.
- [ ] The test suite passes.

## Report format

```
Blockers (must fix before merge):
  - <one-liner> — file:line

Should fix:
  - <one-liner> — file:line

Nits:
  - <one-liner> — file:line

Looked good:
  - <specific thing checked and approved>
```

## Cross-references

- Run the executable checklist: `/pre-pr` command (if configured for this project).
- Absolute rules detail: `domain-rules` skill (if present).
- Schema workflow: `schema-agent` skill.
- API route pattern: `api-route` skill (if present).
