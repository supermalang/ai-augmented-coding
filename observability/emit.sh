#!/usr/bin/env bash
# emit.sh — vendor-neutral runtime-observability emit entrypoint.
#
# The ONE call site a project's app/deploy uses to emit a runtime signal. Three kinds:
#   emit.sh error  <message> [context]   — a structured runtime error
#   emit.sh metric <name> <value>        — a key metric sample
#   emit.sh deploy <version> [env]       — a deploy/version marker
#
# INERT WHEN OFF (the whole point): if `.claude/context.md` → Observability (runtime) → Enabled is not
# truthy, this exits 0 IMMEDIATELY — before reading the Sink, before sourcing any adapter, before
# loading any dependency. No output, no cost. With the flag off the template behaves exactly as if
# observability did not exist.
#
# VENDOR-NEUTRAL: when enabled, the event is handed to the project's chosen adapter (the `Sink`
# command from context.md). No monitoring vendor is baked in here — see observability/adapters/.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONTEXT_FILE="${OBS_CONTEXT_FILE:-$ROOT/.claude/context.md}"

# Read a "- **<Key>:** <value>" line from the "## Observability (runtime)" section of context.md.
# Pure bash (no grep/sed/jq) so it can't fail on a missing tool. Prints $2 (default) if not found.
# Stops at the next "## " heading so it never reads a key from another section.
obs_flag() {
  local key="$1" default="${2:-}" insection=0 line val=""
  [ -f "$CONTEXT_FILE" ] || { printf '%s' "$default"; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '## Observability (runtime)'*) insection=1; continue ;;
    esac
    if [ "$insection" -eq 1 ]; then
      case "$line" in
        '## '*) break ;;                      # next section → stop
        *"**$key:**"*)
          val="${line#*"**$key:**"}"          # text after the key
          val="${val%%#*}"                     # drop trailing "# comment"
          val="${val#"${val%%[![:space:]]*}"}" # ltrim
          val="${val%"${val##*[![:space:]]}"}" # rtrim
          printf '%s' "$val"
          return 0 ;;
      esac
    fi
  done < "$CONTEXT_FILE"
  printf '%s' "$default"
}

is_truthy() { case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in true|1|yes|on) return 0 ;; *) return 1 ;; esac; }

# ── The inert gate: OFF → no-op, nothing loaded ───────────────────────────────
ENABLED="$(obs_flag Enabled false)"
is_truthy "$ENABLED" || exit 0

# ── Enabled path ──────────────────────────────────────────────────────────────
KIND="${1:-}"
shift || true
[ -n "$KIND" ] || { echo "observability: usage: emit.sh <error|metric|deploy> …" >&2; exit 64; }

SINK="$(obs_flag Sink '')"
# A `[CONFIGURE …]` placeholder means the project enabled the flag but hasn't wired a sink yet.
case "$SINK" in
  ''|'['*)
    echo "⚠️  observability: Enabled but no Sink configured (context.md → Observability → Sink). Event dropped: $KIND $*" >&2
    exit 0 ;;
esac

# Hand the structured event to the project's adapter (the Sink command). The adapter — not this file —
# owns the vendor specifics; see observability/adapters/. Event is passed as: <kind> <args…>.
exec "$SINK" "$KIND" "$@"
