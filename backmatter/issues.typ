#import "../metadata.typ": book-meta

// Every bynk-lang/bynk issue the chapters cite, and its state when this
// draft was made. scripts/check-book-issues.sh keeps the list in step with
// the chapters; check each state with `gh issue view N -R bynk-lang/bynk`.

= Appendix: Issues cited <issues-cited>

Where Bynk doesn't yet do what a chapter needs, the chapter says so where it
matters, with the issue in `bynk-lang/bynk` that tracks it. At
#book-meta.bynk-version, on 21 October 2026, no chapter cites one.

The first draft of this book was checked against Bynk 0.330.4, and cited
thirty issues, most of them found while writing it. Every one was fixed by
0.371.3, and the chapters' workarounds went with them. The one issue cited at
that release, that `bynkc test` headed a `system` suite's results
`integration` (#2185), is fixed in #book-meta.bynk-version. If a later pin
needs a workaround, it is listed here, one row to an issue.
