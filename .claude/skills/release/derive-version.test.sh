#!/usr/bin/env bash
# Tests for derive-version.sh — semver bump from conventional commits.
# Run: bash .claude/skills/release/derive-version.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DV="$HERE/derive-version.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  ✗ %s (got: %s)\n' "$1" "$2"; }

# derive(current, commit-lines...) → runs the helper over the given commits via stdin.
derive() { local cur="$1"; shift; printf '%s\n' "$@" | bash "$DV" --stdin --current "$cur"; }
expect() { local want="$1" got="$2" name="$3"; [ "$got" = "$want" ] && ok "$name → $got" || bad "$name (want '$want')" "$got"; }

expect "patch 1.2.4" "$(derive 1.2.3 'fix: correct off-by-one')" "fix → patch"
expect "minor 1.3.0" "$(derive 1.2.3 'feat: add export button' 'fix: tidy')" "feat present → minor (beats fix)"
expect "major 2.0.0" "$(derive 1.2.3 'feat!: drop legacy API')" "feat! → major"
expect "major 2.0.0" "$(derive 1.2.3 'refactor: rework' 'BREAKING CHANGE: config renamed')" "BREAKING CHANGE body → major"
expect "none 1.2.3"  "$(derive 1.2.3 'docs: tweak readme' 'chore: bump dep')" "only docs/chore → no bump"
expect "patch 1.2.4" "$(derive 1.2.3 'fix(scope): scoped fix')" "scoped fix → patch"
expect "major 1.0.0" "$(derive 0.4.2 'feat!: first stable')" "0.x feat! → 1.0.0"
expect "minor 0.1.0" "$(derive 0.0.0 'feat: initial feature')" "from 0.0.0, feat → 0.1.0"
# precedence: a breaking change anywhere wins regardless of order
expect "major 2.0.0" "$(derive 1.2.3 'fix: a' 'feat: b' 'feat!: c')" "mixed with a breaking → major"

echo
echo "derive-version.test.sh — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
