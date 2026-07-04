#!/usr/bin/env bash
# remind-code-map.sh — nudge to regenerate the code map when a new module/area appears.
#
# Wired as PostToolUse(Edit|Write) in settings.json.
# The code map (.claude/code-map.md) is a machine-generated router index that /planner and
# /locate read before grepping the tree. Pure edits inside an existing file don't change the
# map's structure, so this only fires when a written CODE file belongs to an AREA the map
# doesn't yet list — the "a new module was added / moved" signal. Renames/deletes won't trip
# it; it's a nudge, not a gate. Regenerate with /code-map.

set -uo pipefail

PROFILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/hooks/stack-profile.sh"
[ -f "$PROFILE" ] && . "$PROFILE"

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[ -z "$file_path" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -n "$project_dir" ]; then
  rel_path="${file_path#${project_dir}/}"
else
  rel_path="$file_path"
fi
rel_path="${rel_path#./}"

# Only care about code files under the gated implementation paths.
printf '%s' "$rel_path" | grep -Eq "${STACK_GATED_PATHS_REGEX:-^(src/|tests/|prisma/schema\.prisma)}" || exit 0
printf '%s' "$rel_path" | grep -Eq '\.(ts|tsx|js|jsx|mjs|cjs|vue|svelte|astro|py|go|rb|php|java|kt|kts|rs|scala|swift|c|cc|cpp|cxx|h|hpp|cs|ex|exs|dart)$' || exit 0

map="${project_dir:-$(pwd)}/.claude/code-map.md"
[ -f "$map" ] || exit 0   # no map yet → nothing to compare against

# Area = first two path segments (matches generate.mjs --depth 2 default).
IFS='/' read -r s1 s2 _rest <<< "$rel_path"
if [ -n "${_rest:-}" ] || { [ -n "$s2" ] && [ "$s2" != "$rel_path" ]; }; then
  area="${s1}/${s2}"
else
  area="$s1"
fi

# If the map already lists this area (as `area`), no structural change — stay quiet.
if grep -qF "\`${area}\`" "$map"; then
  exit 0
fi

printf '🗺️  New code area "%s" is not in the code map (.claude/code-map.md) — regenerate it so /planner and /locate can route to it: `/code-map` (or `%s`).\n' "$area" "${STACK_CODE_MAP_CMD:-node .claude/skills/code-map/generate.mjs}"
exit 0
