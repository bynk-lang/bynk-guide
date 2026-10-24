#import "../template.typ": code-listing, compiler-message, lead-in
#import "../metadata.typ": book-meta

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
which tier it belongs to, and so how much of the world it needs to make
real.

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
  source-lines("../snippets/chapter-11/shop/tests/shop/inventory.bynk", 55, 64),
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
  [A `system` suite for payments],
  read("../snippets/chapter-11/shop/tests/shop/payments_system.bynk"),
  lang: "bynk",
)

`suite shop.payments as system` stands the payments context up as the Worker
it deploys as, with every context it consumes. The case addresses a service by
its context path, `shop.payments.authorise(…)`, as another context would,
and the call is serialised to JSON, signed, sent through a Service Binding,
checked on arrival, and its answer serialised back. That is the edge chapter 8
described, and no in-process tier touches it. A `system` suite names the
commons it uses, here `shop.values`, because it isn't inside the context.

The first case checks the fail-closed rule from chapter 9, over the wire: with
no processor configured, a charge is `Unavailable`. The second gives the Worker
an environment with `env { … }`, the variables and secrets Wrangler would
set, and the fake processor answers. The third tests the webhook's seam. A
`Signature` route is signed by the harness the way its actor declares, so a
plain call would get through; `by Nobody` sends no signature and `by Forged`
signs with the wrong secret, and the real Worker refuses both before the
handler runs.#footnote[
  The Bynk Book's testing reference, “Configuring a suite” and “Testing the
  auth seam”.
]

#lead-in[
And the order flow, end to end:
]

#code-listing(
  [A `system` suite for orders],
  read("../snippets/chapter-11/shop/tests/shop/orders_system.bynk"),
  lang: "bynk",
)

This case stands up three Workers: orders, and the inventory and payments
contexts it consumes. It restocks as an `Admin`, places an order as a
`Customer`, and reads the level back. The harness signs each caller's token
from its `by` clause, and every call between the Workers is a real, signed
Service Binding call. This is the Miniflare harness from the start of the
chapter, and none of its configuration had to be written.

#lead-in[
`system` doesn't mix with the lower tiers in one suite:
]

#code-listing(
  [Two tiers in one suite],
  read("../snippets/chapter-11/mixed-suite/tests/shop/payments.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.tier.mixed_system_suite] Error: case `"the same notice, unsigned, over
the wire"` is `as system`, but other cases in its suite run below `system`
]

A `system` case addresses services by context path and runs against built
Workers, so it lives in its own suite, and its own file.

#lead-in[
Nor does a `stub`. Try to switch the fake processor on by stubbing its
setting, as chapter 9 did:
]

#code-listing(
  [A stub at `system`],
  read("../snippets/chapter-11/system-stub/tests/shop/payments.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.stub.at_system] Error: `stub Secrets.get` is in a `system`-tier case,
where a `stub` has no effect
]

Each Worker at `system` builds its own providers, as it would when deployed,
so there is no seam to replace. Give it an environment with `env` instead, or
keep the case at `unit` or `integration`, where a `stub` works.

== What else `system` can drive <ix-guide-11-what-else-system-can-drive>

A `system` case isn't limited to calls and routes. It can run a cron handler
through the Worker's real `scheduled` entry, deliver a queue message through
its real `queue` entry, and move the harness clock with `advance Clock by …`,
which every Worker's `Clock` reads. Chapter 14 uses the first two from a
`unit` suite; the same bodies promote unchanged. And `bynk test --against`
runs the same `system` suites against a running `bynk dev`, or against a
deployment you name, which is the step from a test of built Workers to a test
of a live system.

== Beyond `bynkc test` <ix-guide-11-beyond-bynkc-test>

Two kinds of test sit outside the tiers, and the shop uses both.

The first is the binding's Node tests, from chapter 10. An `integration` case
can now run an adapter's real binding, with the binding's own capabilities
taking the tier's doubles and stubs, so the binding could be tested from Bynk
with `Fetch.send` stubbed. The shop keeps its Node tests, which test the
binding as the TypeScript it is, against fake capabilities.

The second is end to end, against `bynk dev`: real Workers in Wrangler's local
runtime, real HTTP, real tokens and real signatures. The shop's
`e2e/scenarios.sh` does this for the whole flow, including signed and forged
webhooks and a sweep of stale holds. Every transcript in this book is the same
kind of test: CI starts `bynk dev` on the chapter's project, replays each
request, and compares what comes back with the page.

#lead-in[
The whole run:
]

#code-listing(
  [The suites, run],
  read("../snippets/chapter-11/test-run.txt"),
  lang: "text",
  breakable: true,
)

`order for 7500 cents` is the orders Worker's own `Logger` line, printed by
the real Worker the `system` case stood up.

== What it costs <ix-guide-11-what-it-costs>

Three kinds of runner check this shop: `bynkc test`, `node --test` for the
binding, and a shell script against `bynk dev`. Each answers a question the
others don't, but it is still three things to keep running.

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
