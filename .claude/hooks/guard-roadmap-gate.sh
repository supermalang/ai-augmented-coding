#!/usr/bin/env bash
# Block editing implementation files without an active roadmap task (declared via /start-task).
# Exempt: docs/ROADMAP.md, CLAUDE.md, .claude/ (tooling), root config files (not in gated paths).
#
# PURE BASH (builtins only via _hooklib.sh — no cat/grep/sed/jq), so it works regardless of PATH.
# FAIL CLOSED: if the target path can't be parsed, BLOCK rather than silently allow.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_load_profile
hook_read_stdin
file_path="$(hook_field file_path)"

# Fail closed: a write tool with no parseable target → we cannot verify safety → block.
if [ -z "$file_path" ]; then
  hook_block "🚫 ROADMAP GATE: could not read the target file path from the tool input. Blocking to stay safe rather than allow an unverifiable edit."
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
rel="${file_path#"$PROJECT_DIR"/}"
rel="${rel#./}"
rel="${rel//\\//}"

GATED_REGEX="${STACK_GATED_PATHS_REGEX:-^(src/|tests/|prisma/schema\.prisma)}"
[[ $rel =~ $GATED_REGEX ]] || exit 0   # not a gated implementation path → allow

CURRENT_TASK_FILE="$PROJECT_DIR/.current-task"
[ -f "$CURRENT_TASK_FILE" ] || hook_block "🚫 ROADMAP GATE: No active task declared. Run /start-task <TASK-ID> before editing ${rel}. The task must exist in docs/ROADMAP.md and satisfy the Definition of Ready."

TASK_ID=""
IFS= read -r TASK_ID < "$CURRENT_TASK_FILE" || true
TASK_ID="${TASK_ID//[[:space:]]/}"
[ -n "$TASK_ID" ] || hook_block "🚫 ROADMAP GATE: .current-task is empty. Run /start-task <TASK-ID> to set the active task."

ROADMAP="$PROJECT_DIR/docs/ROADMAP.md"
ROADMAP_CONTENT=""
[ -f "$ROADMAP" ] && ROADMAP_CONTENT="$(<"$ROADMAP")"
if [[ $ROADMAP_CONTENT != *"$TASK_ID"* ]]; then
  hook_block "🚫 ROADMAP GATE: Task '${TASK_ID}' (from .current-task) not found in docs/ROADMAP.md. Write it first (Type: Fix for a bug), then re-run /start-task ${TASK_ID}."
fi

exit 0
