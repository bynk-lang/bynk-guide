#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let orders = "../snippets/chapter-04/shop/src/shop/orders.bynk"

= An agent is a Durable Object <an-agent-is-a-durable-object>

Place order `o1` twice and the shop of chapter 3 says `201` both times. The id
is the customer's, and it is supposed to mean "this order": a client that
retries a request it isn't sure arrived should not place the order again.
For that, the shop has to remember which ids it has seen.

On Workers, state keyed by an id is what a Durable Object is for. Each id
gets one object, every request for that id reaches the same object, and the
object keeps its own storage. You have probably written one.

This chapter gives each order a Durable Object, written as a Bynk _agent_. The
order remembers its line, refuses to be opened twice, and can be looked up
afterwards. Along the way you meet the rule that shapes all stored state in
Bynk: a fresh agent has to start somewhere.

== The Durable Object you would write <ix-guide-04-the-durable-object-you-would-write>

#lead-in[
By hand, the order is a class with two RPC methods, and the Worker reaches it
through a namespace binding:
]

#code-listing(
  [An order as a Durable Object, by hand],
  read("../snippets/chapter-04/conventional.ts"),
  lang: "typescript",
)

#lead-in[
The binding and the class need declaring in `wrangler.toml`, with a migration
that creates the class's storage:
]

#code-listing(
  [Its configuration, by hand],
  read("../snippets/chapter-04/conventional-wrangler.toml"),
  lang: "toml",
)

This works well, and the platform does the hard part: requests for one id
reach one object, one at a time. What is left to you is keeping several
things in step. The storage key `"line"` is a string, written in two methods;
`get<OrderLine>` is an assertion, not a check, so whatever was stored under
that key comes back typed as an `OrderLine`. The class name appears in the
code, in the binding and in the migration, and the binding name `ORDER` in
the config and in `Env`. A typo in any of them is found at run time.

== An agent <ix-guide-04-an-agent>

#lead-in[
In Bynk the order is an `agent`. Add it to `orders.bynk`, after `total`:
]

#code-listing(
  [The order, as an agent],
  source-lines(orders, 27, 48),
  lang: "bynk",
)

`key id: OrderId` is the agent's identity. `Order(id)` names the instance for
that id, and on the `workers` target each instance is a Durable Object. Two
calls with the same id reach the same state; different ids never share any.

`store line: Cell[Option[OrderLine]]` is its state: one stored value, typed.
There is no storage key to spell and no assertion on the way out. A handler
reads the field by name and writes it with `:=`.

The writes are not calls you wait for. Everything a handler assigns is
collected and committed together when the handler returns, atomically: all
of it, or, if the handler faults, none.#footnote[
  The Bynk Book, “The agent model”, and the agents reference on commits.
] `open` either stores the line and returns `Ok`, or finds one already there
and returns `Err(AlreadyDecided)`. That is the variant this chapter adds to
`OrderError`.

== Why the line is optional <ix-guide-04-why-the-line-is-optional>

A Durable Object comes into being the first time something asks for its id.
There is no constructor to call first, so a brand-new `Order` has to have a
state already. Bynk calls this its _zero_: every `store` field must have one,
or an initialiser that supplies it. An `Int` starts at `0`, a `String` at
`""`, and an `Option` at `None`.

An `OrderLine` has no zero. Its `sku` is an opaque, non-empty string and its
quantity starts at 1, so there is no honest "empty order line" to start
from, and a `Cell[OrderLine]` is refused
(`bynk.agents.non_zeroable_state_field`).#footnote[
  Chapter 5 of “Architecture that compiles”, “State needs an owner”, shows
  that refusal and argues for the rule.
] What a fresh order really has is _no line yet_, and `Option[OrderLine]`
says exactly that: `None` until the order is opened, `Some(line)` after.

This is where `Option` belongs in the book. It is Bynk's answer to
`undefined`, and the difference is that you can't forget it. A handler that
reads `line` gets an `Option`, and has to say what happens when it is `None`
before it can use the line.

== Calling the agent <ix-guide-04-calling-the-agent>

#lead-in[
The `PUT` handler opens the order once the total has passed:
]

#code-listing(
  [Placing an order, once],
  source-lines(orders, 50, 72),
  lang: "bynk",
)

`Order(id).open(body)` is a call to another object, an RPC to the Durable
Object, so it is an effect, and `let opened <-` waits for its `Result`. An
order that is already open is a `409`.

#lead-in[
And a route to look an order up:
]

#code-listing(
  [Looking an order up],
  source-lines(orders, 73, 82),
  lang: "bynk",
)

`view` returns the `Option`, and the handler decides what `None` means over
HTTP: `NotFound`, a `404` with an empty body.

== A call you forget to wait for <ix-guide-04-a-call-you-forget-to-wait-for>

#lead-in[
In TypeScript, forgetting `await` on an RPC is easy, and it compiles. Write
the same slip here, binding the call with `=` instead of `<-`:
]

#code-listing(
  [An agent call with no arrow],
  source-lines("../snippets/chapter-04/no-arrow/src/shop/orders.bynk", 58, 63),
  lang: "bynk",
)

#compiler-message[
[bynk.effect.unbound_effect] Error: this `Effect` is started here and never
awaited — it runs eagerly, out of order with everything after it
]

This is the floating promise, and in TypeScript only a lint rule catches it.
Here it doesn't compile. `opened` would have been an `Effect`, a call in
flight, rather than its result, and the handler would have answered `201`
whether or not the order was opened.

== A match that no longer covers every case <ix-guide-04-a-match-that-no-longer-covers>

Chapter 3 claimed that adding a variant to `OrderError` would make every
`match` that names variants one by one stop compiling. This chapter added
`AlreadyDecided`, so here is that claim tested.

#lead-in[
Chapter 3's handler matched `total`'s result like this:
]

#code-listing(
  [Chapter 3's match, unchanged],
  source-lines("../snippets/chapter-04/non-exhaustive/src/shop/orders.bynk", 54, 58),
  lang: "bynk",
)

#compiler-message[
[bynk.types.non_exhaustive_match] Error: non-exhaustive `match` — variant
`Err(AlreadyDecided)` of `Result[Cents, OrderError]` is not covered
]

`total` can never return `AlreadyDecided`, but its type says it might, and
the compiler goes by the type. The handler now says `Err(_)`. That is the
cost of one error type shared between functions, from chapter 3's last
section, arriving on schedule.

== What the compiler wrote <ix-guide-04-what-the-compiler-wrote>

#lead-in[
Compile for Workers and look at the orders Worker's `wrangler.toml`:
]

#code-listing(
  [The generated `wrangler.toml`],
  read("../snippets/chapter-04/emitted/wrangler.toml"),
  lang: "toml",
)

The binding and the Durable Object class are there because the program has
an agent, under names the generated code also uses. The class is declared
with SQLite storage through `exports`, so there is no migration block to
write. The class itself is in `handlers.ts`: it loads the state for its key,
runs the handler against it, and commits what the handler wrote.

== From outside <ix-guide-04-from-outside>

#lead-in[
Place `o1` twice, then look it up:
]

#code-listing(
  [One order id, used twice],
  read("../snippets/chapter-04/responses.txt"),
  lang: "text",
)

The second `PUT` changed nothing. The stored line is still the first one,
with three units.

== Testing an agent <ix-guide-04-testing-an-agent>

#lead-in[
A test can call an agent directly, by key. Two new cases:
]

#code-listing(
  [Testing the order],
  source-lines("../snippets/chapter-04/shop/tests/shop/orders.bynk", 25, 40),
  lang: "bynk",
)

`bynkc test` gives each agent an in-memory store, so there is nothing to set
up: no Miniflare, no storage to clear.

#lead-in[
The run:
]

#code-listing(
  [The suite, run],
  read("../snippets/chapter-04/test-run.txt"),
  lang: "text",
)

== The whole change <ix-guide-04-the-whole-change>

#lead-in[
Everything this chapter did to `orders.bynk`:
]

#code-listing(
  [`orders.bynk`, chapter 3 to chapter 4],
  read("../snippets/chapter-04/orders.diff"),
  lang: "diff",
)

== What it costs <ix-guide-04-what-it-costs>

An agent is a Durable Object, with a Durable Object's shape. Each order lives
alone, so nothing can ask "which orders are there?" without some other place
that keeps a list. Chapter 14 builds one for the stock.

Stored state now has a schema. Change `OrderLine` and every stored order still
holds the old shape. Chapter 15 is about what Bynk does when you change it,
and what it can't do yet.

The zero rule takes some getting used to. Every field needs an honest
starting value, which often means an `Option` and a `match` where TypeScript
would have let you write `!`.

Two things don't work yet, and the shop steers round both. An agent handler
shouldn't call another context: at 0.330.4 that compiles and then fails at
run time, so from chapter 8 the shop's services make those calls and agents
keep to their own state (bynk-lang/bynk#1960). And don't use `~>` on a store
operation such as `update`: there is nothing to send, since writes commit
together, and the compiler accepts it but the build then fails
(bynk-lang/bynk#2017).

== Where this leaves the order <ix-guide-04-where-this-leaves-the-order>

An order can be placed once and looked up. It has no stock behind it, though:
the shop will happily take an order for a thousand widgets it doesn't have.
Stock is a different kind of state, a count that goes up and down and holds
some units back while a payment is taken, and the next chapter meets the
storage kinds it needs.
