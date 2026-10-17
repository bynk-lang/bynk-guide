#!/usr/bin/env bash
#
# Gate for the deploy plans the chapters quote.
#
# A chapter that shows what `bynk deploy` would do prints the plan that
# `bynk deploy --dry-run` writes. The plan is derived from the program (the
# contexts, their order, the agents and the secrets it can see), so a release
# that changes the driver or the compiler can change it while every other gate
# stays green. This runs the dry run for each project a `plan` row of
# snippets/TRANSCRIPTS.tsv names and diffs its output against the chapter's
# copy.
#
# A dry run that refuses the project is quoted the same way: the transcript is
# whatever the dry run prints, so a chapter can show a refusal, and the exit
# status isn't checked.
#
# A dry run makes no Cloudflare calls and needs no account or token. A row may
# give a fourth column of extra `bynk deploy` arguments, such as `--env staging`,
# split on spaces.
#
# Each project runs on a copy with no out/, out-js/ or .bynk/, so the checkout
# is left untouched.
#
# The driver is `bynk` beside the `bynkc` on PATH, or whichever `bynk` is on
# PATH; override with BYNK=/path/to/bynk.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPETS="$ROOT/snippets"
TRANSCRIPTS="$SNIPPETS/TRANSCRIPTS.tsv"

BYNKC="${BYNKC:-$(command -v bynkc || true)}"
BYNK="${BYNK:-}"
if [ -z "$BYNK" ] && [ -n "$BYNKC" ] && [ -x "$(dirname "$BYNKC")/bynk" ]; then
  BYNK="$(dirname "$BYNKC")/bynk"
fi
BYNK="${BYNK:-$(command -v bynk || true)}"
if [ -z "$BYNK" ] || [ ! -x "$BYNK" ]; then
  echo "bynk not found on PATH. Install the Bynk toolchain (see README.md)," >&2
  echo "or set BYNK=/path/to/bynk." >&2
  exit 2
fi
printf 'Checking quoted deploy plans with %s\n\n' \
  "$("$BYNK" --version 2>/dev/null || printf '%s' "$BYNK")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail=0
checked=0
while IFS=$'\t' read -r t k p a; do
  case "$t" in '' | \#*) continue ;; esac
  [ "$k" = plan ] || continue
  checked=$((checked + 1))

  if [ ! -f "$SNIPPETS/$t" ] || [ ! -f "$SNIPPETS/$p/bynk.toml" ]; then
    printf 'FAIL    %-42s %s\n' "$t" "transcript or project $p missing"
    fail=1
    continue
  fi

  copy="$work/${p//\//__}"
  rm -rf "$copy" && mkdir -p "$copy" && cp -R "$SNIPPETS/$p/." "$copy/"
  rm -rf "$copy/out" "$copy/out-js" "$copy/.bynk"

  local_args=()
  [ -z "${a:-}" ] || read -ra local_args <<<"$a"
  out="$(cd "$copy" && NO_COLOR=1 "$BYNK" deploy --dry-run "${local_args[@]}" </dev/null 2>&1)"
  rc=$?
  if ! d="$(diff -u --label "$t (quoted)" --label "$t (bynk deploy --dry-run)" \
    "$SNIPPETS/$t" <(printf '%s\n' "$out"))"; then
    printf 'FAIL    %-42s %s\n' "$t" "the quoted plan no longer matches (exit $rc)"
    printf '%s\n' "$d" | sed 's/^/          | /'
    fail=1
  else
    printf '  ok    %-42s %s\n' "$t" "plan for $p (exit $rc)"
  fi
done <"$TRANSCRIPTS"

echo
if [ "$fail" -eq 0 ]; then
  echo "All $checked quoted deploy plans match what bynk deploy --dry-run writes."
else
  echo "Some quoted deploy plans no longer match. Revise the chapter's copy"
  echo "to what \`bynk deploy --dry-run\` writes now."
fi
exit "$fail"
