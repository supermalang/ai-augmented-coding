#!/usr/bin/env bash
# Backstop: block file writes to gated implementation paths done via the SHELL
# (redirects, tee, sed -i) when there is no active roadmap task. The Edit/Write
# roadmap gate cannot see writes performed through Bash — this closes the common
# bypass (e.g. `echo … > src/x`, `tee src/x`, `sed -i … tests/y`).
#
# PURE BASH — builtins only (no cat/grep/sed/jq), so it can't fail open when those
# tools are missing from PATH.
#
# LIMITS (honest): inspects the command STRING only. A script file that writes paths
# internally (e.g. `python build.py` where build.py writes src/…) is invisible here.
# The real boundary for that is least-privilege agent tools — give builders no raw
# shell write capability so the only write path is Edit/Write.
set -uo pipefail

INPUT=""
while IFS= read -r _line || [ -n "$_line" ]; do INPUT+="$_line"$'\n'; done

block() { printf '{"continue": false, "stopReason": "%s"}\n' "$1"; exit 0; }

CMD=""
if [[ $INPUT =~ \"command\"[[:space:]]*:[[:space:]]*\"(([^\"\\]|\\.)*)\" ]]; then
  CMD="${BASH_REMATCH[1]}"
fi
# Best-effort backstop: nothing parseable → don't block all Bash.
[ -z "$CMD" ] && exit 0

PROFILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/hooks/stack-profile.sh"
[ -f "$PROFILE" ] && . "$PROFILE"

# Loose "contains" form of the gated alternation, e.g. src/|tests/|prisma/schema\.prisma
GATED_REGEX="${STACK_GATED_PATHS_REGEX:-^(src/|tests/|prisma/schema\.prisma)}"
GATED_ALT="${GATED_REGEX#^}"        # drop leading ^
GATED_ALT="${GATED_ALT#(}"          # drop leading (
GATED_ALT="${GATED_ALT%)}"          # drop trailing )

# Match a write whose TARGET is a gated path: a redirect (>/>>) or tee/sed -i
# followed by a (optionally pathed) gated token. Reading a gated file then redirecting
# elsewhere (`cat src/x > /tmp/y`) does NOT match — only writes INTO gated paths.
REDIR_RE="(>>?|[[:space:]]tee([[:space:]]+-a)?)[[:space:]]*[\"']?([^\"' ]*/)?(${GATED_ALT})"
SEDI_RE="sed[[:space:]]+-i[^|;&]*[[:space:]][\"']?([^\"' ]*/)?(${GATED_ALT})"

if [[ $CMD =~ $REDIR_RE || $CMD =~ $SEDI_RE ]]; then
  CURRENT_TASK_FILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.current-task"
  TASK_ID=""
  if [ -f "$CURRENT_TASK_FILE" ]; then
    IFS= read -r TASK_ID < "$CURRENT_TASK_FILE" || true
    TASK_ID="${TASK_ID//[[:space:]]/}"
  fi
  if [ -z "$TASK_ID" ]; then
    block "🚫 ROADMAP GATE (bash): this command writes to a gated implementation path (src/, tests/, schema) with no active task. Writing implementation through the shell bypasses the Edit/Write gate. Run /start-task <ID> first — or make the edit with the Edit/Write tools so the normal gate applies."
  fi
fi

exit 0
