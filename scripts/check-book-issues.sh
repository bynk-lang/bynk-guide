#!/usr/bin/env bash
#
# The appendix in backmatter/issues.typ lists every bynk-lang/bynk issue or
# pull request the chapters cite. This fails if a chapter cites one the
# appendix doesn't list, or the appendix lists one no chapter cites, so the
# two can't drift apart as chapters are revised. It doesn't check an issue's
# state; that is a dated snapshot, refreshed by hand when the pin moves.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cited="$(grep -o -h '#[0-9]\{4\}' "$ROOT"/chapters/*.typ | tr -d '#' | sort -u)"
listed="$(grep -o '^[[:space:]]*\[[0-9]\{4\}\],' "$ROOT/backmatter/issues.typ" |
  tr -dc '0-9\n' | sort -u)"

missing="$(comm -23 <(printf '%s\n' "$cited") <(printf '%s\n' "$listed"))"
extra="$(comm -13 <(printf '%s\n' "$cited") <(printf '%s\n' "$listed"))"

fail=0
for n in $missing; do
  echo "FAIL  #$n is cited in a chapter but missing from backmatter/issues.typ"
  fail=1
done
for n in $extra; do
  echo "FAIL  #$n is listed in backmatter/issues.typ but no chapter cites it"
  fail=1
done
if [ "$fail" -eq 0 ]; then
  echo "Every cited issue ($(printf '%s\n' "$cited" | grep -c .)) is listed in the appendix."
fi
exit "$fail"
