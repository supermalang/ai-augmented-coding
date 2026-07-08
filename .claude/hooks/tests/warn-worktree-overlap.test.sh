#!/usr/bin/env bash
# Tests for warn-worktree-overlap.sh — the ADVISORY cross-worktree overlap check.
# Contract: WARN only (never blocks), silent when one worktree, robust to slash style.
# Run: bash .claude/hooks/tests/warn-worktree-overlap.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../warn-worktree-overlap.sh"
ROOT="$(cd "$HERE/../../.." && pwd)"
export CLAUDE_PROJECT_DIR="$ROOT"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }

# Feed a tool_input.file_path as JSON on stdin; capture stdout + exit code.
run() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | bash "$HOOK"; }
warned() { printf '%s' "$1" | grep -q 'WORKTREE OVERLAP'; }
# Never emits a blocking decision.
blocked() { printf '%s' "$1" | grep -qE '"permissionDecision":"deny"|"continue":[[:space:]]*false'; }

# ── never blocks / never exits non-zero ──────────────────────────────────────
out="$(run "$ROOT/README.md")"; rc=$?
[ "$rc" -eq 0 ] && ok "exit 0 (single worktree, no overlap)" || bad "non-zero exit ($rc)"
blocked "$out" && bad "emitted a blocking decision" || ok "never emits a block decision"

# ── silent when only one worktree ────────────────────────────────────────────
[ -z "$out" ] && ok "silent when one worktree" || bad "printed output with one worktree: $out"

# ── empty / unparseable input is silent and exits 0 ──────────────────────────
out="$(printf '{"tool_input":{}}' | bash "$HOOK")"; rc=$?
{ [ "$rc" -eq 0 ] && [ -z "$out" ]; } && ok "silent on empty file_path" || bad "not silent on empty input (rc=$rc, out=$out)"

# ── with a sibling worktree touching the SAME file → WARN, still exit 0 ───────
WT="$ROOT/../.wt-overlap-selftest"
git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
git -C "$ROOT" branch -D test/overlap-selftest >/dev/null 2>&1 || true
if git -C "$ROOT" worktree add -b test/overlap-selftest "$WT" HEAD >/dev/null 2>&1; then
  printf '\n# overlap selftest\n' >> "$WT/README.md"

  out="$(run "$ROOT/README.md")"; rc=$?
  warned "$out" && ok "warns when a sibling worktree changed the same file" || bad "did NOT warn on overlap"
  [ "$rc" -eq 0 ] && ok "still exits 0 on overlap (advisory, never blocks)" || bad "overlap caused non-zero exit ($rc)"
  blocked "$out" && bad "overlap emitted a blocking decision" || ok "overlap warning is not a block"

  # A file NOT touched by the sibling → no warning.
  out="$(run "$ROOT/CLAUDE.md")"
  warned "$out" && bad "warned on a non-overlapping file" || ok "quiet on a non-overlapping file"

  git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
  git -C "$ROOT" branch -D test/overlap-selftest >/dev/null 2>&1 || true
else
  printf '  ! skipped sibling-worktree cases (could not create a worktree here)\n'
fi

echo
echo "warn-worktree-overlap.test.sh — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
