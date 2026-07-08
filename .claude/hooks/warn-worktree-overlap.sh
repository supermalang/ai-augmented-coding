#!/usr/bin/env bash
# warn-worktree-overlap.sh — ADVISORY cross-worktree overlap check.
#
# Wired as PreToolUse(Edit) and PreToolUse(Write). A hook in one worktree cannot see another
# worktree's edits, so this adds *awareness*, not enforcement: before an edit, it lists the sibling
# worktrees (own dir, shared .git) and, if another worktree is touching the SAME file, it prints a
# warning naming that sibling's branch.
#
# WARN ONLY — this hook must NEVER block. It always exits 0 and never emits a deny/stop decision.
# Overlap is sometimes legitimate (a deliberate cross-cutting change), so a block here would cause
# false stops. It is silent when only one worktree exists, and silent on any git/parse failure
# (advisory checks fail open — a missing warning is never worse than a false block).
#
# LIGHTWEIGHT: local git only (worktree list + per-sibling status/diff). No network, no writes.
set -uo pipefail

# Reads file_path from stdin using pure-bash helpers; git is used only for the advisory lookup.
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh" 2>/dev/null || exit 0

hook_read_stdin
file_path="$(hook_field file_path)"
[ -n "$file_path" ] || exit 0   # nothing to compare → stay quiet

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$ROOT" ] || exit 0

# Repo-relative path of the file being edited (same relative form in every worktree).
# Canonicalise BOTH sides so the prefix strips cleanly regardless of slash style (\ vs /), MSYS vs
# Windows drive form (/c/… vs C:/…), or drive-letter case — otherwise a mismatch silently defeats
# the overlap match on Windows.
canon() {
  local p="${1//\\//}"
  [[ $p =~ ^/([A-Za-z])/(.*)$ ]] && p="${BASH_REMATCH[1]}:/${BASH_REMATCH[2]}"
  printf '%s' "$p"
}
fp="$(canon "$file_path")"
root_fwd="$(canon "$ROOT")"
if shopt -s nocasematch; [[ $fp == "$root_fwd"/* ]]; then
  rel="${fp:$(( ${#root_fwd} + 1 ))}"
else
  rel="$fp"
fi
shopt -u nocasematch
rel="${rel#./}"

# Enumerate worktrees. Silent (and cheap) when there is only one.
wt_out="$(git worktree list --porcelain 2>/dev/null)" || exit 0
[ -n "$wt_out" ] || exit 0

# Parse `git worktree list --porcelain` into parallel path/branch arrays.
paths=(); branches=()
cur_path=""; cur_branch=""
flush() {
  [ -n "$cur_path" ] || return 0
  paths+=("$cur_path"); branches+=("$cur_branch")
  cur_path=""; cur_branch=""
}
while IFS= read -r line; do
  case "$line" in
    "worktree "*) flush; cur_path="${line#worktree }" ;;
    "branch "*)   cur_branch="${line#branch refs/heads/}" ;;
    "detached")   cur_branch="(detached)" ;;
    "")           flush ;;
  esac
done <<< "$wt_out"
flush

[ "${#paths[@]}" -gt 1 ] || exit 0   # only this worktree → nothing to warn about

# Does sibling worktree at $1 touch $rel (working-tree/staged changes, or commits on its branch
# not shared with our HEAD)? Every git call is best-effort; failures just mean "no signal".
sibling_touches() {
  local path="$1" branch="$2" hit=""
  # Working-tree + staged changes in the sibling (active editing right now).
  if git -C "$path" status --porcelain=v1 -- "$rel" 2>/dev/null | grep -q .; then
    hit="working tree"
  else
    # Commits on the sibling branch not yet reachable from our HEAD.
    local base
    base="$(git merge-base HEAD "$branch" 2>/dev/null)" || return 1
    if [ -n "$base" ] && git -C "$path" diff --name-only "$base" "$branch" -- "$rel" 2>/dev/null | grep -q .; then
      hit="committed changes"
    fi
  fi
  [ -n "$hit" ] && printf '%s' "$hit"
}

i=0
while [ "$i" -lt "${#paths[@]}" ]; do
  p="${paths[$i]}"; b="${branches[$i]}"
  i=$((i+1))
  [ "$p" = "$ROOT" ] && continue           # skip the current worktree
  [ -n "$b" ] && [ "$b" != "(detached)" ] || continue
  where="$(sibling_touches "$p" "$b")" || continue
  if [ -n "$where" ]; then
    printf '⚠️  WORKTREE OVERLAP (advisory): "%s" is also changed in a sibling worktree on branch `%s` (%s). Parallel worktrees are only safe on DISJOINT file sets — coordinate before editing this file in both. This is a warning, not a block.\n' \
      "$rel" "$b" "$where"
  fi
done

exit 0
