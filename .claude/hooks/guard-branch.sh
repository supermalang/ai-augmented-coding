#!/usr/bin/env bash
# guard-branch.sh — block editing implementation files directly on develop or main.
# PURE BASH (builtins only; branch from .git/HEAD) — no jq/git/sed/grep dependency.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_read_stdin
file_path="$(hook_field file_path)"
[ -z "$file_path" ] && exit 0   # roadmap-gate fails closed on unparseable paths; this is secondary

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
rel="${file_path#"$PROJECT_DIR"/}"
rel="${rel#./}"
rel="${rel//\\//}"

# Implementation surface (same spirit as the roadmap gate, plus infra files).
if [[ $rel =~ ^(src/|prisma/schema\.prisma|Dockerfile|start\.sh) ]]; then
  branch="$(hook_git_branch)"
  if [ "$branch" = "develop" ] || [ "$branch" = "main" ]; then
    hook_block "🚫 BRANCH GATE: You are on '$branch'. Branch from develop first: git switch develop && git switch -c <type>/description — then open a PR to develop when done."
  fi
fi

exit 0
