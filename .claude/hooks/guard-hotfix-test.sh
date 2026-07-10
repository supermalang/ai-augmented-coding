#!/usr/bin/env bash
# guard-hotfix-test.sh — enforce "a hotfix PR must add a regression test" at push / PR-open time.
#
# Wired as PreToolUse(Bash). When the command is a push or a PR/MR-open AND the current branch is a
# `hotfix/*` branch, it runs the canonical check (require-regression-test.sh): if the branch's diff
# vs the production branch contains no test file, it DENIES the push/PR. Urgency may skip ceremony —
# never the regression test that stops the bug silently returning.
#
# This is a hotfix-only gate: it does nothing on non-hotfix branches and nothing on non-push commands,
# so ordinary work is unaffected. No guard EXEMPTION is granted to hotfixes anywhere — this ADDS a
# requirement, it never removes one.
#
# HONEST LIMIT: needs git to diff against the production branch; if it can't resolve that base it
# allows (the CI check re-enforces). Detection is by branch name + command string (like the other
# command-string guards).
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_read_stdin
cmd="$(hook_field command)"
[ -z "$cmd" ] && exit 0

# Only gate the act of publishing: a push, or opening a PR/MR.
case "$cmd" in
  *"git push"*|*"gh pr create"*|*"glab mr create"*) ;;
  *) exit 0 ;;
esac

# Only on a hotfix branch.
branch="$(hook_git_branch)"
case "$branch" in
  hotfix/*) ;;
  *) exit 0 ;;
esac

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
CHECK="$ROOT/.claude/skills/hotfix/require-regression-test.sh"
[ -f "$CHECK" ] || exit 0   # check script absent → nothing to enforce here

# Run the check with the PROJECT dir as CWD so it inspects this repo (not the ambient CWD).
msg="$(cd "$ROOT" && bash "$CHECK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && exit 0
hook_deny "$msg"
