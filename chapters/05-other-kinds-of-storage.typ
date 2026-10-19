#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let orders = "../snippets/chapter-05/shop/src/shop/orders.bynk"

= Other kinds of storage <other-kinds-of-storage>

The shop will take an order for a thousand widgets it doesn't have. Stock is
the next thing it needs to know about, and stock is a different kind of state
from an order. An order is one value, set once. Stock is a count that goes up
when the warehouse restocks and down when an order is placed, and while a
payment is being taken some of it is held back for one order and nobody
else.

A single `Cell` can't say all that. This chapter adds the product's stock as
a second agent, `Inventory`, and uses it to meet the rest of Bynk's storage:
`update` for a counter, a `Map` for the holds, and a `Query` to read across
them. The last part of the chapter looks briefly at three more kinds the shop
doesn't need: a `Log`, a `Cache` and Workers KV.

This chapter is lighter than the last. Agents, `Cell` and the commit are the
part of Bynk that 1.0 will hold stable; the richer storage kinds are newer, and
may still change in small ways through 1.x.

== The Durable Object you would write <ix-guide-05-the-durable-object-you-would-write>

#lead-in[
By hand, the stock is a Durable Object that keeps a count and one storage key
per hold, inside a transaction:
]

#code-listing(
  [Stock as a Durable Object, by hand],
  read("../snippets/chapter-05/conventional.ts"),
  lang: "typescript",
)

This is careful code. The transaction makes the check and the two writes one
step. The hold is keyed by order, so a retried reservation finds its earlier
hold and doesn't take the stock twice. And `held` reads every hold back by
listing a key prefix.

Most of that care is convention. The prefix `hold:` and the key
`"available"` are strings that every method has to spell the same way. The
types coming out of storage are assertions. And `held` loads every hold into
memory to add up one field, which is fine for ten holds and less fine for ten
thousand.

== A count, and `update` <ix-guide-05-a-count-and-update>

#lead-in[
Start with the types. In `orders.bynk`:
]

#code-listing(
  [Why stock is refused, and a hold],
  source-lines(orders, 49, 58),
  lang: "bynk",
)

`StockError` is the first `enum` in the shop: a sum type whose variants carry
nothing, written with the shorter spelling chapter 3 mentioned. It has one
variant now, and the shop never needs another.

#lead-in[
Then the agent:
]

#code-listing(
  [The stock of one product],
  source-lines(orders, 59, 102),
  lang: "bynk",
)

`Inventory` is keyed by `Sku`, so each product's stock is its own Durable
Object, and products never wait for each other.

`available` is a `Cell[Int]`, like chapter 4's line, but it is changed
differently. `available.update((v) => v + qty)` applies a function to the
current value, which is what a counter wants: you don't read, add and write
back. Unlike `:=`, `update` is a call into storage, an `Effect[()]`, and
`let _ <-` waits for it. That is chapter 3's warning about writes, now with a
write to point at. Reading `available` afterwards gives the new value:
a handler reads its own writes, though none of them is stored until it
returns.

== A map of holds <ix-guide-05-a-map-of-holds>

`holds` is a `Map[String, Hold]`: one entry per order holding stock. Its
operations, `contains`, `put`, `get`, `remove` and the rest, are calls into
storage like `update`, so each one is awaited.#footnote[
  The Bynk Book's agents reference lists every storage kind and its
  operations.
]

`reserve` checks for a hold first. If this order already holds stock, it
returns `Ok` without taking more, so a client that retries a request it
isn't sure arrived reserves once. Only then does it check the count, move the
units and record the hold. All of it commits together when `reserve`
returns, which is the transaction the TypeScript version opened by hand.

#lead-in[
The map is keyed by the order id as text, not by the `OrderId` itself. That
is a workaround, and `shop.values` gains a function for it:
]

#code-listing(
  [The order id as text],
  source-lines("../snippets/chapter-05/shop/src/shop/values.bynk", 40, 46),
  lang: "bynk",
)

A `Map` may be keyed by an opaque type, and its `.keys` and `.entries` then
yield that type. The shop keys `holds` by text and keeps the `OrderId` inside
the `Hold`, which is what an earlier release needed; keyed by `OrderId`, the
map would do without `orderRef`.

== Reading across the map: `Query` <ix-guide-05-query>

`held` adds up every hold in one expression:
`holds.values.fold(0, (n, h) => n + h.qty)`.

`holds.values` is a `Query[Hold]`: a description of a read, not the values
themselves. Methods such as `filter`, `map` and `sortBy` build a bigger
description. A _terminal_ such as `fold`, `count`, `first` or `collect` runs
it against storage. Because it touches storage, a terminal is an effect too,
and `held` returns its result as the handler's value. The same method names
work on an ordinary `List`, eagerly; on a store they run as a query, inside the
agent that owns the data.#footnote[
  The Bynk Book's types reference, under `Query`, covers the full vocabulary,
  including joins and grouping, and the `@indexed` annotation that turns an
  equality filter on a `Map` into an index lookup.
]

#lead-in[
That makes a `Query` local by design. Try handing one to the caller, the way
you might return a cursor:
]

#code-listing(
  [A query returned from a handler],
  read("../snippets/chapter-05/query-boundary/src/shop/orders.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.types.query_at_boundary] Error: a `Query` type cannot appear in an agent
handler signature — a query is built and executed in place, never persisted
or sent across a boundary
]

A handler's result crosses a boundary (here, the Durable Object's RPC), and
a query only means something next to its storage. Run it with a terminal, and
send the result.

== Reserving stock when an order is placed <ix-guide-05-reserving-stock>

#lead-in[
The `PUT` handler now reserves stock once the order is open:
]

#code-listing(
  [Opening, then reserving],
  source-lines(orders, 120, 133),
  lang: "bynk",
)

Two routes manage the stock itself: `PUT /stock/:sku` restocks with a
`{"qty":…}` body, and `GET /stock/:sku` reads the level. For now anyone can
call them; chapter 7 keeps them for an administrator.

#lead-in[
Stock ten widgets and place two orders:
]

#code-listing(
  [Stock, from outside],
  read("../snippets/chapter-05/responses.txt"),
  lang: "text",
)

The first order holds three widgets and leaves seven. The second asks for a
hundred and is refused. But look at the last request. Order `o2` was refused
for stock, and it exists anyway: the handler opened it before it found out
there was no stock to hold, and nothing undoes that. Every such refusal
leaves an order behind that will never be filled.

The fault is in the order, not the stock. It has two states, no line and a
line, and it needs at least one more: an order that was opened and then
turned down. That is the next chapter.

== Three more kinds <ix-guide-05-three-more-kinds>

The shop needs no more storage than this, but three more kinds are worth
knowing before you need them.

#lead-in[
Here they are together, in a small context of their own:
]

#code-listing(
  [A `Log`, a `Cache` and Workers KV],
  read("../snippets/chapter-05/kinds/src/notes.bynk"),
  lang: "bynk",
)

A `Log[T]` is append-only. `append` stamps each entry with the time, which is
why it needs `given Clock`, and `@retain(7.days)` drops entries older than a
week as new ones arrive. Reads are queries over a window: `since`, `before`,
`between`, `recent`. It suits history, an audit trail or a replay guard, and
chapter 10 uses one for exactly that: a payment's record of the notices it has
seen.

A `Cache[K, V]` is a `Map` whose entries expire. Its `@ttl` is required, and
an entry is checked for expiry as it is read, so a `Cache` needs a clock too.

#lead-in[
Leave out the lifetime and the compiler points you back to `Map`:
]

#code-listing(
  [A cache that never expires],
  read("../snippets/chapter-05/no-ttl/src/notes.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.store.cache_ttl_required] Error: a `Cache` field requires a
`@ttl(<duration>)` annotation — its entry lifetime
]

`Kv` is Workers KV, and it isn't agent storage at all: it is one namespace
the whole Worker shares, eventually consistent, reached as a capability
(`consumes bynk.cloudflare { Kv }` and `given Kv`). That `cloudflare` in the
name is honest. A context that consumes it runs only on Cloudflare, where the
rest of this chapter's storage would run on any target Bynk supports. Chapter 9
is about capabilities.

Choose by the shape of the state. One value per key goes in a `Cell`; a
keyed collection that belongs to one thing goes in a `Map`; history goes in a
`Log`; something you can rebuild goes in a `Cache`; and configuration or
content that many Workers read goes in `Kv`.

== Testing the stock <ix-guide-05-testing-the-stock>

#lead-in[
Three cases for `Inventory`, beside the earlier ones:
]

#code-listing(
  [Testing the stock],
  source-lines("../snippets/chapter-05/shop/tests/shop/orders.bynk", 41, 69),
  lang: "bynk",
)

#code-listing(
  [The suite, run],
  read("../snippets/chapter-05/test-run.txt"),
  lang: "text",
)

== The whole change <ix-guide-05-the-whole-change>

#lead-in[
Everything this chapter did to `orders.bynk`:
]

#code-listing(
  [`orders.bynk`, chapter 4 to chapter 5],
  read("../snippets/chapter-05/orders.diff"),
  lang: "diff",
)

== What it costs <ix-guide-05-what-it-costs>

The storage kinds beyond `Cell` are the least settled part of this book. They
work, and the shop depends on them, but they may move between releases more
than the rest; the canary will say when a chapter here stops being true.

The map is keyed by text, at the cost of one helper and a little type safety
at the key.

A query reads one agent's data. Nothing reads across every product's stock at
once: each `Inventory` is a separate Durable Object, and Durable Objects
can't be listed. Chapter 14 needs exactly that, and builds a catalogue to do
it.

== Where this leaves the shop <ix-guide-05-where-this-leaves-the-shop>

The shop counts its stock, holds it per order, and refuses an order it can't
fill, but it leaves the refused order behind. The next chapter gives an order
a life (open, then placed or turned down, then perhaps cancelled) as a state
machine that the compiler holds it to.
