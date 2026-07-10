#!/usr/bin/env bash
# webhook adapter — POST a JSON event to a vendor-agnostic HTTP endpoint.
# Works with any sink that accepts a JSON webhook (log platform, incident tool, your own collector).
# Set `Sink: observability/adapters/webhook.sh` in context.md and export OBS_WEBHOOK_URL to use it.
#
# Invoked by emit.sh as:  webhook.sh <kind> <args…>   (only when Observability is Enabled).
# Never commit the URL/token — read it from the environment.
set -uo pipefail

URL="${OBS_WEBHOOK_URL:-}"   # [CONFIGURE] endpoint — env var, not committed
if [ -z "$URL" ]; then
  echo "⚠️  observability/webhook: OBS_WEBHOOK_URL not set — event dropped: $*" >&2
  exit 0
fi

kind="${1:-unknown}"; shift || true
esc() { local s="${1:-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; printf '%s' "$s"; }
payload="$(printf '{"kind":"%s","event":"%s"}' "$(esc "$kind")" "$(esc "$*")")"

# curl if present; the adapter is the only place a transport tool is assumed.
if command -v curl >/dev/null 2>&1; then
  curl -fsS -X POST -H 'Content-Type: application/json' -d "$payload" "$URL" >/dev/null \
    || echo "⚠️  observability/webhook: POST failed (non-fatal) — $payload" >&2
else
  echo "⚠️  observability/webhook: curl not found — event dropped: $payload" >&2
fi
exit 0
