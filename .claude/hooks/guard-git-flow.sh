#!/usr/bin/env bash
# guard-git-flow.sh — enforce branch → PR → develop → release. Deny commits/pushes
# that would land directly on the protected branch (main).
# PURE BASH (builtins only; branch read from .git/HEAD) — no jq/git/grep dependency.
set -uo pipefail
. "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/hooks/_hooklib.sh"

PROTECTED="main"
hook_read_stdin
cmd="$(hook_field command)"

# Fast path: ignore anything that isn't a git command.
[[ $cmd == *git* ]] || exit 0

branch="$(hook_git_branch)"

# --- Block commits made while on the protected branch -----------------------
if [[ $cmd =~ (^|[[:space:]])commit([[:space:]]|$) ]]; then
  if [ "$branch" = "$PROTECTED" ]; then
    hook_deny "Refus de committer sur '$PROTECTED' (branche de production). Workflow : crée une branche de feature depuis develop — git switch develop && git switch -c <type>/<description> — puis committe et ouvre une PR/MR vers develop. (Blocked: committing directly on '$PROTECTED'. Branch from develop and open a PR targeting develop instead.)"
  fi
  case "$branch" in
    main|master|develop|feature/*|fix/*|chore/*|hotfix/*|release/*|refactor/*|test/*|docs/*|ci/*|"") ;;
    *)
      printf '⚠️  BRANCH NAME : la branche "%s" ne suit pas la convention de nommage.\nConvention : feature/<description>, fix/<description>, chore/<description>, hotfix/<description>.\n' "$branch"
      ;;
  esac
fi

# --- Block pushing the protected branch -------------------------------------
if [[ $cmd =~ (^|[[:space:]])push([[:space:]]|$) ]]; then
  if [[ $cmd =~ (^|[[:space:]:+])main([[:space:]]|$) ]]; then
    hook_deny "Refus de pousser vers '$PROTECTED'. Pousse ta branche feature et ouvre une PR/MR vers develop : git push -u origin <branche> puis gh pr create --base develop (GitHub) ou glab mr create --target-branch develop (GitLab). (Blocked: pushing to '$PROTECTED'. Push your feature branch and open a PR targeting develop.)"
  fi
  if [ "$branch" = "$PROTECTED" ]; then
    hook_deny "Tu es sur '$PROTECTED' — un 'git push' nu mettrait à jour la production. Branche depuis develop, committe, et ouvre une PR vers develop. (Blocked: bare push from '$PROTECTED' would update production. Branch from develop and open a PR targeting develop.)"
  fi
fi

exit 0
