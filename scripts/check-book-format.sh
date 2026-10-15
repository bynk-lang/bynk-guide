#!/usr/bin/env bash
#
# Formatting gate for the manuscript's Bynk snippet projects.
#
# Every listing in the book is typeset from the file on disk — the chapters
# `read()` the snippet sources directly — so a snippet's whitespace is printed
# whitespace. The compile gate (scripts/check-book-snippets.sh) proves each
# listing is the program its chapter claims; it says nothing about how that
# program is laid out. Without this gate a hand-edited snippet drifts from
# canonical Bynk and the book prints non-idiomatic code while CI stays green.
#
# This runs `bynkc fmt --check` over the snippet projects that are expected to
# compile: every project not listed in snippets/EXPECTATIONS.tsv, plus the ones
# listed there as `warn`. The deliberately-rejected `fail` projects are skipped
# — they exist to be refused, and a future negative fixture may not parse at
# all, which the formatter cannot process. Their listings are printed in the
# book too, so that exemption is a real (small) hole, not a claim of coverage.
#
# The file list is enumerated here rather than delegated to project discovery:
# `bynkc fmt` accepted only files, not directories, before Bynk 0.307.0. `--check` writes nothing: it
# exits non-zero and names each file that is not already canonical.
#
# Chapters 1-8 predate the formatter and are not canonical yet. They cannot
# simply be reformatted: six chapters print listings by slicing hard-coded line
# ranges out of these files (`source-lines(path, start, end)`), and formatting
# shifts those lines — it breaks the Typst build where a range runs off the end
# of a file, and silently prints the wrong lines where it does not. So the
# projects still to be reformatted are listed in snippets/FORMAT-BASELINE and
# reported without failing.
#
# The baseline is a ratchet, not an exemption list: a baselined project that
# has become canonical *fails*, with a note to delete its line. It can only
# shrink, and everything outside it is gated from today.
#
# The compiler is whichever `bynkc` is on PATH; override with
# BYNKC=/path/to/bynkc. In CI, bynk-lang/setup-bynk installs a pinned release.
# The formatter ships with the compiler, so canonical layout is defined by the
# same release the diagnostics are quoted from — its version is printed below.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPETS="$ROOT/snippets"
MANIFEST="$SNIPPETS/EXPECTATIONS.tsv"
BASELINE="$SNIPPETS/FORMAT-BASELINE"

BYNKC="${BYNKC:-$(command -v bynkc || true)}"
if [ -z "$BYNKC" ] || [ ! -x "$BYNKC" ]; then
  echo "bynkc not found on PATH. Install the Bynk toolchain (see README.md)," >&2
  echo "or set BYNKC=/path/to/bynkc." >&2
  exit 2
fi
printf 'Format-checking snippets with %s\n\n' "$("$BYNKC" --version 2>/dev/null || printf '%s' "$BYNKC")"

is_baselined() {
  [ -f "$BASELINE" ] || return 1
  awk -v p="$1" '$0 !~ /^[[:space:]]*(#|$)/ && $1 == p { found = 1 } END { exit !found }' "$BASELINE"
}

fail=0
gated=0
checked=0
skipped=0
pending=0
formatted=0
project_dirs=()

while IFS= read -r toml; do
  dir="$(dirname "$toml")"
  rel="${dir#"$SNIPPETS"/}"
  project_dirs+=("$dir")

  kind="$(awk -F'\t' -v p="$rel" '$1 == p { print $2; exit }' "$MANIFEST")"
  if [ "$kind" = fail ]; then
    printf '  skip  %-42s rejected fixture\n' "$rel"
    skipped=$((skipped + 1))
    continue
  fi

  files=()
  while IFS= read -r bynk; do
    files+=("$bynk")
  done < <(find "$dir" -type f -name '*.bynk' | sort)

  if [ "${#files[@]}" -eq 0 ]; then
    printf 'FAIL    %-42s %s\n' "$rel" "project contains no .bynk sources"
    fail=1
    continue
  fi

  gated=$((gated + 1))
  out="$("$BYNKC" fmt --check "${files[@]}" 2>&1)"
  rc=$?

  if is_baselined "$rel"; then
    if [ "$rc" -eq 0 ]; then
      printf 'FAIL    %-42s %s\n' "$rel" "now canonical — delete its line from FORMAT-BASELINE"
      fail=1
    else
      printf '  todo  %-42s %s\n' "$rel" "not canonical yet (baselined)"
      pending=$((pending + 1))
    fi
  elif [ "$rc" -eq 0 ]; then
    printf '  ok    %-42s %d file(s)\n' "$rel" "${#files[@]}"
    checked=$((checked + 1))
    formatted=$((formatted + ${#files[@]}))
  else
    printf 'FAIL    %-42s %s\n' "$rel" "not canonically formatted (run: bynkc fmt <file>)"
    printf '%s\n' "$out" | sed "s|$ROOT/||g; s|^|          \| |"
    fail=1
  fi
done < <(find "$SNIPPETS" -name bynk.toml | sort)

if [ "$gated" -eq 0 ]; then
  echo "FAIL    found no snippet projects to format-check under $SNIPPETS" >&2
  fail=1
fi

# A `.bynk` file outside every project is a listing no gate compiles and no gate
# formats. Neither script would otherwise notice it, because both enumerate work
# from bynk.toml.
while IFS= read -r bynk; do
  owned=0
  for dir in ${project_dirs+"${project_dirs[@]}"}; do
    case "$bynk" in "$dir"/*) owned=1; break ;; esac
  done
  if [ "$owned" -eq 0 ]; then
    printf 'FAIL    %-42s %s\n' "${bynk#"$SNIPPETS"/}" "not part of any snippet project"
    fail=1
  fi
done < <(find "$SNIPPETS" -type f -name '*.bynk' | sort)

echo
if [ "$fail" -eq 0 ]; then
  echo "All $formatted .bynk files in $checked snippet projects are canonically formatted."
  echo "($skipped rejected fixtures skipped; $pending baselined projects still to reformat.)"
else
  echo "Some snippet sources did not pass the formatting gate."
fi
exit "$fail"
