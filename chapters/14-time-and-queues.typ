#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let inventory = "../snippets/chapter-14/shop/src/shop/inventory.bynk"
#let orders = "../snippets/chapter-14/shop/src/shop/orders.bynk"

= Time and queues <time-and-queues>

Every handler in the shop so far has run because someone asked: a customer,
another context, the payment processor, an event. Some work has no one to ask
for it. Stock held for an order whose request died halfway is a debt nobody is
going to collect, unless something goes looking for it on a schedule.

Chapter 8 left exactly that gap. Placing an order reserves stock, then takes
the payment, and if the Worker dies between the two, the hold stays forever.
This chapter closes it with a _cron_ handler, a service that runs on a
schedule. Then it gives the inventory a second way to hear about the world: a
Cloudflare Queue, fed by the warehouse.

== The sweeper you would write <ix-guide-14-the-sweeper-you-would-write>

#lead-in[
By hand, a Worker's `scheduled` handler runs on a schedule set in
`wrangler.toml`, and asks each Durable Object to clean up:
]

#code-listing(
  [A scheduled sweep, by hand],
  read("../snippets/chapter-14/conventional.ts"),
  lang: "typescript",
)

The schedule lives in one file and the code it drives in another. The cutoff
is a number of milliseconds. And `release-stale` is a path the Durable Object
has to route, with a body it has to parse, so the sweep is only as right as
two pieces of string handling agree.

== A hold that knows when it was made <ix-guide-14-a-hold-that-knows-when>

#lead-in[
To find an abandoned hold, the inventory needs to know how old each one is:
]

#code-listing(
  [Holds, and how long one may stand],
  source-lines(inventory, 17, 33),
  lang: "bynk",
)

#lead-in[
`reserve` stamps each hold with `Clock.now()`, the capability from chapter 5:
]

#code-listing(
  [Reserving, with the time],
  source-lines(inventory, 57, 79),
  lang: "bynk",
)

A hold now ends one of three ways. `release` gives it back, as before, when a
payment fails. The sweeper gives it back when it is too old. And `commit`,
which is new, turns it into a sale:

#code-listing(
  [Committing a hold],
  source-lines(inventory, 99, 109),
  lang: "bynk",
)

Before this chapter, a placed order's hold simply stayed in `holds` forever,
which was harmless only because nothing looked at it. With a sweeper, a hold
that is never committed would be released fifteen minutes later and the stock
sold twice. So orders now commits the hold once the payment is taken:

#code-listing(
  [In orders, after the payment],
  source-lines(orders, 229, 244),
  lang: "bynk",
)

If the commit fails, the sweeper got there first: the request took longer than
fifteen minutes between reserving and committing, and the stock may have gone
to someone else. The order is refused with a `409 reservation expired` rather
than sold twice. The card has been authorised, though, and the gateway from
chapter 10 has no way to void an authorisation yet. The comment says so, and
the shop is relying on that being rare.

Cancelling an order changes to match. The hold is gone once the order is
placed, so a cancellation gives the units back with `restock` rather than
`release`.

== Finding every sku <ix-guide-14-finding-every-sku>

The sweeper has to visit each `Inventory`, one Durable Object per sku, and
Cloudflare has no way to list a namespace's objects. So the shop keeps its own
list:

#code-listing(
  [The catalogue],
  source-lines(inventory, 146, 161),
  lang: "bynk",
)

#code-listing(
  [Restocking records the sku],
  source-lines(inventory, 166, 172),
  lang: "bynk",
)

`skus` is a map keyed by the sku's text, so adding one twice keeps one entry.
It is keyed by text, as the holds are keyed by `orderRef`, with the `Sku`
itself as the value.

#lead-in[
`releaseStale` does one sku's work in one commit:
]

#code-listing(
  [Releasing what is stale],
  source-lines(inventory, 121, 138),
  lang: "bynk",
)

== A service that runs on a schedule <ix-guide-14-a-service-on-a-schedule>

#lead-in[
And the sweeper itself:
]

#code-listing(
  [The sweeper],
  source-lines(inventory, 202, 223),
  lang: "bynk",
)

`from cron` is the protocol, and `on schedule("*/5 * * * *")` is the schedule,
on the handler it drives: a standard five-field cron expression, here every
five minutes. The handler returns `Effect[Result[(), E]]`. There is no caller
to answer and no retry, so an `Err` is logged and the run is over; the next
one is five minutes away.#footnote[
  The Bynk Book, “Run a task on a schedule”.
]

The one parameter is the time the run was _scheduled_ for, in epoch
milliseconds. The cutoff is measured from that, not from `Clock.now()`. A run
that starts late, because Cloudflare was busy, releases exactly the holds an
on-time run would have, and a test can say which time it is without stubbing
the clock.

#lead-in[
The parameter has to be an `Int`. Ask for an `Instant` and the compiler
refuses:
]

#code-listing(
  [A sweeper that takes an `Instant`],
  source-lines(
    "../snippets/chapter-14/instant-param/src/shop/inventory.bynk",
    209,
    214,
  ),
  lang: "bynk",
)

#compiler-message[
[bynk.cron.bad_params] Error: an `on cron` parameter must be `Int` (the
scheduled time in epoch milliseconds), got `Instant`
]

The sweeper wraps it itself, with `Instant.fromEpochMillis(at)`.

#lead-in[
The schedule is on the handler, and the compiler writes it into the
generated configuration, where Cloudflare expects it:
]

#code-listing(
  [In inventory's generated `wrangler.toml`],
  read("../snippets/chapter-14/emitted/triggers.toml"),
  lang: "toml",
)

The queue below is there too.

== Running a schedule by hand <ix-guide-14-running-a-schedule-by-hand>

A schedule that fires every five minutes is no help while you are working on
it. Wrangler can fire it on request: pass `--test-scheduled` through `bynk
dev`, and each Worker answers `/__scheduled` by running its scheduled
handler.

#code-listing(
  [Serving with scheduled testing],
  "bynk dev --inspect -- --test-scheduled \\\n  --var AUTH_JWT_SECRET:not-a-secret …",
  lang: "sh",
)

#code-listing(
  [Running the sweeper],
  read("../snippets/chapter-14/scheduled.txt"),
  lang: "text",
)

Inventory serves on 8787, so that is where `/__scheduled` goes. The stock is
untouched, because no hold was stale. Every way of placing an order now ends
its hold with a commit or a release, so a stale hold only comes from a request
that died partway, which is hard to arrange on purpose. That is what the tests
are for.

== Testing time <ix-guide-14-testing-time>

#lead-in[
A test runs a cron handler with `.schedule`, naming the schedule and the time:
]

#code-listing(
  [The sweeper, under test],
  source-lines(
    "../snippets/chapter-14/shop/tests/shop/inventory.bynk",
    99,
    126,
  ),
  lang: "bynk",
)

Under test, `Clock.now()` reads the epoch, so every hold is made at time zero.
`960000` is sixteen minutes later, so the first case's hold is stale, and
`840000` is fourteen, so the second case's isn't. No clock is stubbed and
nothing waits: the time is an argument.

`expect Logger.info called with …` checks that the sweep said what it did, and
`expect Logger.info never called` that a sweep with nothing to do stays quiet.

== A queue <ix-guide-14-a-queue>

The shop's stock has only ever arrived through `PUT /stock/:sku`, an admin
typing a number. A real warehouse has a system of its own, and it announces
deliveries on a Cloudflare Queue.

#lead-in[
The inventory consumes that queue:
]

#code-listing(
  [Deliveries, from the warehouse],
  source-lines(inventory, 224, 241),
  lang: "bynk",
)

`from queue("stock-deliveries")` binds the service to the queue by name, and
`on message` takes one message, already checked against `Delivery`. A message
that doesn't fit is retried, so the handler never sees a malformed one. It
returns a `QueueResult`: `Ack` to say it's done, or `Retry(reason)` to have the
queue deliver it again.#footnote[
  The Bynk Book, “Process a queued message”.
]

A queue delivers at least once. A message whose handler fails or times out
comes back, and a message can come back even when the handler finished. So
stocking a delivery has to be safe to repeat:

#code-listing(
  [Receiving a delivery once],
  source-lines(inventory, 80, 98),
  lang: "bynk",
)

This is the dedup chapter 13 recommended for a ledger that had to be right:
the ids live in the agent's own storage, in a `Log` kept for 30 days, and the
check and the restock commit together. `Idempotency` would have been shorter,
but it forgets when the isolate does.

#lead-in[
A test sends a message with `.message`:
]

#code-listing(
  [Deliveries, under test],
  source-lines(
    "../snippets/chapter-14/shop/tests/shop/inventory.bynk",
    129,
    146,
  ),
  lang: "bynk",
)

What Bynk can't do is _send_ to a queue. Producing messages isn't a
first-party capability yet, so a queue in a Bynk program is always fed from
outside it: here, the warehouse's own Worker. That is also why there is no
transcript of a delivery under `bynk dev`: nothing in the shop can put a
message on the local queue.

#code-listing(
  [The suites, run],
  read("../snippets/chapter-14/test-run.txt"),
  lang: "text",
  breakable: true,
)

== What it costs <ix-guide-14-what-it-costs>

The sweeper visits every sku in the catalogue, one after another, every five
minutes, in a single invocation. That is fine for a shop with a few hundred
products. With many thousands it could outrun what one scheduled invocation is
allowed, and the usual fix is to have the cron put one message per sku on a queue and
let a consumer do the work. A Bynk program can't send that message yet, so
the fan-out would need a TypeScript Worker beside it.

The catalogue only grows. A sku that is never stocked again is still visited,
and nothing removes it.

A committed hold leaves an order that the sweeper can no longer save. If the
gateway is slow enough that the commit fails, the customer has a refused order
and an authorised card, until the authorisation lapses on the processor's
side.

And a message that never fits `Delivery` is retried until the queue gives up.
Where it goes then is the queue's dead-letter setting, which is configured in
Cloudflare, not in Bynk.

== Where this leaves the shop <ix-guide-14-where-this-leaves-the-shop>

A hold is now reserved, then committed or released, and one that is neither
is released by a sweep within twenty minutes. The gap chapter 8 left is
closed. The inventory takes deliveries from the warehouse's queue, once each.

The shop is nearly finished, and so is its first version. The next chapter is
about the second: changing a system that is already running, without losing
what it has stored.
