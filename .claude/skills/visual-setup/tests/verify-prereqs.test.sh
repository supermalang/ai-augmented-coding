#!/usr/bin/env bash
# Tests for verify-prereqs.sh — the detect-only prerequisite check.
# Run: bash .claude/skills/visual-setup/tests/verify-prereqs.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../verify-prereqs.sh"
pass=0; fail=0

ok()   { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }

# ── 1: all required present → exit 0, reports ready ──────────────────────────
# `sh` is guaranteed present in any POSIX env, so this is deterministic.
out="$(VISUAL_REQUIRED_CMDS="sh" bash "$SCRIPT")"; code=$?
[ "$code" -eq 0 ] && ok "all-present → exit 0" || bad "all-present → expected exit 0, got $code"
echo "$out" | grep -q "present" && ok "all-present → reports ready" || bad "all-present → missing 'present' line"

# ── 2: a missing command → non-zero exit + remediation, NO install attempted ─
out="$(VISUAL_REQUIRED_CMDS="__definitely_missing_cmd_xyz__" bash "$SCRIPT" 2>&1)"; code=$?
[ "$code" -ne 0 ] && ok "missing → non-zero exit" || bad "missing → expected non-zero, got $code"
echo "$out" | grep -q "missing" && ok "missing → lists missing prerequisite" || bad "missing → no 'missing' line"
echo "$out" | grep -qi "no install was attempted" && ok "missing → states no install attempted" || bad "missing → no 'no install' assurance"

# ── 3: known command gets a specific remediation ─────────────────────────────
out="$(VISUAL_REQUIRED_CMDS="node" bash "$SCRIPT" 2>&1)" || true
if command -v node >/dev/null 2>&1; then
  echo "$out" | grep -q "present" && ok "node-present → ready" || bad "node-present → not ready"
else
  echo "$out" | grep -qi "nodejs" && ok "node-missing → node-specific remediation" || bad "node-missing → generic remediation"
fi

# ── 4: static guarantee — the script never actually invokes an installer ─────
# Installer tokens are allowed ONLY inside remediation text (lines that echo).
# Any line with an installer token that is NOT an echo line is a real invocation.
offending="$(grep -nE '(apt(-get)?|brew|choco|npm[[:space:]]+(i|install)|yarn[[:space:]]+add|playwright[[:space:]]+install)' "$SCRIPT" | grep -v 'echo' || true)"
[ -z "$offending" ] && ok "no installer is actually invoked (tokens only in remediation text)" \
                     || bad "possible installer invocation: $offending"

echo
echo "verify-prereqs.test.sh — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
