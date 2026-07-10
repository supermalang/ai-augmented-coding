#!/usr/bin/env bash
# derive-version.sh — compute the next semver from conventional commits since the last tag.
#
# Leverages the guard-commit-message convention:
#   fix:            → patch      feat:           → minor
#   <type>!:  or  a "BREAKING CHANGE" body line  → major
#   other types (docs/chore/refactor/test/ci/build/style/perf/revert) → no release-worthy bump
#
# Prints one line:  "<level> <next-version>"   e.g.  "minor 1.3.0"   ("none <current>" if no bump).
# Deterministic + side-effect-free (reads git or stdin; writes nothing, tags nothing).
#
# Usage:
#   derive-version.sh                       # commits = <last-tag>..HEAD; current = last tag
#   derive-version.sh --current 1.2.3       # override the current version
#   derive-version.sh --stdin --current X   # read commit SUBJECT+BODY lines from stdin (for tests/CI)
set -uo pipefail

CURRENT=""; USE_STDIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --current) CURRENT="${2:-}"; shift 2 ;;
    --stdin)   USE_STDIN=1; shift ;;
    *) shift ;;
  esac
done

TAG_PREFIX="v"
last_tag=""
if [ -z "$CURRENT" ]; then
  last_tag="$(git describe --tags --abbrev=0 --match "${TAG_PREFIX}*" 2>/dev/null || echo '')"
  CURRENT="${last_tag#$TAG_PREFIX}"
fi
[ -n "$CURRENT" ] || CURRENT="0.0.0"

# Gather the commit text to classify.
if [ "$USE_STDIN" -eq 1 ]; then
  commits="$(cat)"
elif [ -n "$last_tag" ]; then
  commits="$(git log "${last_tag}..HEAD" --format='%s%n%b' 2>/dev/null || echo '')"
else
  commits="$(git log --format='%s%n%b' 2>/dev/null || echo '')"   # no tag yet → whole history
fi

level="none"
bump_to() {  # raise level toward major (major > minor > patch > none)
  case "$1" in
    major) level="major" ;;
    minor) [ "$level" = major ] || level="minor" ;;
    patch) [ "$level" = major ] || [ "$level" = minor ] || level="patch" ;;
  esac
}

while IFS= read -r line || [ -n "$line" ]; do
  # BREAKING CHANGE anywhere in a body line → major.
  case "$line" in
    *"BREAKING CHANGE"*) bump_to major; continue ;;
  esac
  # Conventional subject: type(scope)!: …
  if [[ $line =~ ^([a-zA-Z]+)(\([^\)]*\))?(!)?: ]]; then
    type="${BASH_REMATCH[1]}"; bang="${BASH_REMATCH[3]}"
    if [ -n "$bang" ]; then bump_to major
    else
      case "$type" in
        feat) bump_to minor ;;
        fix)  bump_to patch ;;
      esac
    fi
  fi
done <<< "$commits"

# Apply the bump to CURRENT (major.minor.patch; tolerate a missing component).
IFS='.' read -r MA MI PA <<< "$CURRENT"
MA="${MA:-0}"; MI="${MI:-0}"; PA="${PA:-0}"; MA="${MA//[!0-9]/}"; MI="${MI//[!0-9]/}"; PA="${PA//[!0-9]/}"
case "$level" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
  none)  ;;  # no release-worthy change
esac

printf '%s %d.%d.%d\n' "$level" "$MA" "$MI" "$PA"
