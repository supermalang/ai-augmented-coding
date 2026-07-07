#!/usr/bin/env bash
# Block AGENTS from re-baselining visual snapshots.
#
# Only a human at the terminal may bless baselines. An agent
# that could run `playwright test --update-snapshots` could silently accept a visual
# regression — so this denies that invocation when issued through the Bash tool. Agents
# READ approval state via /visual-review; they never create it.
#
# PURE BASH (builtins only via _hooklib.sh) — no jq/grep/git, so it can't fail OPEN because
# a tool is missing from PATH or the shebang got CRLF-mangled. That tool-independence is the
# fail-closed guarantee that matters for a hard-block gate.
#
# HONEST LIMIT: inspects the command STRING only. A re-baseline performed inside a script
# file is invisible here (same limit as guard-bash-write). The real boundary for that is
# least-privilege agent tools — a human blesses at their own terminal, outside the agent's Bash.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

hook_load_profile
hook_read_stdin
cmd="$(hook_field command)"
[ -z "$cmd" ] && exit 0   # nothing parseable → don't block all Bash (matches guard-bash-write)

TOOL_RE="${STACK_VISUAL_TOOL_PATTERN:-playwright[[:space:]]+test}"
UPDATE_RE="${STACK_VISUAL_UPDATE_PATTERN:---update-snapshots|(^|[[:space:]])-u([[:space:]]|$)}"

# Both must hold: the command is the capture INVOCATION (`playwright test`) AND carries an
# update flag. Matching the subcommand (not bare `playwright`) means a commit message or doc
# that merely mentions --update-snapshots won't false-trip; and unrelated `-u` usages
# (sort -u, git push -u) never match.
if [[ $cmd =~ $TOOL_RE ]] && [[ $cmd =~ $UPDATE_RE ]]; then
  hook_deny "🚫 VISUAL GATE: re-baselining screenshots (--update-snapshots) is a HUMAN action, not an agent one — it would silently accept whatever the code now renders. Agents read approval state via /visual-review; they do not bless baselines. A human runs --update-snapshots at the terminal, then commits the PNGs."
fi

exit 0
