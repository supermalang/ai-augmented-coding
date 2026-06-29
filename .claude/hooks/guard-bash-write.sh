#!/usr/bin/env bash
# Backstop: block file writes to gated implementation paths done via the SHELL
# (redirects, tee, sed -i) when there is no active roadmap task. The Edit/Write
# roadmap gate cannot see writes performed through Bash — this closes the common
# bypass (e.g. `echo … > src/x`, `tee src/x`, `sed -i … tests/y`).
#
# PURE BASH (builtins only via _hooklib.sh) — can't fail open when jq/coreutils are missing.
#
# LIMITS (honest): inspects the command STRING only. A script file that writes paths
# internally (e.g. `python build.py` where build.py writes src/…) is invisible here.
# The real boundary for that is least-privilege agent tools + the "Edit/Write only for
# source" rule in CLAUDE.md — not this hook.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_load_profile
hook_read_stdin
cmd="$(hook_field command)"
[ -z "$cmd" ] && exit 0   # best-effort backstop: nothing parseable → don't block all Bash

GATED_REGEX="${STACK_GATED_PATHS_REGEX:-^(src/|tests/|prisma/schema\.prisma)}"
GATED_ALT="${GATED_REGEX#^}"; GATED_ALT="${GATED_ALT#(}"; GATED_ALT="${GATED_ALT%)}"

# Write whose TARGET is a gated path: a redirect (>/>>) or tee/sed -i followed by a
# (optionally pathed) gated token. `cat src/x > /tmp/y` does NOT match — only writes INTO gated paths.
REDIR_RE="(>>?|[[:space:]]tee([[:space:]]+-a)?)[[:space:]]*[\"']?([^\"' ]*/)?(${GATED_ALT})"
SEDI_RE="sed[[:space:]]+-i[^|;&]*[[:space:]][\"']?([^\"' ]*/)?(${GATED_ALT})"

if [[ $cmd =~ $REDIR_RE || $cmd =~ $SEDI_RE ]]; then
  CURRENT_TASK_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.current-task"
  TASK_ID=""
  if [ -f "$CURRENT_TASK_FILE" ]; then
    IFS= read -r TASK_ID < "$CURRENT_TASK_FILE" || true
    TASK_ID="${TASK_ID//[[:space:]]/}"
  fi
  if [ -z "$TASK_ID" ]; then
    hook_block "🚫 ROADMAP GATE (bash): this command writes to a gated implementation path (src/, tests/, schema) with no active task. Writing implementation through the shell bypasses the Edit/Write gate. Run /start-task <ID> first — or make the edit with the Edit/Write tools so the normal gate applies."
  fi
fi

exit 0
