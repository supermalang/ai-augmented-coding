#!/usr/bin/env bash
# open-report.sh — run the Tier-1 visual suite and/or serve its HTML report.
#
# Two responsibilities, one file, selected by the first arg:
#   run [substring]   run the visual specs (workers=1, NEVER --update-snapshots), then fall through
#                     to serve. A substring filters specs by title/path.
#   serve             serve the most recent HTML report only (no run).
#   last              alias for `serve`.
#
# WHY no --update-snapshots anywhere in here: blessing baselines is a human action. This script is
# invocable by the /visual-report agent, so it must be structurally incapable of re-baselining —
# guard-visual-update would block it anyway, but not offering the flag is the belt-and-braces.
#
# CONTAINER-AWARE: in a Dev Container the report server must bind 0.0.0.0 and NOT try to launch a
# browser inside the container; the human opens it on the host through a forwarded port. On a plain
# local machine we let `show-report` open the browser itself.
set -uo pipefail

MODE="${1:-run}"
FILTER="${2:-}"

CONFIG="visual-review/playwright.visual.config.ts"
REPORT_DIR="visual-review/results/report"
PORT="${VISUAL_REPORT_PORT:-9323}"

# --- guard: refuse if someone smuggled an update flag through the filter arg ------------------
case "$FILTER" in
  *--update-snapshots*|*" -u"*|"-u"|*" -u "*)
    echo "🚫 refusing: --update-snapshots / -u is a human action, not for this runner." >&2
    exit 2 ;;
esac

# --- detect container / remote so we know how to serve ----------------------------------------
in_container() {
  [ -f /.dockerenv ] && return 0
  [ -n "${REMOTE_CONTAINERS:-}" ] && return 0
  [ -n "${CODESPACES:-}" ] && return 0
  [ -n "${DEVCONTAINER:-}" ] && return 0
  return 1
}

run_suite() {
  echo "▶️  Running visual specs (workers=1${FILTER:+, filter=\"$FILTER\"})…"
  # A non-zero exit means screenshots DIFFERED — expected; we still serve the report.
  if [ -n "$FILTER" ]; then
    npx playwright test -c "$CONFIG" --workers=1 "$FILTER" || true
  else
    npx playwright test -c "$CONFIG" --workers=1 || true
  fi
}

serve_report() {
  if [ ! -f "$REPORT_DIR/index.html" ]; then
    echo "⚠️  No report at $REPORT_DIR — run \`open-report.sh run\` first." >&2
    exit 1
  fi
  if in_container; then
    echo "📂 Serving report on http://localhost:${PORT}  (bind 0.0.0.0 → open on your HOST browser)"
    echo "   If it doesn't open, add ${PORT} to forwardPorts in .devcontainer/devcontainer.json."
    # --host 0.0.0.0 so the forwarded port reaches the host; show-report stays in the foreground.
    exec npx playwright show-report "$REPORT_DIR" --host 0.0.0.0 --port "$PORT"
  else
    echo "📂 Opening report on http://localhost:${PORT}…"
    exec npx playwright show-report "$REPORT_DIR" --port "$PORT"
  fi
}

case "$MODE" in
  run)         run_suite; serve_report ;;
  serve|last)  serve_report ;;
  *)
    echo "usage: open-report.sh [run [substring] | serve | last]" >&2
    exit 64 ;;
esac
