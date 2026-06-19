#!/usr/bin/env bash
# guard-expose-hash.sh — warn when sensitive fields may be exposed in an API response.
#
# Wired as PostToolUse(Edit) and PostToolUse(Write) in settings.json.
# Scans written content for patterns that could leak sensitive data.
#
# EXAMPLE: adapt to your project's sensitive field names (password hash, tokens, secrets).
# Replace the grep pattern below with the field names that must never appear in an
# API response body — e.g. `passwordHash`, `hashedPassword`, `apiSecret`,
# `refreshToken`, `privateKey`, etc. Add one grep per sensitive field family,
# or combine them into a single alternation pattern.
#
# Test files (*.test.ts, *.spec.ts) are excluded.

set -uo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

case "$file_path" in
  *.test.ts | *.spec.ts) exit 0 ;;
esac

content=$(printf '%s' "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')

# EXAMPLE: adapt to your project's sensitive field names (password hash, tokens, secrets).
# The pattern below catches a field being selected as `true` in a Prisma select block,
# or included in a response/return object. Extend the alternation with your own fields:
#   passwordHash|hashedPassword|apiSecret|refreshToken|privateKey
if printf '%s' "$content" | grep -Eq '(passwordHash|hashedPassword|apiSecret|refreshToken|privateKey)\s*:\s*true|(passwordHash|hashedPassword|apiSecret|refreshToken|privateKey)[^:=]*(,|\})'; then
  printf '⚠️  SENSITIVE FIELD EXPOSURE: a sensitive field (password hash, token, or secret) was detected in "%s". Never include these fields in API responses — exclude them explicitly with `select` or delete them from the result object before returning.\n' "$file_path"
fi

exit 0
