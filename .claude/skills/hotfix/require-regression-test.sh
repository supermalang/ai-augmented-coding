#!/usr/bin/env bash
# require-regression-test.sh — the "a hotfix PR must add a regression test" check.
#
# Canonical, reusable determination (used by guard-hotfix-test.sh at push/PR time, by CI, and runnable
# by hand). On a `hotfix/*` branch it verifies the branch's diff vs the production branch includes at
# least one test file (per STACK_TEST_FILE_REGEX). Exit 0 = ok (or not a hotfix branch → nothing to
# enforce); exit 1 = a hotfix branch with NO regression test (prints the reason on stderr).
#
# WHY: urgency may skip ceremony, never the regression test — it's what stops the bug silently
# returning. Stack-agnostic: the test-file pattern and production branch come from stack-profile.sh.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -f "$ROOT/.claude/hooks/stack-profile.sh" ] && . "$ROOT/.claude/hooks/stack-profile.sh"
TEST_RE="${STACK_TEST_FILE_REGEX:-\.(test|spec)\.(ts|tsx|js|jsx)\$}"
PROD="${STACK_PRODUCTION_BRANCH:-main}"

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
case "$branch" in
  hotfix/*) ;;
  *) exit 0 ;;    # not a hotfix branch → this check does not apply
esac

# Base to diff against: the merge-base with the production branch (prefer local, else origin/).
base="$(git merge-base "$PROD" HEAD 2>/dev/null || git merge-base "origin/$PROD" HEAD 2>/dev/null || echo '')"
if [ -z "$base" ]; then
  # Can't locate the production branch here (e.g. shallow clone) → don't hard-fail; CI re-checks.
  echo "require-regression-test: cannot resolve production branch '$PROD' — skipping (CI will re-check)." >&2
  exit 0
fi

changed="$(git diff --name-only "$base" HEAD 2>/dev/null || echo '')"
if printf '%s\n' "$changed" | grep -Eq "$TEST_RE"; then
  exit 0
fi

echo "🚫 HOTFIX GATE: this hotfix branch adds no regression test. A hotfix PR MUST include a new/updated test (matching ${TEST_RE}) that reproduces the bug — write the failing test FIRST, then the fix. Urgency skips ceremony, never the regression test." >&2
exit 1
