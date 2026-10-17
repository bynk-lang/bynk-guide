#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let ledger = "../snippets/chapter-13/shop/src/shop/ledger.bynk"

= Events <events>

Every conversation between the shop's contexts so far has been a call. Orders
asks inventory to reserve stock and waits for the answer; it asks payments to
charge a card and waits for that too. A call is right when the caller needs
the answer.

The shop now wants a ledger: how many orders stand, how many units, and what
they come to. Orders doesn't need anything back from the ledger. It shouldn't
even need to know there is one. That is an _event_: a fact one context
announces, for any number of others to act on.

This chapter adds the ledger, fed by two events from orders. It is also where
the shop meets the edge of what Bynk 0.330.4 can test and deploy, and the
chapter is plain about both.

== The fan-out you would write <ix-guide-13-the-fan-out-you-would-write>

#lead-in[
By hand, orders sends a message to a Cloudflare Queue, and the ledger consumes
it, remembering which messages it has already counted:
]

#code-listing(
  [A queue between two Workers, by hand],
  read("../snippets/chapter-13/conventional.ts"),
  lang: "typescript",
  breakable: true,
)

This is a reasonable design, and the queue retries a message whose consumer
fails, which the Bynk version below doesn't do yet. But the message's shape is
a type each Worker declares for itself, the queue is configured in both
Workers' `wrangler.toml`, and nothing checks that the ledger understands what
orders sends. Add a field on one side and the other finds out in production.

== An event is a fact <ix-guide-13-an-event-is-a-fact>

#lead-in[
Orders declares its two events, exports them, and emits each where the fact
becomes true:
]

#code-listing(
  [`orders.bynk`, chapter 12 to chapter 13],
  read("../snippets/chapter-13/orders.diff"),
  lang: "diff",
  breakable: true,
)

An `event` is a record type with a meaning: something that happened. Its
fields are ordinary types, so `OrderPlaced` carries an `OrderId`, a `Sku`, a
`Quantity` and a `Cents`, each with its rules from chapter 2. `exports
transparent` lets other contexts name the events, and `consumes bynk { Events
}` brings in the capability that emits them.#footnote[
  The Bynk Book, “Understand events”.
]

`Events.emit[OrderPlaced](…)` names the event's type explicitly, as every
generic capability operation does. It returns `Effect[()]`: orders learns
nothing about who listened, or how it went. And an emission is held until the
handler finishes. The events a handler emits are released after its body has
run, so an event can't escape from a handler that faulted partway through.

The `Order` agent would be a better place still. An agent's emissions are
released only when its state commits, so `confirm` emitting `OrderPlaced` would
tie the event to the state change exactly. At 0.330.4 a unit test of an agent
that emits fails (bynk-lang/bynk#2050), so the shop emits from the route
handler, right after `confirm`.

== Subscribing <ix-guide-13-subscribing>

#lead-in[
The ledger is a context of its own. It consumes orders, but only to name the
events:
]

#code-listing(
  [The ledger's context],
  source-lines(ledger, 0, 4),
  lang: "bynk",
)

#lead-in[
Its state is one agent, the books:
]

#code-listing(
  [The books],
  source-lines(ledger, 25, 53),
  lang: "bynk",
)

#lead-in[
And a subscriber for each event:
]

#code-listing(
  [Counting a placed order],
  source-lines(ledger, 54, 74),
  lang: "bynk",
)

`from Events(OrderPlaced)` is a service protocol, beside `http`, `call` and the
others. The service has exactly one handler, `on event`, and nothing calls it;
it runs when an `OrderPlaced` arrives. The optional second parameter is the
envelope: the event's id, the context that emitted it, when, and its schema
version. `OnCancelled` is the same, and calls `cancelled`. The ledger also has
an `api` service with one route, `GET /totals`, for an `Admin`.

The order's total isn't on the event. It is `qty * cents`, worked out by the
subscriber. Orders announces what happened, and each listener derives what it
needs.

`Idempotency` is the first-party capability for at-least-once delivery.
`dedup` looks up a key, and `remember` stores a value under it for a time.
Keys are scoped to the handler that uses them, so `OnPlaced` and
`OnCancelled` can't collide even if they see the same id.

#lead-in[
Consuming orders lets the ledger subscribe to its events. It doesn't let the
ledger announce them:
]

#code-listing(
  [A ledger that emits an orders event],
  source-lines(
    "../snippets/chapter-13/foreign-emit/src/shop/ledger.bynk",
    54,
    63,
  ),
  lang: "bynk",
)

#compiler-message[
[bynk.event.emit_outside_owner] Error: `OrderPlaced` is not declared in this
context — only the context that declares an event may emit it
]

Only the context that owns an event can say it happened. Seeing a type isn't
permission to forge one.

== Running it <ix-guide-13-running-it>

`bynk dev` now serves four contexts, on ports in the order of their names, so
the ledger is on 8788 and orders moves up to 8789:

#code-listing(
  [Placing an order, and reading the books],
  read("../snippets/chapter-13/responses.txt"),
  lang: "text",
  breakable: true,
)

The books count the order as soon as it is placed, and take it off when it is
cancelled. A customer without the `admin` claim is `403`.

== What delivery means, at 0.330.4 <ix-guide-13-what-delivery-means>

The books were up to date by the next request, and the emitted code shows why.

#lead-in[
After a handler's body has run, orders hands its events to the context's
fan-out, a Durable Object the compiler adds, and waits for it:
]

#code-listing(
  [In orders' `handlers.ts`],
  read("../snippets/chapter-13/emitted/dispatch.ts"),
  lang: "typescript",
)

#lead-in[
The fan-out calls each subscriber's Worker through a Service Binding:
]

#code-listing(
  [In orders' `events_fanout.ts`],
  read("../snippets/chapter-13/emitted/deliver.ts"),
  lang: "typescript",
)

Three things follow, and none of them is obvious from the source.

- *Delivery happens inside the request.* The `PUT` that places an order
  doesn't answer until the ledger has counted it. A slow subscriber makes
  ordering slow, though a failing one doesn't make it fail.
- *Delivery is attempted once.* If the ledger's Worker answers with an error,
  or can't be reached, the fan-out logs `EventsFanout delivery failed`, with
  the event and the subscriber, and moves on. There is no retry and no log to
  replay from. The order is placed and the books miss it.
- *`Idempotency` remembers in memory.* At 0.330.4 its provider keeps keys in
  the isolate, so they are gone when Cloudflare recycles it, and two isolates
  don't share them.

So the shop's dedup guards against the duplicate deliveries that the design's
at-least-once guarantee allows. The failure this release actually has is a
missed event, and that one is logged rather than prevented. Both are named in
the events guide's account of what the track doesn't yet give you.

A ledger that had to be right would keep the event ids it has seen in the
agent's own storage, as payments keeps its webhook notices in chapter 10, and
would need a way to replay what it missed. This one is a running total for the
shop's staff, and it can afford to be approximately right.

== Testing it <ix-guide-13-testing-it>

#lead-in[
The books are an agent, so they are tested like one:
]

#code-listing(
  [The ledger's suite],
  read("../snippets/chapter-13/shop/tests/shop/ledger.bynk"),
  lang: "bynk",
)

The subscribers are another matter. A test can address a service by `call`,
by an HTTP route, by a cron schedule or by a WebSocket message, but not by an
event (bynk-lang/bynk#2052). So `OnPlaced`'s dedup has no unit test. The
`system` tier does deliver events, but chapter 11 warned that the shop would
lose its `system` suite here: a subscriber to events that carry commons types
doesn't build as a Worker under `tsc` (bynk-lang/bynk#2027, fixed on Bynk's
main branch and not yet released). The suite from chapter 11 is gone, and the
delivery is checked end to end, by the transcript above and the shop's
scenarios.

`bynk dev` isn't affected by that build failure, because Wrangler strips the
types without checking them. Neither is `bynkc test`, which only builds the
Workers for a `system` suite.

#code-listing(
  [The suites, run],
  read("../snippets/chapter-13/test-run.txt"),
  lang: "text",
  breakable: true,
)

== Deploying it <ix-guide-13-deploying-it>

Chapter 12 deployed three Workers. With the ledger, `bynk deploy` refuses
before it plans anything:

#compiler-message(read("../snippets/chapter-13/cycle.txt"))

Orders delivers events to the ledger through a Service Binding, so orders binds
to the ledger. And the ledger's `consumes shop.orders`, there only to name the
events, gives it a Service Binding to orders as well. Each Worker needs the
other to exist before it can be uploaded. The fix is on Bynk's main branch
(bynk-lang/bynk#1961): a consumer that only subscribes gets no binding. It
isn't released yet.

So at 0.330.4 the shop with a ledger runs under `bynk dev` and not on
Cloudflare. The chapter 12 shop, without it, still deploys.

== What it costs <ix-guide-13-what-it-costs>

An event decouples the emitter from its listeners, and that cuts both ways.
Orders can't tell whether the ledger counted an order, and nothing reconciles
the two. If the books are wrong, the evidence is a log line in the fan-out.

Ordering holds within one handler's emissions, and across one agent's
successive calls, but not across concurrent requests. A customer who cancels
while the placement is still being delivered could have the ledger see the
cancellation first, and the books would dip below zero for a moment. The
ledger doesn't refuse that with an invariant, because refusing the
cancellation would lose it.

At 0.330.4 the costs of the release come on top: one delivery attempt, an
in-memory `Idempotency`, no test address for a subscriber, no `system` suite,
and no deploy. The hand-written queue at the start of the chapter has
retries, and it deploys.

== Where this leaves the shop <ix-guide-13-where-this-leaves-the-shop>

Orders announces what happens to an order, and a ledger keeps the books from
those announcements, with the event's type checked on both sides of the wire.
Orders doesn't know the ledger exists. The ledger can't deploy until the next
Bynk release.

The next chapter puts time into the shop: a sweeper that runs on a schedule and
releases stock held by orders that never finished.
