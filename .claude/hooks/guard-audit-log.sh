#!/usr/bin/env bash
# guard-audit-log.sh — warn when immutable audit log rows are mutated.
#
# Wired as PostToolUse(Edit) and PostToolUse(Write) in settings.json.
#
# EXAMPLE: this hook is an example for projects with immutable audit logs.
# Audit log tables are insert-only by design (required by ISO 22000 §7.5.3,
# SOC 2, GDPR, and similar standards). Once a log entry is written it must
# never be updated or deleted — doing so destroys the integrity of the audit
# trail and may constitute a compliance violation.
#
# To adapt this hook to your project:
#   1. Replace the grep patterns below with your ORM model name / table name
#      for the audit log (e.g. `AuditLog`, `EventLog`, `activity_logs`, etc.).
#   2. Add any additional mutation methods your ORM exposes (updateOne, bulkDelete…).
#   3. Add raw-SQL patterns that target your audit table name.
#
# Test files (*.test.ts, *.spec.ts) are excluded.

set -uo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

case "$file_path" in
  *.test.ts | *.spec.ts) exit 0 ;;
esac

content=$(printf '%s' "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')

# EXAMPLE: replace `auditLog` with your ORM model name for the audit log table.
if printf '%s' "$content" | grep -Eq 'prisma\.auditLog\.(update|delete|updateMany|deleteMany)\('; then
  printf '⚠️  AUDIT LOG RULE: mutation of the audit log model detected in "%s". The audit log table is INSERT-ONLY — update and delete are forbidden. Write a new corrective entry instead.\n' "$file_path"
fi

# EXAMPLE: replace `audit_logs` with your audit table name.
if printf '%s' "$content" | grep -Eiq '(UPDATE|DELETE)[[:space:]]+.*audit_logs'; then
  printf '⚠️  AUDIT LOG RULE: raw SQL UPDATE/DELETE on the audit_logs table detected in "%s". Table is insert-only — mutation forbidden.\n' "$file_path"
fi

exit 0
