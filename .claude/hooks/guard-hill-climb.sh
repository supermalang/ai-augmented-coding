#!/usr/bin/env bash
# guard-hill-climb.sh — make the self-improvement (hill-climbing) agent PROPOSE-ONLY, structurally.
#
# The hill-climb agent analyses run traces and proposes harness improvements — but it must NEVER edit
# the harness itself (skills / agents / hooks / prompts / config) or merge. This guard enforces that
# as a structural impossibility, not just policy (belt-and-braces, like guard-visual-update):
#
#   WHEN ACTIVE (the run is a hill-climb run — detected by a `hill-climb/*` branch OR a
#   `.hill-climb-active` marker at the worktree root), the ONLY writes allowed are the proposal itself
#   (`docs/improvements/**`) and throwaway scratch (`.scratch/**`). Every other Edit/Write/shell-write
#   is DENIED — so it cannot touch .claude/skills, .claude/agents, .claude/hooks, settings, context,
#   CLAUDE.md, or any prompt. Its only output path is a proposal doc + a PR.
#
# When NOT a hill-climb run, this guard is inert (exits 0) — normal work is unaffected.
#
# PURE BASH (builtins only via _hooklib) — can't fail open on a missing tool. FAIL CLOSED: on a
# hill-climb run with an unparseable target, DENY rather than allow an unverifiable harness edit.
#
# HONEST LIMIT: like every command-string guard, a write performed inside a script file it invokes is
# invisible here; and branch/marker detection is the activation signal (see guard-visual-update's note).
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_read_stdin

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# ── Activation: is this a hill-climb run? ─────────────────────────────────────
branch="$(hook_git_branch)"
active=0
case "$branch" in hill-climb/*) active=1 ;; esac
[ -f "$ROOT/.hill-climb-active" ] && active=1
[ "$active" -eq 1 ] || exit 0   # not a hill-climb run → inert

# An allowed write target: the proposal output or scratch. Everything else is denied.
is_allowed() {
  local rel="$1"
  case "$rel" in
    docs/improvements/*|.scratch/*) return 0 ;;
    *) return 1 ;;
  esac
}

DENY_MSG="🚫 HILL-CLIMB GATE: the self-improvement agent is PROPOSE-ONLY. It may write only its proposal (docs/improvements/**) and open a PR — it can never edit skills/agents/hooks/prompts/config or merge. Put the suggested change in the proposal doc with its evidence; a human applies it through the normal PR gate."

# Which tool is this? (top-level tool_name in the PreToolUse payload.)
tool_name=""
if [[ $HOOK_INPUT =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
  tool_name="${BASH_REMATCH[1]}"
fi

# ── Edit / Write path — default-deny; only the proposal + scratch may be written ─
if [ "$tool_name" = "Edit" ] || [ "$tool_name" = "Write" ]; then
  file_path="$(hook_field file_path)"
  # FAIL CLOSED: an Edit/Write with no parseable target on a hill-climb run → deny.
  [ -n "$file_path" ] || hook_deny "$DENY_MSG (unverifiable write target)"
  rel="${file_path#"$ROOT"/}"; rel="${rel#./}"; rel="${rel//\\//}"
  is_allowed "$rel" && exit 0
  hook_deny "$DENY_MSG (blocked write: ${rel})"
fi

# ── Bash path — block shell writes into non-allowed paths; leave git/gh/read alone ─
if [ "$tool_name" = "Bash" ]; then
  cmd="$(hook_field command)"
  [ -n "$cmd" ] || exit 0   # nothing parseable → don't block all Bash (matches guard-bash-write)
  # A redirect (> / >>) or tee/sed -i whose target is NOT under an allowed dir → deny.
  WRITE_RE='(>>?|[[:space:]]tee([[:space:]]+-a)?|sed[[:space:]]+-i)[[:space:]]*["'"'"']?([^"'"'"' ]+)'
  if [[ $cmd =~ $WRITE_RE ]]; then
    target="${BASH_REMATCH[3]}"
    target="${target#"$ROOT"/}"; target="${target#./}"; target="${target//\\//}"
    is_allowed "$target" || hook_deny "$DENY_MSG (blocked shell write: ${target})"
  fi
  exit 0
fi

exit 0
