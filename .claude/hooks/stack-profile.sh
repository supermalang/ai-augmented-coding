#!/usr/bin/env bash
# stack-profile.sh — single source of truth for all stack-specific patterns the hooks use.
#
# The pipeline's orchestration (skills, gates, TDD loop, reviews) is language-agnostic.
# The only stack-bound pieces are the regex/glob patterns and commands the guard hooks
# match against. They all live HERE so adopting the pipeline for another stack means
# editing this one file — never the hook scripts themselves.
#
# Each hook sources this file and reads its values via `${VAR:-default}`, so:
#   - if this file is missing, hooks fall back to the built-in default (current stack);
#   - to retarget a stack, override the variables below.
#
# ─────────────────────────────────────────────────────────────────────────────
# DEFAULT PROFILE: React / Next.js (App Router) · Prisma · TypeScript · Vitest
# ─────────────────────────────────────────────────────────────────────────────

# Test/spec files — excluded from content scanners; flagged by guard-test-files.
# (ts/tsx/js/jsx with a .test. or .spec. infix.)
export STACK_TEST_FILE_REGEX='\.(test|spec)\.(ts|tsx|js|jsx)$'

# Implementation paths gated behind /start-task (guard-roadmap-gate).
export STACK_GATED_PATHS_REGEX='^(src/|tests/|prisma/schema\.prisma)'

# Auto-generated files that must never be hand-edited (guard-generated-files).
export STACK_GENERATED_FILES_GLOB='*.generated.md'

# Hard-delete call that violates the soft-delete rule (guard-soft-delete).
# Prisma: `prisma.<model>.delete(`.
export STACK_SOFT_DELETE_PATTERN='prisma\.[a-zA-Z]+\.delete\('

# Destructive DB command that wipes data (guard-destructive-db).
export STACK_DESTRUCTIVE_DB_PATTERN='npm run db:reset|prisma migrate reset'

# Audit-log mutation — ORM call and raw SQL (guard-audit-log).
export STACK_AUDIT_LOG_ORM_PATTERN='prisma\.auditLog\.(update|delete|updateMany|deleteMany)\('
export STACK_AUDIT_LOG_SQL_PATTERN='(UPDATE|DELETE)[[:space:]]+.*audit_logs'

# Sensitive field names that must never appear in an API response (guard-expose-hash).
export STACK_SENSITIVE_FIELDS='passwordHash|hashedPassword|apiSecret|refreshToken|privateKey'

# Sources that feed generated docs, and the command to regenerate (remind-docs-generate).
export STACK_DOCS_SOURCE_REGEX='^(prisma/schema\.prisma$|src/app/api/)'
export STACK_DOCS_GENERATE_CMD='npm run docs:generate'

# New migration files, and the rebuild command (remind-docker-rebuild).
export STACK_MIGRATIONS_REGEX='^prisma/migrations/'
export STACK_DOCKER_REBUILD_CMD='docker compose up -d --build app'

# ─────────────────────────────────────────────────────────────────────────────
# ADAPTING TO ANOTHER STACK
# ─────────────────────────────────────────────────────────────────────────────
# Override the variables above for your stack. Examples:
#
# Laravel (PHP · Eloquent · PHPUnit):
#   STACK_TEST_FILE_REGEX='Test\.php$'
#   STACK_GATED_PATHS_REGEX='^(app/|tests/|database/migrations/)'
#   STACK_SOFT_DELETE_PATTERN='::forceDelete\(|->forceDelete\('   # Eloquent SoftDeletes: ->delete() is already soft
#   STACK_DESTRUCTIVE_DB_PATTERN='php artisan migrate:fresh|migrate:reset|db:wipe'
#   STACK_AUDIT_LOG_ORM_PATTERN='AuditLog::(where|find).*->(update|delete)\('
#   STACK_MIGRATIONS_REGEX='^database/migrations/'
#
# Django (Python · Django ORM · pytest):
#   STACK_TEST_FILE_REGEX='(^|/)test_.*\.py$|_test\.py$'
#   STACK_GATED_PATHS_REGEX='^(apps?/|tests/|.*/migrations/)'
#   STACK_SOFT_DELETE_PATTERN='\.delete\('                        # if not using a soft-delete mixin
#   STACK_DESTRUCTIVE_DB_PATTERN='manage\.py (flush|reset_db|sqlflush)'
#   STACK_MIGRATIONS_REGEX='/migrations/'
#   STACK_DOCS_GENERATE_CMD='python manage.py spectacular --file schema.yml'
#
# FastAPI (Python · SQLAlchemy/Alembic · pytest):
#   STACK_TEST_FILE_REGEX='(^|/)test_.*\.py$|_test\.py$'
#   STACK_GATED_PATHS_REGEX='^(app/|tests/|alembic/versions/)'
#   STACK_DESTRUCTIVE_DB_PATTERN='alembic downgrade base|drop_all'
#   STACK_MIGRATIONS_REGEX='^alembic/versions/'
#
# Leave any variable unset to keep the default. Only override what differs.
