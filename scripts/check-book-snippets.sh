#!/usr/bin/env bash
#
# Compile-gate for the manuscript's Bynk snippet projects.
#
# Working principle 7 of README.md ("Compile-test every listing presented as a
# complete program") is otherwise only a manual discipline: CI typesets the
# manuscript but never compiles snippets/. This script runs `bynkc check` over
# every snippet project and asserts each one's expected outcome:
#
#   * most projects must type-check cleanly (a valid program);
#   * the "rejected" projects that demonstrate a compiler refusal must fail
#     with the exact diagnostic code the chapter quotes;
#   * a project may instead be expected to compile with a specific warning.
#
# Expectations for the non-clean projects live in snippets/EXPECTATIONS.tsv.
# Any project not listed there must check cleanly, warnings included.
#
# The compiler is whichever `bynkc` is on PATH; override with
# BYNKC=/path/to/bynkc. In CI, bynk-lang/setup-bynk installs a pinned release.
# The chapters quote diagnostic codes from a *published* compiler, so the
# version this runs against is part of the evidence — it is printed below.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPETS="$ROOT/snippets"
MANIFEST="$SNIPPETS/EXPECTATIONS.tsv"

BYNKC="${BYNKC:-$(command -v bynkc || true)}"
if [ -z "$BYNKC" ] || [ ! -x "$BYNKC" ]; then
  echo "bynkc not found on PATH. Install the Bynk toolchain (see README.md)," >&2
  echo "or set BYNKC=/path/to/bynkc." >&2
  exit 2
fi
printf 'Checking snippets with %s\n\n' "$("$BYNKC" --version 2>/dev/null || printf '%s' "$BYNKC")"

fail=0
checked=0
while IFS= read -r toml; do
  dir="$(dirname "$toml")"
  rel="${dir#"$SNIPPETS"/}"
  checked=$((checked + 1))

  out="$("$BYNKC" check --format short "$dir" 2>&1)"
  rc=$?

  spec="$(awk -F'\t' -v p="$rel" '$1 == p { print $2 "\t" $3; exit }' "$MANIFEST")"
  if [ -z "$spec" ]; then
    kind="pass"
    code=""
  else
    kind="${spec%%$'\t'*}"
    code="${spec#*$'\t'}"
  fi

  ok=1
  msg=""
  case "$kind" in
  pass)
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -q 'error\['; then
      ok=0
      msg="expected a clean check"
    elif printf '%s' "$out" | grep -q 'warning\['; then
      ok=0
      msg="unexpected warning (add it to EXPECTATIONS.tsv if intended)"
    fi
    ;;
  fail)
    if [ "$rc" -eq 0 ]; then
      ok=0
      msg="expected refusal error[$code], but check passed"
    elif ! printf '%s' "$out" | grep -q "error\[$code\]"; then
      ok=0
      msg="expected error[$code]"
    fi
    ;;
  build-fail)
    # Accepted by `check`, refused when built; check-book-emit.sh asserts the
    # build refusal. Here it must check as cleanly as a passing project.
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -q 'error\['; then
      ok=0
      msg="expected a clean check (the refusal $code is a build-time one)"
    fi
    ;;
  warn)
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -q 'error\['; then
      ok=0
      msg="expected a warning, got an error"
    elif ! printf '%s' "$out" | grep -q "warning\[$code\]"; then
      ok=0
      msg="expected warning[$code]"
    fi
    ;;
  *)
    ok=0
    msg="unknown expectation kind '$kind' in EXPECTATIONS.tsv"
    ;;
  esac

  if [ "$kind" = pass ]; then label="pass"; else label="$kind $code"; fi
  [ "$kind" = build-fail ] && label="pass (build-fail $code)"
  if [ "$ok" -eq 1 ]; then
    printf '  ok    %-42s %s\n' "$rel" "$label"
  else
    printf 'FAIL    %-42s %s\n' "$rel" "$msg"
    printf '%s\n' "$out" | sed 's/^/          | /'
    fail=1
  fi
done < <(find "$SNIPPETS" -name bynk.toml | sort)

echo
if [ "$fail" -eq 0 ]; then
  echo "All $checked snippet projects match their expected diagnostics."
else
  echo "Some snippet projects did not match their expected diagnostics."
fi
exit "$fail"
