#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let inventory = "../snippets/chapter-08/shop/src/shop/inventory.bynk"

= Contexts and Service Bindings <contexts-and-service-bindings>

So far the shop is one Worker. Orders, stock and, from this chapter, payments
all live in one context, deploy together and fail together. That was the right
place to start, and it is not where a shop stays. Stock is touched by every
order and by the warehouse; payments talk to a processor that is slow and
sometimes down; orders are what customers see. They change at different
rates, for different reasons, and a bug in one shouldn't take the others with
it.

On Cloudflare the usual answer is several Workers joined by Service Bindings:
one Worker calls another directly, inside Cloudflare's network, without a
public URL between them. This chapter splits the shop that way, into three
_contexts_. Each one is a Worker, and the calls between them are Bynk calls
that the compiler turns into Service Binding calls, typed at both ends.

== The Service Bindings you would write <ix-guide-08-the-service-bindings-you-would-write>

#lead-in[
By hand, the inventory and payments Workers each export a `WorkerEntrypoint`,
and the orders Worker calls them through bindings it declares an interface
for:
]

#code-listing(
  [Calling two Workers, by hand],
  read("../snippets/chapter-08/conventional.ts"),
  lang: "typescript",
)

#lead-in[
And the bindings, declared in the orders Worker's configuration:
]

#code-listing(
  [The bindings, by hand],
  read("../snippets/chapter-08/conventional-wrangler.toml"),
  lang: "toml",
)

Cloudflare's RPC is good, and this code is short. The weak point is the
interfaces at the top. They are copies, by hand, of what the other Workers
export, and nothing checks the copy against the original. Rename a parameter
or change a return type in the inventory Worker, deploy it, and the orders
Worker still compiles. It finds out at run time, or worse, gets a value of the
wrong shape and carries on. Nor does anything check the arguments as they
arrive: whatever the caller sends is what the callee gets.

== Three contexts <ix-guide-08-three-contexts>

The shop becomes three files beside `values.bynk`: `orders.bynk`,
`inventory.bynk` and `payments.bynk`. By the path rule from chapter 1, their
contexts are `shop.orders`, `shop.inventory` and `shop.payments`, and each one
compiles to its own Worker. All three say `uses shop.values`, so they share
the shop's vocabulary from chapter 2: a `Sku` is a `Sku` in all of them.

#lead-in[
The inventory context is chapter 5's `Inventory` agent, moved, with a new
first few lines:
]

#code-listing(
  [The inventory context begins],
  source-lines(inventory, 0, 5),
  lang: "bynk",
)

`exports transparent { StockError }` lets other contexts see `StockError`
and match on its variants. A context's types are its own unless it exports
them; `Hold`, which no one else needs, stays private.

== A context's public face <ix-guide-08-a-contexts-public-face>

#lead-in[
Other contexts can't reach the `Inventory` agent. What they can call are the
services the context offers:
]

#code-listing(
  [What inventory offers other contexts],
  source-lines(inventory, 80, 111),
  lang: "bynk",
)

An `on call` service is a handler other contexts call, not customers. Another
context reaches it through a Service Binding. `by c: Caller` names who called:
`c.identity` is the calling context's qualified name, such as `"shop.orders"`,
stamped by the compiler at the call site, and signed, so a context can't
claim to be another. It tells you who is asking, not whether they may. (How
that signing works comes up at the end of the chapter.)#footnote[
  The Bynk Book, “Consume another context's services” and “Know which context
  called you”.
]

Each service hands straight on to the agent. That is the shape the rest of the
shop follows: _a service coordinates, and an agent owns state_. The agent
never sees another context, and other contexts never see the agent.

== Payments, for now <ix-guide-08-payments-for-now>

#lead-in[
The payments context is new, and small:
]

#code-listing(
  [The payments context],
  read("../snippets/chapter-08/shop/src/shop/payments.bynk"),
  lang: "bynk",
)

`fakeCharge` is a stand-in for a card processor, as a pure function. It
declines anything over 1,000.00, so the shop has a failure to handle. Chapter 9
puts a real processor behind it, and shows how to swap the fake back in for
tests.

== Calling across <ix-guide-08-calling-across>

#lead-in[
The orders context declares what it consumes, and the placement flow gains a
payment step:
]

#code-listing(
  [`orders.bynk`, chapter 7 to chapter 8],
  read("../snippets/chapter-08/orders.diff"),
  lang: "diff",
  breakable: true,
)

`consumes shop.inventory as Stock` makes the inventory context's services
callable as `Stock.reserve(…)`, `Stock.release(…)` and so on, with the
signatures the inventory context declares. They are effects, and `let held <-`
waits for each one. On the `workers` target the call is a JSON request over the
Service Binding; the arguments are checked against their types as they arrive,
as chapter 2 promised, and so is the result on the way back.

There is no interface to copy. The orders context is type-checked against the
inventory context's real services, in the same build, so a renamed parameter
or a changed return type in one context breaks the build of the other.

== Only through a service <ix-guide-08-only-through-a-service>

#lead-in[
The agent is still there, one context over, and it is tempting to call it:
]

#code-listing(
  [Reaching into another context],
  source-lines("../snippets/chapter-08/agent-across/src/shop/orders.bynk", 276, 281),
  lang: "bynk",
)

#compiler-message[
[bynk.consumes.unknown_service] Error: context `shop.inventory` has no service
named `Inventory`
]

Another context's state is reachable only through the services it chose to
offer. That is what makes a context a boundary: the inventory context can
change how it stores stock without asking anyone, so long as its services
still mean the same thing.

The `Order` agent could call `Stock.reserve` itself; an agent's handler may
call another context, as a service's may. The shop doesn't, by choice: the
`api` service makes every call to another context, and each agent keeps to its
own state. A service coordinates and an agent owns, and keeping the two apart
means an agent's handler never waits on another Worker while it holds its own
state.

== No cycles <ix-guide-08-no-cycles>

#lead-in[
Contexts that consume each other are refused. Suppose inventory wanted to look
at an order:
]

#code-listing(
  [Inventory consuming orders],
  source-lines("../snippets/chapter-08/cycle/src/shop/inventory.bynk", 0, 5),
  lang: "bynk",
)

#compiler-message[
[bynk.context.consumes_cycle] Error: `consumes` cycle detected: shop.orders →
shop.inventory → shop.orders
]

The `consumes` graph must have no cycles. Each edge is a Service Binding, and a
cycle of bindings has no context that can be deployed first. It also keeps the
design honest: inventory doesn't need to know orders exist. Chapter 13 meets
this rule again, when events would need a cycle that the shop can't have.

== What the compiler wrote <ix-guide-08-what-the-compiler-wrote>

#lead-in[
The orders Worker's generated `wrangler.toml` now has its bindings:
]

#code-listing(
  [The generated `wrangler.toml`],
  read("../snippets/chapter-08/emitted/wrangler.toml"),
  lang: "toml",
)

Two `[[services]]` bindings, one per `consumes`, and chapter 4's Durable Object.
Each cross-context call also carries the calling context's name, which is
what `Caller` reads, and a hash of the service's signature. If the two Workers
are deployed out of step and the signature no longer matches, the call is
refused with a `409` instead of being misread. Chapter 15 is about that.

== From outside <ix-guide-08-from-outside>

`bynk dev` now serves three Workers, on consecutive ports in the order of
their names: inventory on 8787, orders on 8788, payments on 8789. The bindings
between them are wired, and each signs and checks its calls with a fixed local
key:

#code-listing(
  [Running three contexts],
  "bynk dev -- --var AUTH_JWT_SECRET:not-a-secret",
  lang: "sh",
)

#lead-in[
Through the orders Worker, with chapter 7's tokens:
]

#code-listing(
  [Three Workers, from outside],
  read("../snippets/chapter-08/responses.txt"),
  lang: "text",
)

The second order was declined by payments, so its stock was released and the
level is back to seven. And the inventory Worker on 8787 has no routes of its
own: a plain request finds nothing, because its services are meant for other
contexts.

== Compensation, by hand <ix-guide-08-compensation-by-hand>

Look again at the declined payment. The handler had already reserved stock, so
when payments said no, it released the stock and rejected the order. That is
_compensation_: undoing an earlier step because a later one failed, written
out by hand.

It isn't crash-safe. If the Worker dies between reserving the stock and
releasing it (a deploy, an exception, the platform recycling the isolate), the
hold stays, and nobody will release it. Each step is atomic inside its own
agent; the sequence across three contexts is not. Bynk's answer to this is
_sagas_, multi-step workflows with their compensations declared. They are
planned and not yet in the language, so the shop covers the gap another way:
chapter 14 adds a job that releases holds left too long.

== Beside an existing Worker <ix-guide-08-beside-an-existing-worker>

You may not be starting from nothing. If you have Workers already, the
question is how a Bynk context sits beside them.

The simplest way is the public one: put the Bynk Worker in front of your
existing ones, or call its `from http` routes from them, as any client would.

A TypeScript Worker can also call a context's `on call` services directly,
over a Service Binding. The context declares it as an actor with the `Foreign`
scheme and names that actor in each service it may call. The build then writes
a typed TypeScript client for it, `bynk-client.ts`, with one function per
service the actor is admitted to, and `bynk deploy` mints the key the two
Workers sign their calls with. The other direction works too: a context can
call a Worker outside the project through an experimental `Service`
capability.#footnote[
  The Bynk Book, “Adopt Bynk beside a TypeScript Worker”.
]

So you can move a system over one Worker at a time. The shop doesn't need to,
but a real migration would start here.

== Testing a context <ix-guide-08-testing-a-context>

Each context has its own suite now. The inventory suite keeps chapter 5's and
chapter 6's cases, and the payments suite tests `fakeCharge`.

#lead-in[
A test can call a context's service as another context would, with `by
Caller(…)`:
]

#code-listing(
  [Calling a service as orders would],
  source-lines("../snippets/chapter-08/shop/tests/shop/inventory.bynk", 42, 54),
  lang: "bynk",
)

Leave the `by Caller(…)` out and the check refuses the case: a service that
binds `by c: Caller` needs to know who is calling, in a test as in
production.

A test of the orders routes would now cross into inventory and payments, and a
unit test runs one context in process. Testing all three together is the
`system` tier, and chapter 11 is about tiers. Until then, the orders suite tests
its agent and its functions, and the transcript above covers the routes.

#code-listing(
  [The three suites, run],
  read("../snippets/chapter-08/test-run.txt"),
  lang: "text",
)

== What it costs <ix-guide-08-what-it-costs>

Three Workers are three things to deploy, watch and keep in step. Every call
between them is a network hop and a round of JSON, where it used to be a
function call. Split along the lines your system really has, and no further.

The placement handler is now six `match`es deep. Each level is a real
decision, and the compiler makes sure none is missed, but it reads as a
pyramid. Bynk has no `?` for a handler's `HttpResult`, as chapter 3 showed.
`let … else` flattens it: `let Ok(_) <- Stock.reserve(…) else { … }` binds
on success and handles the failure beside the step, so the chain reads top to
bottom. The shop keeps the nesting, which shows each decision where it's
made.#footnote[
  The Bynk Book, “Work with `Result` and optional values”: `let … else`.
]

And compensation is yours. The type checker can see that `Stock.reserve`
returns a `Result` that you handled. It can't see that you released the stock
on every path that should.

Finally, how private the channel between contexts is. A context's Worker
answers its `on call` services on every route it has, including the
`workers.dev` address Cloudflare gives a deployed Worker. What keeps them
private is a signature. Each pair of contexts that call each other shares a
key, which `bynk deploy` mints and sets on both Workers, and every call is
signed with it. A Worker refuses a call whose signature doesn't verify for the
caller it names, with a `401`, before anything else. So a request from the
internet gets nowhere, and one context can't claim to be another. Chapter 12
shows the keys in the deploy plan.

== Where this leaves the shop <ix-guide-08-where-this-leaves-the-shop>

The shop is three Workers that call each other with the types checked at both
ends. Its payments are still a function that says yes under a thousand. The
next chapter puts a real processor behind a _capability_, and shows how to
keep the fake for tests without editing the code that uses it.
