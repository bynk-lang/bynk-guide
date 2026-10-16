#!/usr/bin/env bash
#
# Gate for the compiler output the chapters quote.
#
# A chapter that shows what `bynkc compile` generates, a wrangler.toml or a line
# of a handler's TypeScript, prints a copy of it. The emit gate
# (scripts/check-book-emit.sh) proves that output type-checks, but nothing holds
# the copy to it: a release that changes the code generator makes the page wrong
# while every gate stays green. This compiles each project named by an `emit`
# row of snippets/TRANSCRIPTS.tsv for the row's target and diffs the quoted
# file against the generated one.
#
# A row quotes either a whole generated file, compared byte for byte, or the
# lines of it a match selects: every line containing <from>, or with <to> too,
# the first line containing <from> through the next line containing <to>. The
# matches are fixed strings, not patterns. Selected lines lose the indentation
# they share, since a page prints an excerpt flush left.
#
# Each project compiles on a copy with no out/, out-js/ or .bynk/: `bynkc
# compile` writes bynk.schema.lock into the project, and a stale out/ must never
# answer for the current sources.
#
# The compiler is whichever `bynkc` is on PATH; override with
# BYNKC=/path/to/bynkc.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPETS="$ROOT/snippets"
TRANSCRIPTS="$SNIPPETS/TRANSCRIPTS.tsv"

BYNKC="${BYNKC:-$(command -v bynkc || true)}"
if [ -z "$BYNKC" ] || [ ! -x "$BYNKC" ]; then
  echo "bynkc not found on PATH. Install the Bynk toolchain (see README.md)," >&2
  echo "or set BYNKC=/path/to/bynkc." >&2
  exit 2
fi
printf 'Checking quoted compiler output against %s\n\n' \
  "$("$BYNKC" --version 2>/dev/null || printf '%s' "$BYNKC")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Prints the lines of file $1 the matches $2 (and $3) select, with their common
# leading indentation removed. A range whose <to> never follows selects nothing.
select_lines() {
  awk -v from="$2" -v to="$3" '
    function keep() {
      line[++n] = $0
      if ($0 ~ /[^[:space:]]/) {
        match($0, /^[[:space:]]*/)
        if (min == "" || RLENGTH < min) min = RLENGTH
      }
    }
    to == "" { if (index($0, from)) keep(); next }
    !on && index($0, from) { on = 1; keep(); next }
    on { keep(); if (index($0, to)) { closed = 1; exit } }
    END {
      if (to != "" && !closed) exit
      for (i = 1; i <= n; i++) print substr(line[i], min + 1)
    }
  ' "$1"
}

fail=0
checked=0
while IFS=$'\t' read -r t k p target path from to; do
  case "$t" in '' | \#*) continue ;; esac
  [ "$k" = emit ] || continue
  checked=$((checked + 1))

  if [ -z "${target:-}" ] || [ -z "${path:-}" ]; then
    printf 'FAIL    %-42s %s\n' "$t" "an emit row needs a target and a path under out/"
    fail=1
    continue
  fi
  if [ ! -f "$SNIPPETS/$t" ] || [ ! -f "$SNIPPETS/$p/bynk.toml" ]; then
    printf 'FAIL    %-42s %s\n' "$t" "transcript or project $p missing"
    fail=1
    continue
  fi

  # Rows quoting the same project and target share one compile.
  copy="$work/${p//\//__}__$target"
  if [ ! -d "$copy" ]; then
    mkdir -p "$copy" && cp -R "$SNIPPETS/$p/." "$copy/"
    rm -rf "$copy/out" "$copy/out-js" "$copy/.bynk"
    if ! out="$(cd "$copy" && NO_COLOR=1 "$BYNKC" compile . --output out --target "$target" 2>&1)"; then
      printf 'FAIL    %-42s %s\n' "$t" "$p does not compile for $target"
      printf '%s\n' "$out" | sed 's/^/          | /'
      rm -rf "$copy"
      fail=1
      continue
    fi
  fi

  generated="$copy/out/$path"
  if [ ! -f "$generated" ]; then
    printf 'FAIL    %-42s %s\n' "$t" "bynkc compile --target $target wrote no out/$path"
    fail=1
    continue
  fi

  what="out/$path"
  if [ -n "${from:-}" ]; then
    excerpt="$work/excerpt"
    select_lines "$generated" "$from" "${to:-}" >"$excerpt"
    if [ ! -s "$excerpt" ]; then
      printf 'FAIL    %-42s %s\n' "$t" "the match selects no lines of out/$path"
      fail=1
      continue
    fi
    generated="$excerpt"
    what="$what, lines from \"$from\"${to:+ to \"$to\"}"
  fi

  if d="$(diff -u --label "$t (quoted)" --label "out/$path ($target)" \
    "$SNIPPETS/$t" "$generated")"; then
    printf '  ok    %-42s %s\n' "$t" "$what"
  else
    printf 'FAIL    %-42s %s\n' "$t" "the quoted output no longer matches"
    printf '%s\n' "$d" | sed 's/^/          | /'
    fail=1
  fi
done < "$TRANSCRIPTS"

echo
if [ "$fail" -eq 0 ]; then
  echo "All $checked quoted pieces of compiler output match what bynkc compile writes."
else
  echo "Some quoted compiler output no longer matches. Copy the chapter's file"
  echo "again from \`bynkc compile\` at this release."
fi
exit "$fail"
