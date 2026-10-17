#!/usr/bin/env bash
#
# Test gate for the manuscript's Bynk snippet projects.
#
# The compile gate (scripts/check-book-snippets.sh) type-checks a project's
# tests/ along with its sources, but nothing there runs them: a case can fail
# while CI stays green, and the book prints its suite as passing. This runs
# `bynkc test .` in every project that has a tests/ directory and fails if any
# case does. The deliberately rejected `fail` fixtures in
# snippets/EXPECTATIONS.tsv are skipped: they do not compile.
#
# Where a chapter quotes a run, snippets/TRANSCRIPTS.tsv names the transcript
# (kind `test`), and the output from `Running tests...` on must match it
# exactly. Anything before that line is the compile step's and is not quoted.
#
# A project whose adapter binding is TypeScript can test the binding as
# TypeScript, in tests/bindings/*.test.cjs, against the out-js/ build that
# `bynkc test` leaves behind; a Bynk test can't reach a binding at 0.330.4
# (bynk-lang/bynk#1975). Those run with `node --test` after the suite passes.
#
# Each project runs on a copy with no out/ or out-js/, so a stale runner never
# answers for the current sources and the checkout is left untouched.
#
# `bynkc test` needs `tsc` and `node` on PATH.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPETS="$ROOT/snippets"
MANIFEST="$SNIPPETS/EXPECTATIONS.tsv"
TRANSCRIPTS="$SNIPPETS/TRANSCRIPTS.tsv"

BYNKC="${BYNKC:-$(command -v bynkc || true)}"
if [ -z "$BYNKC" ] || [ ! -x "$BYNKC" ]; then
  echo "bynkc not found on PATH. Install the Bynk toolchain (see README.md)," >&2
  echo "or set BYNKC=/path/to/bynkc." >&2
  exit 2
fi
printf 'Running snippet tests with %s\n\n' "$("$BYNKC" --version 2>/dev/null || printf '%s' "$BYNKC")"

# The `test` transcripts quoted from a project, one path per line.
transcripts_of() {
  awk -F'\t' -v p="$1" \
    '$0 !~ /^[[:space:]]*(#|$)/ && $2 == "test" && $3 == p { print $1 }' \
    "$TRANSCRIPTS"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail=0
checked=0
skipped=0
quoted=0
seen=""
while IFS= read -r toml; do
  dir="$(dirname "$toml")"
  rel="${dir#"$SNIPPETS"/}"
  [ -d "$dir/tests" ] || continue

  kind="$(awk -F'\t' -v p="$rel" '$1 == p { print $2; exit }' "$MANIFEST")"
  if [ "$kind" = fail ]; then
    printf '  skip  %-42s rejected fixture\n' "$rel"
    skipped=$((skipped + 1))
    continue
  fi
  checked=$((checked + 1))
  seen="$seen$rel"$'\n'

  copy="$work/${rel//\//__}"
  mkdir -p "$copy" && cp -R "$dir/." "$copy/"
  rm -rf "$copy/out" "$copy/out-js"

  out="$(cd "$copy" && NO_COLOR=1 "$BYNKC" test . 2>&1)"
  rc=$?
  run="$(printf '%s\n' "$out" | sed -n '/^Running tests\.\.\.$/,$p')"
  summary="$(printf '%s\n' "$run" | grep -E '^[0-9]+ passed, [0-9]+ failed\.$' | tail -n 1)"

  problem=""
  if [ "$rc" -ne 0 ]; then
    problem="bynkc test exited $rc"
  elif [ -z "$summary" ]; then
    problem="no test summary in the output"
  elif ! printf '%s' "$summary" | grep -q ' 0 failed\.$'; then
    problem="a case failed"
  fi
  if [ -z "$problem" ] && compgen -G "$copy/tests/bindings/*.test.cjs" >/dev/null; then
    if ! out="$(cd "$copy" && node --test tests/bindings/*.test.cjs 2>&1)"; then
      problem="a binding test failed"
    else
      summary="$summary $(printf '%s\n' "$out" | sed -n 's/^ℹ pass \([0-9]*\)$/\1/p') binding tests passed."
    fi
  fi
  if [ -n "$problem" ]; then
    printf 'FAIL    %-42s %s\n' "$rel" "$problem"
    printf '%s\n' "$out" | sed 's/^/          | /'
    fail=1
    continue
  fi

  stale=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    quoted=$((quoted + 1))
    if [ ! -f "$SNIPPETS/$t" ]; then
      stale="$stale$t: listed in TRANSCRIPTS.tsv but missing"$'\n'
    elif ! d="$(diff -u --label "$t (quoted)" --label "$t (bynkc test)" \
      "$SNIPPETS/$t" <(printf '%s\n' "$run"))"; then
      stale="$stale$t: the quoted run no longer matches"$'\n'"$d"$'\n'
    fi
  done < <(transcripts_of "$rel")
  if [ -n "$stale" ]; then
    printf 'FAIL    %-42s %s\n' "$rel" "transcript out of date"
    printf '%s' "$stale" | sed 's/^/          | /'
    fail=1
  else
    printf '  ok    %-42s %s\n' "$rel" "$summary"
  fi
done < <(find "$SNIPPETS" -name bynk.toml | sort)

# A `test` row for a project this loop never ran is checking nothing.
while IFS=$'\t' read -r t k p; do
  case "$t" in '' | \#*) continue ;; esac
  [ "$k" = test ] || continue
  if ! printf '%s' "$seen" | grep -qxF "$p"; then
    printf 'FAIL    %-42s %s\n' "$t" "TRANSCRIPTS.tsv names $p, which has no tests/ to run"
    fail=1
  fi
done < "$TRANSCRIPTS"

echo
if [ "$fail" -eq 0 ]; then
  echo "All $checked tested snippet projects pass, and $quoted quoted runs match."
  echo "($skipped rejected fixtures skipped.)"
else
  echo "Some snippet tests failed, or a quoted run no longer matches."
  echo "Fix the case, or regenerate the transcript from \`bynkc test .\`."
fi
exit "$fail"
