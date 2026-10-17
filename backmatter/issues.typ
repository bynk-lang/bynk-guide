#import "../metadata.typ": book-meta

// Every bynk-lang/bynk issue or pull request the chapters cite, and its
// state when this draft was made. Regenerate the list with
//   grep -o -h "#[0-9]\{4\}" chapters/*.typ | sort -u
// and check each state with `gh issue view N -R bynk-lang/bynk`.

= Appendix: Issues cited <issues-cited>

The chapters name each limit of Bynk #book-meta.bynk-version where it bites,
with the issue in `bynk-lang/bynk` that tracks it. This is the whole list, as
it stood on 17 October 2026.

_Fixed_ means the issue is closed as fixed on Bynk's main branch, but the fix
isn't in #book-meta.bynk-version: the chapter's workaround is still needed at
this pin. _Merged_ marks a pull request the chapters cite for the fix itself.
_Open_ is still open. When the book moves to a newer release, the chapters
that cite a fixed issue change, and this list shrinks.

#block(width: 100%, breakable: true)[
  #set text(size: 8.4pt, hyphenate: false)
  #set par(justify: false, leading: 0.55em, first-line-indent: 0pt)
  #table(
    columns: (0.42fr, 2.6fr, 0.55fr, 0.5fr),
    align: (right, left, left, left),
    inset: (x: 0.5em, y: 0.42em),
    stroke: (x, y) => if y == 0 { (bottom: 0.8pt + rgb("#4b44d6")) } else { none },
    table.header(
      text(weight: "semibold")[\#],
      text(weight: "semibold")[At #book-meta.bynk-version],
      text(weight: "semibold")[Ch.],
      text(weight: "semibold")[On main],
    ),
    [1954], [`bynk dev` with several contexts fails to start without `--inspect`], [8], [fixed],
    [1960], [An agent handler that calls another context's service faults], [4, 8], [fixed],
    [1961], [`bynk deploy` refuses an event subscription as a Service Binding cycle], [13], [fixed],
    [1973], [Interop with existing TypeScript Workers (a track)], [8], [open],
    [1975], [A test can't reach an adapter's TypeScript binding], [10, 11], [fixed],
    [1976], [The deploy plan misses secrets read in providers and bindings], [12], [fixed],
    [1978], [A test that calls a `Caller` service without `by Caller(…)` fails `tsc`], [8, 11], [fixed],
    [1979], [`expect r == Ok(v)` in a test is checked against the wrong type], [2, 11], [fixed],
    [1982], [A `Map` keyed by an opaque type fails `tsc`], [2, 5, 14], [fixed],
    [1994], [A test that calls a route using `~>` fails `tsc`], [3], [fixed],
    [1997], [The deploy plan reads providers' secrets, and says when it can't see a binding's (the fix)], [12], [merged],
    [2004], [A shared secret on every internal call (the fix)], [8, 12], [merged],
    [2005], [Typed test outcomes, a named `Caller`, `~>` in tests (the fix)], [11], [merged],
    [2012], [Every internal call signed per pair of contexts (the fix)], [8, 12], [merged],
    [2017], [`~>` on a store update in an agent fails `tsc`], [4], [fixed],
    [2018], [`restates_invariant` misses a restated transition], [6], [fixed],
    [2019], [A test can't call a route guarded by a refinement actor], [7], [fixed],
    [2020], [A test can't call a route whose actor is a sum], [7], [fixed],
    [2024], [A test local named like a service fails `tsc`], [11], [fixed],
    [2025], [A literal argument isn't admitted in a `system` call], [11], [fixed],
    [2026], [A `stub` at the `system` tier is ignored], [11], [fixed],
    [2027], [A subscriber to events with commons types fails `tsc`], [11, 13], [fixed],
    [2034], [The staging plan omits the `-staging` suffix (the fix)], [12], [merged],
    [2037], [The bare `Kv` namespace keeps one title in every environment], [12], [fixed],
    [2050], [A unit test of an agent that emits an event fails], [13], [fixed],
    [2052], [A test can't deliver an event to a subscriber], [13], [open],
    [2053], [A fault reaches the logs without its stack trace], [12], [fixed],
    [2055], [A new Worker's secrets are set after its first upload], [12], [fixed],
    [2077], [`--context` doesn't refuse a callee whose contract changed], [15], [fixed],
    [2078], [`bynkc check` and `test` pass a non-additive event change], [15], [fixed],
  )
]
