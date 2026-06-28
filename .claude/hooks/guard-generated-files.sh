#!/usr/bin/env bash
# guard-generated-files.sh — block manual edits to auto-generated doc files.
# PURE BASH (builtins only) — no jq. Glob pattern comes from stack-profile.sh.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_load_profile
hook_read_stdin
file_path="$(hook_field file_path)"
[ -z "$file_path" ] && exit 0

case "$file_path" in
  ${STACK_GENERATED_FILES_GLOB:-*.generated.md})
    hook_deny "Fichier auto-généré — ne pas modifier à la main : ${file_path}. Modifie la source (schema ou route API) puis relance la génération de docs. (Auto-generated — edit the source and regenerate, don't hand-edit.)"
    ;;
esac

exit 0
