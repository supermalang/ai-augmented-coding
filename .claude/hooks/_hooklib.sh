#!/usr/bin/env bash
# Shared PURE-BASH helpers for the guard hooks. Uses ONLY shell builtins —
# no cat/grep/sed/jq/git — so a guard can never fail OPEN because a tool is
# missing from PATH or the shebang got CRLF-mangled. Source this from a hook:
#   . "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

# Read all of stdin into HOOK_INPUT using only the `read` builtin (no `cat`).
hook_read_stdin() {
  HOOK_INPUT=""
  local _l
  while IFS= read -r _l || [ -n "$_l" ]; do HOOK_INPUT+="$_l"$'\n'; done
}

# hook_field <name> → prints tool_input.<name> string value (first match),
# JSON-UNESCAPED so downstream regexes see real quotes/backslashes/newlines.
# Captures escaped chars first so a command containing \" is not truncated.
hook_field() {
  local key="$1" v=""
  if [[ $HOOK_INPUT =~ \"$key\"[[:space:]]*:[[:space:]]*\"(([^\"\\]|\\.)*)\" ]]; then
    v="${BASH_REMATCH[1]}"
    v=${v//\\\\/$'\x01'}   # protect literal backslashes
    v=${v//\\\"/\"}
    v=${v//\\\//\/}
    v=${v//\\n/$'\n'}
    v=${v//\\t/$'\t'}
    v=${v//$'\x01'/\\}     # restore literal backslashes
    printf '%s' "$v"
  fi
}

# JSON-escape a string for embedding in a hook decision.
hook_json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

# Deny the tool call (PreToolUse) but let the session continue.
hook_deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$(hook_json_escape "$1")"
  exit 0
}

# Hard-stop with a reason (used by the roadmap/branch gates).
hook_block() {
  printf '{"continue": false, "stopReason": "%s"}\n' "$(hook_json_escape "$1")"
  exit 0
}

# Current git branch read straight from .git/HEAD — no `git` binary needed.
# Prints "" for a detached HEAD or when HEAD can't be read.
hook_git_branch() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}" head=""
  [ -f "$dir/.git/HEAD" ] || return 0
  head="$(<"$dir/.git/HEAD")"
  if [[ $head == ref:\ refs/heads/* ]]; then
    printf '%s' "${head#ref: refs/heads/}"
  fi
}

# Source the stack profile if present (for STACK_* pattern overrides).
hook_load_profile() {
  local p="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/stack-profile.sh"
  [ -f "$p" ] && . "$p"
  return 0
}
