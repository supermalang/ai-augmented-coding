#!/usr/bin/env bash
# Tests for guard-hotfix-test.sh — a hotfix PR must add a regression test.
# Contract: inert off hotfix branches & non-push commands; on a hotfix/* branch it DENIES a push/PR
# when the branch adds no test file vs the production branch, and ALLOWS it once a test is present.
# Runs against a throwaway git repo so branch/diff detection is real. Run:
#   bash .claude/hooks/tests/guard-hotfix-test.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/guard-hotfix-test.sh"
CHECK="$REPO_ROOT/.claude/skills/hotfix/require-regression-test.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }
denied() { printf '%s' "$1" | grep -q '"permissionDecision":"deny"'; }

# Build a throwaway repo that carries the real hook scripts + a stack-profile.
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.claude/hooks" "$WORK/.claude/skills/hotfix"
cp "$REPO_ROOT/.claude/hooks/_hooklib.sh" "$WORK/.claude/hooks/"
cp "$HOOK" "$WORK/.claude/hooks/guard-hotfix-test.sh"
cp "$CHECK" "$WORK/.claude/skills/hotfix/require-regression-test.sh"
cat > "$WORK/.claude/hooks/stack-profile.sh" <<'EOF'
export STACK_TEST_FILE_REGEX='\.(test|spec)\.(ts|tsx|js|jsx)$'
export STACK_PRODUCTION_BRANCH='main'
EOF

git -C "$WORK" init -q -b main
git -C "$WORK" config user.email t@t.t; git -C "$WORK" config user.name t
mkdir -p "$WORK/src"
printf 'export const x=1\n' > "$WORK/src/app.ts"
git -C "$WORK" add -A && git -C "$WORK" commit -qm "base"

export CLAUDE_PROJECT_DIR="$WORK"
runhook() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | bash "$WORK/.claude/hooks/guard-hotfix-test.sh"; }

# ── 1. On main (not a hotfix branch) → inert even for a push ─────────────────
out="$(runhook 'git push -u origin main')"
denied "$out" && bad "blocked a push on main" || ok "inert on non-hotfix branch (push allowed)"

# ── 2. Hotfix branch, NO test in the diff → push denied ──────────────────────
git -C "$WORK" switch -q -c hotfix/bug-1
printf 'export const x=2\n' > "$WORK/src/app.ts"          # a code fix, no test
git -C "$WORK" commit -qam "fix: patch app"
out="$(runhook 'git push -u origin hotfix/bug-1')"
denied "$out" && ok "hotfix without a test → push DENIED" || bad "hotfix without a test was NOT blocked"

# ── 3. A non-push command on the same branch → not gated ─────────────────────
out="$(runhook 'git status')"
denied "$out" && bad "blocked a non-push command" || ok "non-push command not gated"

# ── 4. Add a regression test → push allowed ──────────────────────────────────
mkdir -p "$WORK/tests"
printf 'test("repro", () => {})\n' > "$WORK/tests/bug-1.test.ts"
git -C "$WORK" add -A && git -C "$WORK" commit -qam "test: regression for bug-1"
out="$(runhook 'git push -u origin hotfix/bug-1')"
denied "$out" && bad "blocked a hotfix that DOES add a test" || ok "hotfix with a regression test → push allowed"

# ── 5. PR-open command is gated the same way (deny when no test) ─────────────
git -C "$WORK" switch -q -c hotfix/bug-2 main
printf 'export const y=3\n' > "$WORK/src/app.ts"
git -C "$WORK" commit -qam "fix: another patch"
out="$(runhook 'gh pr create --base main --title x --body y')"
denied "$out" && ok "gh pr create on testless hotfix → DENIED" || bad "PR-open on testless hotfix not blocked"

echo
echo "guard-hotfix-test.test.sh — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
