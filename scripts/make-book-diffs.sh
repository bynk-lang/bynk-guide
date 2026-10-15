#!/usr/bin/env bash
#
# Generate the diffs the manuscript prints, from the snippet projects they
# compare.
#
# A chapter that shows a program changing prints a unified diff between two
# snippet projects. Typst can only read files, so the diffs are checked in
# under snippets/. This script writes them from snippets/DIFFS.tsv, so a printed
# diff is always the real difference between two compile-tested projects:
#
#   ./scripts/make-book-diffs.sh          # rewrite every diff
#   ./scripts/make-book-diffs.sh --check  # fail if any checked-in diff is stale
#
# CI runs --check, so editing a snippet without regenerating its diffs fails
# the build, as a shifted source-lines range would if it could be detected.
#
# Manifest columns (tab-separated), paths relative to snippets/:
#   <output .diff>  <from project>  <to project>  <file in project>  <hunks>
# <hunks> is "all", or a comma-separated list of 1-based hunk numbers to keep,
# for a chapter that discusses one part of a larger change.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPETS="$ROOT/snippets"
MANIFEST="$SNIPPETS/DIFFS.tsv"

check=0
case "${1:-}" in
"") ;;
--check) check=1 ;;
*)
  echo "usage: $0 [--check]" >&2
  exit 2
  ;;
esac

# Unified diff with stable labels: no paths outside the project, and no
# timestamps.
render() {
  local from="$1" to="$2" file="$3"
  diff -u --label "a/$file" --label "b/$file" \
    "$SNIPPETS/$from/$file" "$SNIPPETS/$to/$file"
  [ $? -le 1 ] || return 2
}

select_hunks() {
  local hunks="$1"
  if [ "$hunks" = "all" ]; then
    cat
    return
  fi
  awk -v keep=",$hunks," '
    NR <= 2 { print; next }
    /^@@ / { hunk++ }
    index(keep, "," hunk ",") { print }
  '
}

stale=0
written=0
while IFS=$'\t' read -r output from to file hunks; do
  case "$output" in "" | \#*) continue ;; esac
  for project in "$from" "$to"; do
    if [ ! -f "$SNIPPETS/$project/$file" ]; then
      echo "DIFFS.tsv: no $file in $project (for $output)" >&2
      exit 2
    fi
  done

  rendered="$(render "$from" "$to" "$file" | select_hunks "$hunks")"
  if [ -z "$rendered" ]; then
    echo "DIFFS.tsv: $from and $to do not differ in $file (for $output)" >&2
    exit 2
  fi

  target="$SNIPPETS/$output"
  if [ "$check" -eq 1 ]; then
    if [ ! -f "$target" ] || [ "$(cat "$target")" != "$rendered" ]; then
      printf '  stale %s\n' "$output"
      stale=$((stale + 1))
    else
      printf '  ok    %s\n' "$output"
    fi
  else
    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$rendered" >"$target"
    printf '  wrote %s\n' "$output"
    written=$((written + 1))
  fi
done <"$MANIFEST"

if [ "$check" -eq 1 ]; then
  if [ "$stale" -gt 0 ]; then
    echo
    echo "$stale printed diff(s) no longer match their snippet projects."
    echo "Run ./scripts/make-book-diffs.sh and commit the result."
    exit 1
  fi
  echo
  echo "Every printed diff matches its snippet projects."
fi
