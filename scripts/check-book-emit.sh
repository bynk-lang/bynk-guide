#!/usr/bin/env bash
#
# Emit-gate for the manuscript's Bynk snippet projects.
#
# check-book-snippets.sh runs `bynkc check`, which proves a program is
# accepted. It does not prove the program can be built: a listing can pass
# `check` and still emit TypeScript that `tsc` rejects (accuser/bynk#1818 is one
# such case). A chapter presents its listings as working programs, so this gate
# compiles every project expected to pass, for both topologies the book
# discusses (`bundle` and `workers`), and type-checks the output with
# `tsc --strict` through the tsconfig.json the compiler emits.
#
# The deliberately-rejected `fail` projects in snippets/EXPECTATIONS.tsv are
# skipped; they exist to be refused by `check`. A `build-fail` project is the
# opposite case: `check` accepts it and the build must refuse it with the listed
# code (a change only the build can see, such as one against the committed
# event schema registry). Here it must fail to compile with exactly that code
# on every target.
#
# `bynkc compile` writes bynk.schema.lock into the project it compiles, so each
# project is copied to a temporary directory first and the snippets tree is
# never written to.
#
# Builds listed in snippets/EMIT-BASELINE are known to fail. They are reported
# without failing the gate, and a listed build that starts to pass fails it with
# a note to delete its line, so the baseline can only shrink.
#
# The compiler is whichever `bynkc` is on PATH; override with
# BYNKC=/path/to/bynkc. TypeScript is whichever `tsc` is on PATH; override with
# TSC=/path/to/tsc (CI pins a version through npx).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPETS="$ROOT/snippets"
MANIFEST="$SNIPPETS/EXPECTATIONS.tsv"
BASELINE="$SNIPPETS/EMIT-BASELINE"
TARGETS=(bundle workers)

BYNKC="${BYNKC:-$(command -v bynkc || true)}"
if [ -z "$BYNKC" ] || [ ! -x "$BYNKC" ]; then
  echo "bynkc not found on PATH. Install the Bynk toolchain (see README.md)," >&2
  echo "or set BYNKC=/path/to/bynkc." >&2
  exit 2
fi
TSC="${TSC:-$(command -v tsc || true)}"
if [ -z "$TSC" ]; then
  echo "tsc not found on PATH. Install TypeScript, or set TSC=/path/to/tsc." >&2
  exit 2
fi
printf 'Compiling snippets with %s and checking with tsc %s\n\n' \
  "$("$BYNKC" --version 2>/dev/null || printf '%s' "$BYNKC")" \
  "$($TSC --version 2>/dev/null | sed 's/^Version //')"

is_baselined() {
  [ -f "$BASELINE" ] || return 1
  awk -F'\t' -v p="$1" -v t="$2" \
    '$0 !~ /^[[:space:]]*(#|$)/ && $1 == p && $2 == t { found = 1 } END { exit !found }' \
    "$BASELINE"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail=0
checked=0
skipped=0
pending=0
while IFS= read -r toml; do
  dir="$(dirname "$toml")"
  rel="${dir#"$SNIPPETS"/}"

  kind="$(awk -F'\t' -v p="$rel" '$1 == p { print $2; exit }' "$MANIFEST")"
  code="$(awk -F'\t' -v p="$rel" '$1 == p { print $3; exit }' "$MANIFEST")"
  if [ "$kind" = fail ]; then
    printf '  skip  %-42s rejected fixture\n' "$rel"
    skipped=$((skipped + 1))
    continue
  fi
  checked=$((checked + 1))

  copy="$work/${rel//\//__}"
  mkdir -p "$copy" && cp -R "$dir/." "$copy/"

  if [ "$kind" = build-fail ]; then
    for target in "${TARGETS[@]}"; do
      out="$work/out-${rel//\//__}-$target"
      if detail="$("$BYNKC" compile --target "$target" -o "$out" "$copy" 2>&1)"; then
        printf '  FAIL  %-42s %s: expected the build to refuse [%s], but it compiled\n' "$rel" "$target" "$code"
        fail=$((fail + 1))
      elif ! printf '%s' "$detail" | grep -qF "[$code]"; then
        printf '  FAIL  %-42s %s: expected [%s]\n' "$rel" "$target" "$code"
        printf '%s\n' "$detail" | sed 's/^/        /'
        fail=$((fail + 1))
      else
        printf '  ok    %-42s %s: refused [%s]\n' "$rel" "$target" "$code"
      fi
    done
    continue
  fi

  for target in "${TARGETS[@]}"; do
    out="$work/out-${rel//\//__}-$target"
    problem=""
    if ! detail="$("$BYNKC" compile --target "$target" -o "$out" "$copy" 2>&1)"; then
      problem="bynkc compile failed"
    elif ! detail="$(cd "$out" && $TSC -p . --noEmit 2>&1)"; then
      problem="tsc rejected the emitted code"
    fi

    if is_baselined "$rel" "$target"; then
      if [ -n "$problem" ]; then
        printf '  todo  %-42s %s: known failure (baselined)\n' "$rel" "$target"
        pending=$((pending + 1))
      else
        printf '  FAIL  %-42s %s: now builds; delete its line from snippets/EMIT-BASELINE\n' "$rel" "$target"
        fail=$((fail + 1))
      fi
    elif [ -n "$problem" ]; then
      printf '  FAIL  %-42s %s: %s\n' "$rel" "$target" "$problem"
      printf '%s\n' "$detail" | sed 's/^/        /'
      fail=$((fail + 1))
    else
      printf '  ok    %-42s %s\n' "$rel" "$target"
    fi
  done
done < <(find "$SNIPPETS" -name bynk.toml | sort)

echo
if [ "$fail" -gt 0 ]; then
  echo "$fail build(s) failed. A listing the book presents as a program must"
  echo "compile and type-check, not only pass \`bynkc check\`."
  exit 1
fi
echo "Every gated build of $checked snippet projects compiles and type-checks."
echo "($skipped rejected fixtures skipped; $pending baselined builds still to fix.)"
