#!/usr/bin/env bash
# Block editing implementation files without an active roadmap task (declared via /start-task).
# Exempt: docs/ROADMAP.md, CLAUDE.md, .claude/ (tooling), root config files (not in gated paths).
#
# PURE BASH — uses only shell builtins (no cat/grep/sed/jq), so it works even when coreutils
# or jq are not on PATH. A guard that depends on external tools fails OPEN when they're missing;
# that is exactly how the gate got bypassed. This one cannot.
# FAIL CLOSED: if the target path can't be parsed, BLOCK rather than silently allow.
set -uo pipefail

# Read all of stdin using only the `read` builtin (no `cat`).
INPUT=""
while IFS= read -r _line || [ -n "$_line" ]; do INPUT+="$_line"$'\n'; done

block() { printf '{"continue": false, "stopReason": "%s"}\n' "$1"; exit 0; }

# Parse tool_input.file_path with bash's own regex engine.
FILE_PATH=""
if [[ $INPUT =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
  FILE_PATH="${BASH_REMATCH[1]}"
fi

# Fail closed: a write tool with no parseable target means we cannot verify safety → block.
if [ -z "$FILE_PATH" ]; then
  block "🚫 ROADMAP GATE: could not read the target file path from the tool input. Blocking to stay safe rather than allow an unverifiable edit."
fi

# Stack-specific patterns live in stack-profile.sh (override there, not here).
PROFILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/hooks/stack-profile.sh"
[ -f "$PROFILE" ] && . "$PROFILE"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Normalise: strip an absolute project-dir prefix and any leading ./ ; tolerate \ or / separators.
RELATIVE="${FILE_PATH#"$PROJECT_DIR"/}"
RELATIVE="${RELATIVE#./}"
RELATIVE="${RELATIVE//\\//}"

GATED_REGEX="${STACK_GATED_PATHS_REGEX:-^(src/|tests/|prisma/schema\.prisma)}"

# Only gate implementation files.
if [[ ! $RELATIVE =~ $GATED_REGEX ]]; then
  exit 0
fi

CURRENT_TASK_FILE="$PROJECT_DIR/.current-task"
[ -f "$CURRENT_TASK_FILE" ] || block "🚫 ROADMAP GATE: No active task declared. Run /start-task <TASK-ID> before editing ${RELATIVE}. The task must exist in docs/ROADMAP.md and satisfy the Definition of Ready."

TASK_ID=""
IFS= read -r TASK_ID < "$CURRENT_TASK_FILE" || true
TASK_ID="${TASK_ID//[[:space:]]/}"
[ -n "$TASK_ID" ] || block "🚫 ROADMAP GATE: .current-task is empty. Run /start-task <TASK-ID> to set the active task."

ROADMAP="$PROJECT_DIR/docs/ROADMAP.md"
ROADMAP_CONTENT=""
[ -f "$ROADMAP" ] && ROADMAP_CONTENT="$(<"$ROADMAP")"
if [[ $ROADMAP_CONTENT != *"$TASK_ID"* ]]; then
  block "🚫 ROADMAP GATE: Task '${TASK_ID}' (from .current-task) not found in docs/ROADMAP.md. Write it first (Type: Fix for a bug), then re-run /start-task ${TASK_ID}."
fi

exit 0
