#!/usr/bin/env bash
# health-gate.sh — post-deploy smoke/health check + auto-rollback (reference implementation).
#
# WHERE IT RUNS: at the DEPLOY BOUNDARY a project owns (its deploy pipeline / release step) — NOT in
# /ship-task and NOT in develop → main promotion. It is a machine safety check, not a human gate; the
# three human gates (merge / bless / promote) are unchanged.
#
# INERT WHEN OFF: if `.claude/context.md` → Observability (runtime) → `Health gate` is not truthy,
# this exits 0 immediately — no check, no rollback, nothing. Default OFF.
#
# CONTRACT when ON (a project fills the [CONFIGURE] commands):
#   1. run the health/smoke check against the deployed release
#   2. evaluate it against the SLOs in context.md
#   3. on failure → run the rollback command AND record the incident (via emit.sh)
#   4. exit non-zero so the deploy pipeline marks the release failed
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONTEXT_FILE="${OBS_CONTEXT_FILE:-$ROOT/.claude/context.md}"

# Reuse the same pure-bash flag reader shape as emit.sh (kept local so this script stands alone).
obs_flag() {
  local key="$1" default="${2:-}" insection=0 line val=""
  [ -f "$CONTEXT_FILE" ] || { printf '%s' "$default"; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '## Observability (runtime)'*) insection=1; continue ;; esac
    if [ "$insection" -eq 1 ]; then
      case "$line" in
        '## '*) break ;;
        *"**$key:**"*)
          val="${line#*"**$key:**"}"; val="${val%%#*}"
          val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
          printf '%s' "$val"; return 0 ;;
      esac
    fi
  done < "$CONTEXT_FILE"
  printf '%s' "$default"
}
is_truthy() { case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in true|1|yes|on) return 0 ;; *) return 1 ;; esac; }

# ── The inert gate: OFF → no-op ───────────────────────────────────────────────
is_truthy "$(obs_flag 'Health gate' false)" || exit 0

# ── Enabled path (a project wires these [CONFIGURE] commands) ──────────────────
# HEALTH_CHECK_CMD : runs the smoke/health probe; exits 0 if the release is healthy per the SLOs.
# ROLLBACK_CMD     : reverts to the previous known-good release.
HEALTH_CHECK_CMD="${HEALTH_CHECK_CMD:-}"   # [CONFIGURE] e.g. a script hitting /health and checking p95/error-rate vs SLOs
ROLLBACK_CMD="${ROLLBACK_CMD:-}"           # [CONFIGURE] e.g. the deploy tool's rollback command
RELEASE="${1:-unknown}"

if [ -z "$HEALTH_CHECK_CMD" ]; then
  echo "⚠️  health-gate: enabled but HEALTH_CHECK_CMD not configured — skipping (no false gate)." >&2
  exit 0
fi

echo "▶️  health-gate: checking release '$RELEASE' against SLOs ($(obs_flag SLOs 'unset'))…"
if bash -lc "$HEALTH_CHECK_CMD"; then
  echo "✅ health-gate: release '$RELEASE' healthy."
  exit 0
fi

echo "🚨 health-gate: release '$RELEASE' FAILED the SLO check — rolling back." >&2
"$ROOT/observability/emit.sh" error "health-gate failed for release $RELEASE" "auto-rollback triggered" || true
if [ -n "$ROLLBACK_CMD" ]; then
  bash -lc "$ROLLBACK_CMD" && echo "↩️  health-gate: rolled back release '$RELEASE'." >&2 \
    || echo "❌ health-gate: ROLLBACK COMMAND FAILED — manual intervention needed." >&2
else
  echo "❌ health-gate: no ROLLBACK_CMD configured — cannot auto-rollback; manual intervention needed." >&2
fi
exit 1
