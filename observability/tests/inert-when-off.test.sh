#!/usr/bin/env bash
# Tests for the runtime-observability layer. The headline acceptance criterion:
# with Observability disabled, the emit/health-gate calls are FULLY INERT — no output, exit 0, and
# the configured sink is NEVER invoked (no dependency loaded, no cost). Also proves the enabled path
# works, so "inert" is the flag doing its job, not a broken script.
# Run: bash observability/tests/inert-when-off.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
EMIT="$ROOT/observability/emit.sh"
GATE="$ROOT/observability/health-gate.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A sentinel "sink": if emit ever calls it, it creates a marker file. Its existence == sink invoked.
SENTINEL="$WORK/sink-was-called"
SINK="$WORK/sentinel-sink.sh"
cat > "$SINK" <<EOF
#!/usr/bin/env bash
printf 'called with: %s\n' "\$*" > "$SENTINEL"
EOF
chmod +x "$SINK"

# Write a context.md containing just the Observability block, with the given Enabled/Sink/Health values.
mkctx() {  # $1=enabled $2=sink $3=healthgate
  local f="$WORK/context-$RANDOM.md"
  {
    printf '# ctx\n\n## Observability (runtime)\n'
    printf -- '- **Enabled:** %s\n' "$1"
    printf -- '- **Sink:** %s\n' "$2"
    printf -- '- **SLOs:** [CONFIGURE — error-rate < 1%%]\n'
    printf -- '- **Health gate:** %s\n' "$3"
    printf '\n## Next section\n- **Enabled:** true\n'   # a trap: must NOT be read (wrong section)
  } > "$f"
  printf '%s' "$f"
}

reset_sentinel() { rm -f "$SENTINEL"; }

# ── 1. Disabled → fully inert ────────────────────────────────────────────────
reset_sentinel
ctx="$(mkctx false "$SINK" false)"
out="$(OBS_CONTEXT_FILE="$ctx" bash "$EMIT" error "boom" "ctx")"; rc=$?
[ "$rc" -eq 0 ] && ok "disabled: emit exits 0" || bad "disabled: emit exit $rc"
[ -z "$out" ] && ok "disabled: emit prints nothing" || bad "disabled: emit printed '$out'"
[ ! -f "$SENTINEL" ] && ok "disabled: sink NEVER invoked (inert)" || bad "disabled: sink was invoked!"

# ── 2. Missing/absent Enabled key → defaults OFF (inert) ─────────────────────
reset_sentinel
ctxNo="$WORK/ctx-noflag.md"; printf '# ctx\n\n## Observability (runtime)\n- **Sink:** %s\n' "$SINK" > "$ctxNo"
out="$(OBS_CONTEXT_FILE="$ctxNo" bash "$EMIT" metric latency 42)"; rc=$?
{ [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -f "$SENTINEL" ]; } && ok "absent Enabled → defaults off (inert)" || bad "absent Enabled not treated as off (rc=$rc out=$out)"

# ── 3. No Observability section at all → inert ───────────────────────────────
reset_sentinel
ctxEmpty="$WORK/ctx-empty.md"; printf '# ctx\n\n## Something else\n- **Enabled:** true\n' > "$ctxEmpty"
out="$(OBS_CONTEXT_FILE="$ctxEmpty" bash "$EMIT" error "x")"; rc=$?
{ [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -f "$SENTINEL" ]; } && ok "no Observability section → inert (section-scoped read)" || bad "leaked Enabled from another section (rc=$rc)"

# ── 4. Enabled + real sink → the sink IS invoked (proves the flag is the gate) ─
reset_sentinel
ctxOn="$(mkctx true "$SINK" false)"
OBS_CONTEXT_FILE="$ctxOn" bash "$EMIT" deploy "v1.2.3" prod >/dev/null; rc=$?
[ "$rc" -eq 0 ] && [ -f "$SENTINEL" ] && ok "enabled: sink invoked with the event" || bad "enabled: sink NOT invoked (rc=$rc)"

# ── 5. Enabled but Sink still a [CONFIGURE] placeholder → warn, drop, exit 0 ──
reset_sentinel
ctxHalf="$(mkctx true "[CONFIGURE — set me]" false)"
out="$(OBS_CONTEXT_FILE="$ctxHalf" bash "$EMIT" error "x" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && [ ! -f "$SENTINEL" ]; } && ok "enabled+unconfigured sink → no half-configured failure (exit 0, dropped)" || bad "half-configured sink misbehaved (rc=$rc)"

# ── 6. Health gate off → no-op ───────────────────────────────────────────────
ctxGateOff="$(mkctx false "$SINK" false)"
out="$(OBS_CONTEXT_FILE="$ctxGateOff" bash "$GATE" v1)"; rc=$?
{ [ "$rc" -eq 0 ] && [ -z "$out" ]; } && ok "health gate off → no-op (exit 0, silent)" || bad "health gate off not inert (rc=$rc out=$out)"

# ── 7. Health gate on but no HEALTH_CHECK_CMD → skip, no false gate ──────────
ctxGateOn="$(mkctx true "$SINK" true)"
out="$(OBS_CONTEXT_FILE="$ctxGateOn" HEALTH_CHECK_CMD="" bash "$GATE" v1 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "health gate on + unconfigured check → skips (no false gate)" || bad "health gate falsely gated when unconfigured (rc=$rc)"

echo
echo "inert-when-off.test.sh — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
