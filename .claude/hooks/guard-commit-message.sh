#!/usr/bin/env bash
# guard-commit-message.sh — warn when git commit -m doesn't follow Conventional Commits.
# PURE BASH (builtins only) — no jq/grep/sed. Advisory (prints a warning), does not deny.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_read_stdin
cmd="$(hook_field command)"

# Fast path: only git commit commands that use -m.
[[ $cmd == *git*commit*-m* ]] || exit 0

# Extract the message after -m (handles "..." or '...'); heredoc/$(...) → skip.
msg=""
if [[ $cmd =~ -m[[:space:]]+\"([^\"]*)\" ]]; then
  msg="${BASH_REMATCH[1]}"
elif [[ $cmd =~ -m[[:space:]]+\'([^\']*)\' ]]; then
  msg="${BASH_REMATCH[1]}"
fi
[ -z "$msg" ] && exit 0

subject="${msg%%$'\n'*}"   # first line only

TYPES="feat|fix|docs|refactor|test|chore|ci|perf|style|build|revert"
if [[ ! $subject =~ ^($TYPES)(\(.+\))?:\ .+ ]]; then
  printf '⚠️  CONVENTIONAL COMMITS : "%s" ne respecte pas le format.\n' "$subject"
  printf 'Format attendu : type(scope): description courte\n'
  printf 'Exemples : feat(analyses): ajoute le filtre par matrice ; fix(lots): corrige le blocage\n'
  printf 'Types valides : %s\n' "${TYPES//|/, }"
fi

exit 0
