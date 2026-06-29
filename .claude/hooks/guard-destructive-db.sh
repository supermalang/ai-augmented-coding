#!/usr/bin/env bash
# guard-destructive-db.sh — deny commands that irreversibly wipe the database.
# PURE BASH (builtins only) so it can't fail open when jq/coreutils are absent.
#
# Blocks: db reset (drop + re-migrate + re-seed), docker down -v/--volumes,
# docker volume rm. Patterns come from stack-profile.sh.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_load_profile
hook_read_stdin
cmd="$(hook_field command)"
[ -z "$cmd" ] && exit 0

DB_RESET_RE="${STACK_DESTRUCTIVE_DB_PATTERN:-npm run db:reset|prisma migrate reset}"

if [[ $cmd =~ $DB_RESET_RE ]]; then
  hook_deny "Commande destructive bloquée : '$cmd' détruit toute la base de données (drop + re-migrate + re-seed). Lance cette commande manuellement si c'est intentionnel. (Destructive: drops and recreates the entire database — run manually if intentional.)"
fi

if [[ $cmd == *docker* && $cmd == *down* ]] && [[ $cmd =~ (^|[[:space:]])-v([[:space:]]|$)|--volumes ]]; then
  hook_deny "Commande destructive bloquée : 'down -v / --volumes' supprime les volumes Docker dont le volume PostgreSQL — toutes les données seront perdues. Lance manuellement si intentionnel. (Destructive: removes Docker volumes including the PostgreSQL data — run manually if intentional.)"
fi

if [[ $cmd =~ docker[[:space:]]+volume[[:space:]]+rm ]]; then
  hook_deny "Commande destructive bloquée : 'docker volume rm' peut supprimer le volume PostgreSQL. Lance manuellement si intentionnel. (Destructive: may remove the PostgreSQL data volume — run manually if intentional.)"
fi

exit 0
