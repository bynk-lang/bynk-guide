#import "../metadata.typ": book-meta

= Epilogue: Where to go next <epilogue>

The shop began as one Worker answering one route. It ends as four contexts:
orders, inventory, payments and a ledger. They have five agents between them,
two events, a schedule, a queue, an adapter over a real payment API, and a
webhook proved by its signature. Every chapter replaced something you would
otherwise have written by hand, and it is worth seeing the whole list at once.

#figure(
  block(width: 100%)[
    #set text(size: 8.7pt, hyphenate: false)
    #set par(justify: false, leading: 0.6em, first-line-indent: 0pt)
    #table(
      columns: (1.25fr, 1.25fr, 0.35fr),
      align: (left, left, right),
      inset: (x: 0.55em, y: 0.5em),
      stroke: (x, y) => if y == 0 { (bottom: 0.8pt + rgb("#4b44d6")) } else { none },
      table.header(
        text(weight: "semibold")[By hand],
        text(weight: "semibold")[In Bynk],
        text(weight: "semibold")[Ch.],
      ),
      [A `fetch` handler and a router], [`service … from http`], [1],
      [Validating input before you trust it], [Refined and opaque types], [2],
      [`throw`, and remembering to catch], [`Result`, `?` and `embeds`], [3],
      [A Durable Object class, its binding and its migration], [An `agent`], [4],
      [KV, a cache, a list you scan], [`Cell`, `Map`, `Cache`, `Log`, `Query`], [5],
      [Status checks at the top of each method], [Invariants and transitions], [6],
      [Auth middleware], [Actors], [7],
      [Service Binding glue, typed twice], [Contexts and `consumes`], [8],
      [Reading `env`, and `vi.mock`], [Capabilities and providers], [9],
      [An SDK call, and verifying a webhook], [An adapter and a `Signature` actor], [10],
      [A Miniflare harness], [Unit, integration and system tests], [11],
      [A deploy script], [`bynk deploy` and its plan], [12],
      [A queue between two Workers], [Events], [13],
      [A `scheduled` handler and a queue consumer], [`from cron` and `from queue`], [14],
      [A storage migration, and versioned RPC], [The schema lock and the contract hash], [15],
    )
  ],
  caption: [What the shop replaced, chapter by chapter.],
)

The right-hand column isn't less work. It is the same work, moved to where the
compiler can see it. Each chapter also ended with what that costs. Some of
those costs come from a young language, and some will stay.

== The Bynk Book <ix-guide-epilogue-the-bynk-book>

This book taught Bynk by building one thing. The Bynk Book, at
`bynk-lang.org/book`, is the reference: every construct, every diagnostic
code (`bynk explain` prints the longer form of one), the guides this book's
footnotes point to, and the changelog. It also covers what this book left out:

- *WebSockets*, and the `Oidc` actor for signing in with an identity provider.
- *Localisation*: message bundles and a `Locale` negotiated per request.
- *Static assets*, served by the platform beside a context's routes.
- *The `bundle` target*, which chapter 1 introduced and then set aside, for
  running a Bynk program on Node or in a browser.
- *The editor*: the language server, and the VS Code extension that sets
  breakpoints in `.bynk` files.

== _Architecture that compiles_ <ix-guide-epilogue-architecture-that-compiles>

This book has said _how_ more often than _why_. Why a dependency between
contexts should be declared, why a failure belongs in a type, why an effect
needs authority: that argument is _Architecture that compiles_, a companion
book about the problems of service design that Bynk is built to address. Read
it when you want to know whether the friction in these chapters is worth
paying for on a system of your own.

== Real programs <ix-guide-epilogue-real-programs>

The shop is at `bynk-lang/shop`, with its end-to-end scenarios and a README
that lists, as this book has, what it works around and why.

The `bynk-lang` organisation runs a few more Bynk programs in production. Each
is small, and each was written for its own sake, not for teaching:

- *`bynk-lang/compat-board`* collects the canary's results. Its one agent
  holds every result, and its route is guarded by a GitHub OIDC token.
- *`bynk-lang/examples`* is the index of the organisation's Bynk projects.
  It fetches two documents, merges them, and keeps the last good copy in an
  agent's `Cache`.
- *`bynk-lang/status`* checks every five minutes that the others answer.

Reading them is the quickest way to see the language in code nobody shaped
for a chapter.

== The canary <ix-guide-epilogue-the-canary>

Bynk is pre-1.0, and its releases change things. The organisation's
_canary_ re-runs every enrolled repository's checks against each new release:
the format check, the type check, the tests and, where it can, a deploy dry
run. When something breaks, it opens an issue on that repository, and the
compat board records which release each one last passed with.

This book is enrolled. Every listing in it is compiled, formatted and run by
its own gates, and every transcript is replayed against `bynk dev`, so a
release that changes what a listing does is found by the canary before a
reader finds it.

Your own project can do the same thing on a smaller scale. Pin the version in
`bynk-ci`, as chapter 12 did, and add a scheduled workflow that runs the same
checks with `version: latest`. Bump the pin deliberately when that workflow
is green.

== This book's pin <ix-guide-epilogue-this-books-pin>

Every example was checked against Bynk #book-meta.bynk-version. The first
draft of this book was checked against 0.330.4, and worked around thirty
limits that are gone now: the shop couldn't deploy its ledger, its calls
between contexts weren't signed, and a good deal of it couldn't be tested
above the `unit` tier. Each was filed while the book was written, and each
was fixed by the release this one uses.

Nothing is left to name. No chapter works around an open Bynk issue at this
release. If a later pin needs a workaround, the chapter will say so where it
bites, with its issue number, and the appendix will list it.

If you find one this book missed, the place to say so is the issue tracker at
`bynk-lang/bynk`. Most of the issues this book cites were found by writing it.
