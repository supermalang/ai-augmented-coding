#!/usr/bin/env bash
# remind-docs-generate.sh — remind to run docs:generate after schema or API changes.
#
# Wired as PostToolUse(Edit) and PostToolUse(Write) in settings.json.
# Triggers when prisma/schema.prisma or any file under src/app/api/ is written,
# since those are the two sources that feed the *.generated.md doc files.

set -uo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

# Strip the project root prefix to get a repo-relative path for matching.
project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -n "$project_dir" ]; then
  rel_path="${file_path#${project_dir}/}"
else
  rel_path="$file_path"
fi

case "$rel_path" in
  prisma/schema.prisma | src/app/api/*)
    printf '⚠️  CONTRIBUTING reminder: "%s" a été modifié — pense à lancer `npm run docs:generate` pour régénérer api-reference.generated.md et modele-donnees.generated.md avant d'\''ouvrir une PR.\n' "$rel_path"
    ;;
esac

exit 0
