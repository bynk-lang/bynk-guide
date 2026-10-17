#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

= Testing at three tiers <testing-at-three-tiers>

The shop has been tested since chapter 2, one chapter's worth at a time. It
now has a suite per context, property tests that drive whole histories, stubs
and observation at capability seams, Node tests for its binding, transcripts
replayed against `bynk dev`, and an end-to-end script in the shop's own
repository. That is a lot of testing, and it was all added as each chapter
needed it.

This chapter steps back and puts it in order. Bynk has three _tiers_ of test,
and they answer different questions: does this unit's logic hold, does it hold
with its real collaborators, and does the flow hold across the wire between
Workers? The useful thing to learn is which question a test is asking, and so
which tier it belongs to. The other thing to learn, at 0.330.4, is where the
top tier stops, because it stops sooner than it should.

== The harness you would build <ix-guide-11-the-harness-you-would-build>

#lead-in[
By hand, testing a flow across three Workers means building each one, then
standing them up together in Miniflare, wired the way `wrangler.toml` wires
them:
]

#code-listing(
  [Three Workers in Miniflare, by hand],
  read("../snippets/chapter-11/conventional.test.ts"),
  lang: "typescript",
)

This works, and Miniflare is a good tool. But every name in that
configuration (`ORDER`, `INVENTORY`, `shop-payments`, the class names) is a
copy of something in each Worker's configuration, and a build step has to run
first. The test knows the system's shape because someone wrote it down twice.
And it can only test from the outside: the HTTP request and its status code.
To test the inventory's rule about holds, you write a different harness.

== One body, three tiers <ix-guide-11-one-body-three-tiers>

A Bynk `case` runs at one of three tiers. The tier says how much of the world
is real; the body is the same.#footnote[
  The Bynk Book, “Test tiers”, and the testing reference.
]

#figure(
  block(width: 100%)[
    #set text(size: 8.7pt, hyphenate: false)
    #set par(justify: false, leading: 0.6em, first-line-indent: 0pt)
    #table(
      columns: (0.7fr, 1.4fr, 1fr),
      inset: (x: 0.55em, y: 0.52em),
      stroke: (x, y) => if y == 0 { (bottom: 0.8pt + rgb("#4b44d6")) } else { none },
      table.header(
        text(weight: "semibold")[Tier],
        text(weight: "semibold")[What is real],
        text(weight: "semibold")[What it answers],
      ),
      [`unit`, the default], [The unit under test, in process. Capability seams can be stubbed.], [Does the logic hold?],
      [`integration`], [Real collaborators within one context, in process.], [Does it hold with what it really works with?],
      [`system`], [Every context it consumes, as the Workers they deploy as, across a real JSON wire.], [Does the flow hold across Workers?],
    )
  ],
  caption: [The three tiers. Many `unit` cases, some `integration`, few `system`.],
)

There is no configuration to keep in step with the build. A `system` suite
finds the contexts to stand up from the `consumes` graph of the context it
tests, and runs them in Node, with no Wrangler and no Miniflare.

== Unit: the default <ix-guide-11-unit-the-default>

Every case in this book so far has been a `unit` case. It runs the unit under
test in process: an agent with fresh in-memory state for each case, a
service's handler, or a function. Collaborators at a capability seam can be
replaced with `stub`, and every call through a seam is recorded, so
`expect Cap.op called …` can check it (chapter 9). A `property` generates
values or whole histories (chapter 6).

Capabilities nobody stubs get a deterministic test double. `Clock.now()` reads
the epoch, `Secrets.get` finds nothing, `Logger` records and prints nothing,
and `Fetch.send` faults, so a unit test never reaches the network by
accident. Chapter 9's "fails closed" case relied on exactly that `Secrets`
double.

Most of the shop's 30 cases are `unit` cases, and that is the right
proportion. They are fast, they don't flake, and a failure points at one
unit.

== Integration: real collaborators <ix-guide-11-integration>

#lead-in[
Promote a case by adding one word to its header:
]

#code-listing(
  [An `integration` case],
  source-lines("../snippets/chapter-11/shop/tests/shop/inventory.bynk", 54, 63),
  lang: "bynk",
)

At `integration`, the collaborators inside the context are real: its agents,
its providers, and their invariants and contracts. The body is unchanged. A
case that passes at `unit` and fails when promoted has found a defect that a
stub was hiding, with no new test code.

In this shop the difference is small, and it is worth being honest about that.
The shop's collaborators within a context are agents and the context's own
providers, which already run for real in a `unit` case unless a case stubs
them. `integration` earns its place in a context with more collaborators than
this one, or once a case starts stubbing seams it would rather see run.

#lead-in[
Neither tier crosses into another context. Test the order route at `unit`, the
way chapter 2 did before the shop was split:
]

#code-listing(
  [A unit case that crosses contexts],
  source-lines("../snippets/chapter-11/cross-context-unit/tests/shop/orders.bynk", 73, 82),
  lang: "bynk",
)

#compiler-message[
[bynk.tier.cross_context_needs_system] Error: case `"a customer places an
order"` calls `api`, which calls `shop.inventory.reserve` in another context,
but it is a `unit`-tier case
]

The compiler follows the call through the handler and finds the Service
Binding. In process, there is nothing on the other side of it, so the case
belongs at `system`.

== System: across the wire <ix-guide-11-system>

#lead-in[
A `system` suite is a file of its own. Here is the payments context, tested
over the wire:
]

#code-listing(
  [A `system` suite],
  read("../snippets/chapter-11/shop/tests/shop/payments_system.bynk"),
  lang: "bynk",
)

`suite shop.payments as system` stands the payments context up as the Worker
it deploys as, with every context it consumes. The case addresses a service by
its context path, `shop.payments.authorise(…)`, as another context would,
and the call is serialised to JSON, sent through a Service Binding, checked on
arrival, and its answer serialised back. That is the edge chapter 8 described,
and no in-process tier touches it. A `system` suite names the commons it uses,
here `shop.values`, because it isn't inside the context.

The first case checks the fail-closed rule from chapter 9, over the wire: with
no processor configured, a charge is `Unavailable`. The second sends a notice
to the webhook. At this tier the harness signs a `Bearer` caller's token from
a `by` clause, but a `Signature` caller needs the shared secret, so the notice
goes unsigned and the boundary refuses it. That is the real check, running in
the real Worker.

#lead-in[
`system` doesn't mix with the lower tiers in one suite:
]

#code-listing(
  [Two tiers in one suite],
  read("../snippets/chapter-11/mixed-suite/tests/shop/payments.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.tier.mixed_system_suite] Error: case `"the same notice, over the wire"`
is `as system`, but other cases in its suite run below `system`
]

A `system` case addresses services by context path and runs against built
Workers, so it lives in its own suite, and its own file.

== Where `system` stops, at 0.330.4 <ix-guide-11-where-system-stops>

The `system` tier is the newest part of Bynk's testing, and at this book's
release it stops short in five places. Each is fixed or filed upstream, and
each shapes the suite above.

- *It can't drive a Worker whose routes use `~>`.* The orders Worker's
  `fetch` takes the execution context that `~>` needs, and the harness calls it
  without one, so the generated test doesn't compile. The fix is on Bynk's main
  branch (bynk-lang/bynk#2005), not yet released. That is why the suite above
  tests payments, not the order flow.
- *A `stub` at `system` is accepted and ignored* (bynk-lang/bynk#2026). The
  reference says a stub is legal at every tier; at 0.330.4 the Worker under
  test reads the real seam. So a `system` case can't give a Worker a secret,
  and the fake processor can't be switched on.
- *A literal argument isn't admitted* to a refined parameter in a
  context-path call (bynk-lang/bynk#2025). Bind it with a type first, as
  `let cents: Cents = 2500` does.
- *A project whose events carry commons types doesn't build as Workers
  under `tsc`*, because a subscriber's serialiser names an unimported
  namespace (bynk-lang/bynk#2027). `bynk dev` and `bynk deploy` don't notice,
  since Wrangler strips types, but a `system` suite type-checks every Worker,
  so once the shop's ledger subscribes to orders in chapter 13 the shop can't
  have one.
- *The output calls a `system` suite `integration`*: the run below lists it as
  `integration · shop.payments`.

None of this undermines the tier's design, which is the right one: the same
body, real Workers, and participants found from the program. It means the
whole order flow, at this release, is covered one level further out.

== Beyond `bynkc test` <ix-guide-11-beyond-bynkc-test>

Two kinds of test sit outside the tiers, and the shop uses both.

The first is the binding's Node tests, from chapter 10. A Bynk test can't
reach an adapter's binding at 0.330.4 (bynk-lang/bynk#1975), so the binding is
tested as TypeScript, against fake capabilities.

The second is end to end, against `bynk dev`: real Workers in Wrangler's local
runtime, real HTTP, real tokens and real signatures. The shop's
`e2e/scenarios.sh` does this for the whole flow, including signed and forged
webhooks and a sweep of stale holds. Every transcript in this book is the same
kind of test: CI starts `bynk dev` on the chapter's project, replays each
request, and compares what comes back with the page.

== Habits that save a failing build <ix-guide-11-habits>

Three habits from earlier chapters exist because of bugs at 0.330.4, and are
worth keeping until the pin moves:

- Compare results with `is`, as in `expect r is Ok(v)`, not `==`, which is
  checked against the wrong type inside a case (bynk-lang/bynk#1979).
- Name the caller when a test calls an `on call` service:
  `… by Caller("shop.orders")`. Leaving it out passes the check and fails the
  build (bynk-lang/bynk#1978; fixed upstream, unreleased, by requiring it).
- Don't name a test's local after a service of the unit under test. `let
  level <- …` beside `service level` passes the check and fails the build
  (bynk-lang/bynk#2024).

#lead-in[
The whole run:
]

#code-listing(
  [The suites, run],
  read("../snippets/chapter-11/test-run.txt"),
  lang: "text",
  breakable: true,
)

== What it costs <ix-guide-11-what-it-costs>

Three kinds of runner check this shop: `bynkc test`, `node --test` for the
binding, and a shell script against `bynk dev`. Each is there because the one
before stops short, and at 0.330.4 the `system` tier stops sooner than it will.
That is more machinery than a project should need, and it will shrink as the
fixes above are released.

The tiers are about realness, not speed or isolation. A `system` case is still
in process and still fast, but it tests built Workers, so a failure there can
come from anywhere on the path. Keep most cases at `unit`, where a failure
names its cause.

And a passing suite is a sample. Property tests and history properties search
further than hand-written cases, but they still run bounded inputs, and none of
these tiers has seen production traffic. The next chapter deploys the shop.

== Where this leaves the shop <ix-guide-11-where-this-leaves-the-shop>

The shop's tests now have a place for every question: logic at `unit`,
collaborators at `integration`, the wire at `system`, the binding in Node, and
everything together against `bynk dev`. What it hasn't done is run anywhere but
a laptop and CI. The next chapter ships it to Cloudflare, and then looks at
what to do when a deployed Worker misbehaves.
