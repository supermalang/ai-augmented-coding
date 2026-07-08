#!/usr/bin/env bash
# Container/no-vendor adapter for per-PR preview deploys.
# Portable by design: calls the PREVIEW_CMD / TEARDOWN_CMD from .claude/context.md (Preview deploy
# section) — it names no vendor. Usage:
#   PREVIEW_CMD='...'  bash ci-adapters/container/preview.sh up      # deploy, prints the URL
#   TEARDOWN_CMD='...' bash ci-adapters/container/preview.sh down    # destroy on PR close
# The deploy command MUST print the preview URL as its last line of stdout; this script echoes it
# back on the final line so a caller (or a webhook glue script) can post it to the PR.
# Merge and visual-bless stay human — this only stands the environment up / tears it down.
set -euo pipefail

MODE="${1:-up}"

case "$MODE" in
  up)
    if [ -z "${PREVIEW_CMD:-}" ]; then
      echo "No PREVIEW_CMD configured — skipping preview (link will be None)." >&2
      exit 0
    fi
    # Run the configured deploy command; its last stdout line is the URL.
    URL="$(bash -lc "$PREVIEW_CMD" | tail -n 1)"
    echo "🔎 preview URL: $URL" >&2
    printf '%s\n' "$URL"          # machine-readable: URL on the final stdout line
    ;;
  down)
    if [ -z "${TEARDOWN_CMD:-}" ]; then
      echo "No TEARDOWN_CMD configured — nothing to tear down." >&2
      exit 0
    fi
    bash -lc "$TEARDOWN_CMD"
    echo "🧹 preview torn down" >&2
    ;;
  *)
    echo "usage: preview.sh [up|down]" >&2
    exit 64 ;;
esac
