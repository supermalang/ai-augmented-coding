#!/usr/bin/env bash
# Tests for the self-improvement (hill-climbing) layer:
#   GATE  (should-run.sh)      — disabled → nothing runs; thin data → nothing runs; else run.
#   GUARD (guard-hill-climb.sh) — inert on a normal run; on a hill-climb run it makes harness edits
#                                 structurally impossible (only the proposal + scratch may be written).
# Run: bash .claude/hooks/tests/hill-climb.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
GATE="$ROOT/.claude/skills/hill-climb/should-run.sh"
GUARD="$ROOT/.claude/hooks/guard-hill-climb.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"; rm -f "$ROOT/.hill-climb-active"' EXIT

mkctx() {  # $1=mode $2=min  → path to a context.md with a hill-climbing section
  local f="$WORK/ctx-$1-$RANDOM.md"
  {
    printf '# ctx\n\n## Self-improvement (hill-climbing)\n'
    printf -- '- **Mode:** %s\n' "$1"
    printf -- '- **Cadence:** manual\n'
    printf -- '- **Min trace volume:** %s\n' "$2"
    printf '\n## Next section\n- **Mode:** propose-only\n'   # trap: must not be read
  } > "$f"; printf '%s' "$f"
}

# ── GATE 1: disabled (default) → skip, nothing runs ──────────────────────────
out="$(OBS_CONTEXT_FILE="$(mkctx disabled 20)" bash "$GATE" 999)"
case "$out" in skip:*disabled*) ok "gate: disabled → skip (inert)";; *) bad "gate: disabled not skipped → '$out'";; esac

# ── GATE 2: propose-only but thin data → skip ────────────────────────────────
out="$(OBS_CONTEXT_FILE="$(mkctx propose-only 20)" bash "$GATE" 5)"
case "$out" in skip:*thin*) ok "gate: propose-only + thin traces → skip";; *) bad "gate: thin data not skipped → '$out'";; esac

# ── GATE 3: propose-only + enough traces → run ───────────────────────────────
out="$(OBS_CONTEXT_FILE="$(mkctx propose-only 20)" bash "$GATE" 25)"
case "$out" in run:*) ok "gate: propose-only + enough traces → run";; *) bad "gate: should have run → '$out'";; esac

# ── GATE 4: no auto mode — 'auto'/'auto-apply' are NOT honored (treated as disabled) ─
out="$(OBS_CONTEXT_FILE="$(mkctx auto-apply 1)" bash "$GATE" 999)"
case "$out" in skip:*) ok "gate: no auto-apply mode exists (auto-apply → skip)";; *) bad "gate: auto-apply was honored → '$out'";; esac

# ── GUARD helpers ────────────────────────────────────────────────────────────
export CLAUDE_PROJECT_DIR="$ROOT"
edit() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" | bash "$GUARD"; }
bashcmd() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | bash "$GUARD"; }
denied() { printf '%s' "$1" | grep -q '"permissionDecision":"deny"'; }

# ── GUARD 1: NOT a hill-climb run (no marker, ordinary branch) → inert ───────
rm -f "$ROOT/.hill-climb-active"
out="$(edit Write "$ROOT/.claude/skills/coder/SKILL.md")"
denied "$out" && bad "guard: blocked a harness edit on a normal run" || ok "guard: inert on a normal run (harness edit allowed)"

# ── Activate via marker (branch-independent) ─────────────────────────────────
: > "$ROOT/.hill-climb-active"

# blocks harness edits
for p in ".claude/skills/coder/SKILL.md" ".claude/agents/coder.md" ".claude/hooks/guard-branch.sh" ".claude/settings.json" ".claude/context.md" "CLAUDE.md"; do
  out="$(edit Edit "$ROOT/$p")"
  denied "$out" && ok "guard: blocks harness edit → $p" || bad "guard: did NOT block $p"
done

# allows the proposal + scratch
out="$(edit Write "$ROOT/docs/improvements/2026-07-08-hill-climb.md")"
denied "$out" && bad "guard: blocked the proposal doc" || ok "guard: allows the proposal (docs/improvements/**)"
out="$(edit Write "$ROOT/.scratch/hill/notes.md")"
denied "$out" && bad "guard: blocked scratch" || ok "guard: allows .scratch/**"

# fail-closed: Edit with no target on an active run → deny
out="$(printf '{"tool_name":"Edit","tool_input":{}}' | bash "$GUARD")"
denied "$out" && ok "guard: fail-closed on unparseable Edit target" || bad "guard: did NOT fail closed on empty Edit target"

# Bash: git/gh allowed; shell write into harness blocked; shell write into proposal allowed
out="$(bashcmd 'git push -u origin hill-climb/2026-07-08')"
denied "$out" && bad "guard: blocked git push" || ok "guard: allows git push (needed to open the PR)"
out="$(bashcmd 'echo x > .claude/skills/coder/SKILL.md')"
denied "$out" && ok "guard: blocks shell write into .claude/**" || bad "guard: did NOT block shell write into harness"
out="$(bashcmd 'echo x > docs/improvements/note.md')"
denied "$out" && bad "guard: blocked shell write to proposal" || ok "guard: allows shell write to docs/improvements/**"

rm -f "$ROOT/.hill-climb-active"

echo
echo "hill-climb.test.sh — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
