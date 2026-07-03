#!/usr/bin/env bash
# Tests for guard-visual-update.sh — blocks agents from re-baselining screenshots.
# Run: bash .claude/hooks/tests/guard-visual-update.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../guard-visual-update.sh"
export CLAUDE_PROJECT_DIR="$(cd "$HERE/../../.." && pwd)"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }

# Feed a tool_input.command as JSON on stdin; capture the hook's stdout.
run() { printf '{"tool_input":{"command":"%s"}}' "$1" | bash "$HOOK" 2>/dev/null; }
denied() { echo "$1" | grep -q '"permissionDecision":"deny"'; }

# ── blocks: the canonical re-baseline invocations ────────────────────────────
out="$(run 'npx playwright test --update-snapshots')"
denied "$out" && ok "blocks: playwright test --update-snapshots" || bad "did NOT block --update-snapshots"

out="$(run 'docker compose -f docker-compose.visual.yml run --rm visual npx playwright test -c playwright.visual.config.ts --update-snapshots')"
denied "$out" && ok "blocks: containerised --update-snapshots" || bad "did NOT block containerised update"

out="$(run 'npx playwright test -u')"
denied "$out" && ok "blocks: playwright -u alias" || bad "did NOT block -u alias"

# ── allows: normal runs and unrelated -u usages ──────────────────────────────
out="$(run 'npx playwright test')"
denied "$out" && bad "wrongly blocked a normal playwright run" || ok "allows: normal playwright run"

out="$(run 'sort -u names.txt')"
denied "$out" && bad "wrongly blocked 'sort -u'" || ok "allows: sort -u (no playwright token)"

out="$(run 'git push -u origin HEAD')"
denied "$out" && bad "wrongly blocked 'git push -u'" || ok "allows: git push -u (no playwright token)"

# A commit message / doc that MENTIONS the flag is not an invocation → must not block.
out="$(run 'git commit -m \"feat: block agents from playwright --update-snapshots\"')"
denied "$out" && bad "wrongly blocked a commit message mentioning the flag" || ok "allows: commit message mentioning --update-snapshots (not 'playwright test')"

# ── fail-safe: empty/unparseable command does NOT block all Bash ─────────────
out="$(printf '{"tool_input":{}}' | bash "$HOOK" 2>/dev/null)"
denied "$out" && bad "empty command wrongly blocked" || ok "allows: empty/unparseable command (no block-all)"

# ── tool-independence: script uses only builtins (no jq/grep/git/sed) ─────────
if grep -nE '(^|[[:space:]])(jq|grep|sed|awk|git|cat)[[:space:]]' "$HOOK" | grep -vE '^[[:digit:]]+:[[:space:]]*#' >/dev/null 2>&1; then
  bad "hook depends on an external tool (could fail open)"
else
  ok "hook uses builtins only (pure-bash, can't fail open)"
fi

echo
echo "guard-visual-update.test.sh — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
