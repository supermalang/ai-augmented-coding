#!/usr/bin/env bash
# remind-docker-rebuild.sh — remind to rebuild the Docker app image after a migration.
#
# Wired as PostToolUse(Write) in settings.json.
# Triggers when a new file is written under prisma/migrations/.
#
# The Prisma client is frozen in the Docker image at build time (npx prisma generate
# runs in the Dockerfile). After any migration, the app container must be rebuilt or
# it will crash with "The column ... does not exist" in Server Components.

set -uo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -n "$project_dir" ]; then
  rel_path="${file_path#${project_dir}/}"
else
  rel_path="$file_path"
fi

case "$rel_path" in
  prisma/migrations/*)
    printf '⚠️  New migration file: "%s" — the Prisma client is frozen in the Docker image. In production, rebuild the app container after applying the migration: `docker compose up -d --build app` — otherwise Server Components crash with "column does not exist".\n' "$rel_path"
    ;;
esac

exit 0
