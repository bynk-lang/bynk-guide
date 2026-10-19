#import "../metadata.typ": book-meta

// Every bynk-lang/bynk issue the chapters cite, and its state when this
// draft was made. scripts/check-book-issues.sh keeps the list in step with
// the chapters; check each state with `gh issue view N -R bynk-lang/bynk`.

= Appendix: Issues cited <issues-cited>

Where Bynk #book-meta.bynk-version doesn't yet do what a chapter needs, the
chapter says so where it matters, with the issue in `bynk-lang/bynk` that
tracks it. This is the whole list, as it stood on 19 October 2026.

The first draft of this book was checked against Bynk 0.330.4, and cited
thirty issues, most of them found while writing it. Every one was fixed by
#book-meta.bynk-version, and the chapters' workarounds went with them.

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
      text(weight: "semibold")[State],
    ),
    [2185], [`bynkc test` heads a `system` suite's results `integration`], [11], [open],
  )
]
