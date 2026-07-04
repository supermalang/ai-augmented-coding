#!/usr/bin/env bash
# verify-prereqs.sh — detect-only prerequisite check for visual baseline testing.
#
# It DETECTS the runtimes visual testing needs and, when any is missing, prints a
# concrete remediation line for each. It NEVER installs anything and NEVER calls a
# package manager — setting up runtimes is the human's job (see the remediation lines).
#
# Exit codes:
#   0  all required commands present
#   1  at least one required command missing (listed with remediation)
#
# The required set is injectable via VISUAL_REQUIRED_CMDS (space-separated) so this
# script is testable in isolation; the default matches Tier 1 (in-project Playwright —
# no container, so no Docker requirement).

set -uo pipefail

REQUIRED="${VISUAL_REQUIRED_CMDS:-node npx}"

remediation_for() {
  case "$1" in
    node)       echo "Install Node.js 20+ from https://nodejs.org or a version manager (nvm/fnm/volta). Do NOT let an agent install it." ;;
    npx)        echo "npx ships with Node.js — installing Node provides it." ;;
    playwright) echo "Add Playwright to the project yourself, once: 'npm i -D @playwright/test' then 'npx playwright install --with-deps'." ;;
    *)          echo "Install '$1' and ensure it is on PATH." ;;
  esac
}

missing=""
for cmd in $REQUIRED; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

if [ -n "$missing" ]; then
  echo "✗ Visual-testing prerequisites missing:"
  for cmd in $missing; do
    printf '  - %s — %s\n' "$cmd" "$(remediation_for "$cmd")"
  done
  echo "No install was attempted. Set these up yourself, then re-run /visual-setup."
  exit 1
fi

echo "✓ Visual-testing prerequisites present: $REQUIRED"
exit 0
