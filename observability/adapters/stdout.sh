#!/usr/bin/env bash
# stdout adapter — prints one structured JSON event line to stdout.
# The simplest reference sink: local dev, or any environment where a log collector scrapes stdout.
# No vendor, no network. Set `Sink: observability/adapters/stdout.sh` in context.md to use it.
#
# Invoked by emit.sh as:  stdout.sh <kind> <args…>   (only when Observability is Enabled).
set -uo pipefail

kind="${1:-unknown}"; shift || true

# JSON-escape a string (quotes, backslashes, control chars) using bash builtins only.
esc() { local s="${1:-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; printf '%s' "$s"; }

# args joined into one context string; kind-specific keys stay simple and stable.
ctx="$(esc "$*")"
printf '{"kind":"%s","event":"%s"}\n' "$(esc "$kind")" "$ctx"
