#!/usr/bin/env bash
# should-run.sh — the hill-climb GATE. Deterministic, side-effect-free: decides whether the
# self-improvement analysis may run, so "disabled → nothing runs" is provable, not vibes.
#
# Prints one line and exits 0 in all cases (a skip is normal, not an error):
#   run:  <n> traces ≥ min <m> · mode=propose-only        → the skill proceeds
#   skip: mode=<mode> (disabled)                            → nothing runs (default)
#   skip: <n> traces < min <m> (thin data)                 → nothing runs
#
# Reads Mode + "Min trace volume" from `.claude/context.md` → Self-improvement (hill-climbing).
# Trace volume: arg $1 if given, else counts "### Run trace" blocks in the roadmap (+ archive).
# Overridable for tests: OBS_CONTEXT_FILE, HILL_ROADMAP_GLOB.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONTEXT_FILE="${OBS_CONTEXT_FILE:-$ROOT/.claude/context.md}"

# Pure-bash reader for a "- **<Key>:** <value>" line inside the hill-climbing section.
hill_flag() {
  local key="$1" default="${2:-}" insection=0 line val=""
  [ -f "$CONTEXT_FILE" ] || { printf '%s' "$default"; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '## Self-improvement (hill-climbing)'*) insection=1; continue ;; esac
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

MODE="$(hill_flag Mode disabled)"
MODE="$(printf '%s' "$MODE" | tr '[:upper:]' '[:lower:]')"

# The ONLY mode that runs is propose-only. disabled (default) or anything else → no-op.
# There is deliberately NO auto-apply mode to honor.
if [ "$MODE" != "propose-only" ]; then
  echo "skip: mode=${MODE:-disabled} (disabled)"
  exit 0
fi

# Min trace volume (default 20 when unset / still a [CONFIGURE] placeholder).
MIN_RAW="$(hill_flag 'Min trace volume' '')"
MIN="${MIN_RAW//[!0-9]/}"        # keep digits only ("20 runs" → "20"; "[CONFIGURE…]" → "")
[ -n "$MIN" ] || MIN=20

# Trace count: explicit arg wins; else count "### Run trace" across roadmap + archive.
if [ -n "${1:-}" ] && [ -z "${1//[0-9]/}" ]; then
  COUNT="$1"
else
  COUNT=0
  for f in "$ROOT/docs/ROADMAP.md" $ROOT/docs/roadmap/archive/*.md; do
    [ -f "$f" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in '### Run trace'*) COUNT=$((COUNT+1)) ;; esac
    done < "$f"
  done
fi

if [ "$COUNT" -lt "$MIN" ]; then
  echo "skip: ${COUNT} traces < min ${MIN} (thin data)"
  exit 0
fi

echo "run: ${COUNT} traces ≥ min ${MIN} · mode=propose-only"
exit 0
