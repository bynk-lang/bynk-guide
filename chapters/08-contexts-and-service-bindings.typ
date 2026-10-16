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
  source-lines(inventory, 75, 106),
  lang: "bynk",
)

An `on call` service is a handler other contexts call, not customers. Another
context reaches it through a Service Binding. `by c: Caller` names who called:
`c.identity` is the calling context's qualified name, such as `"shop.orders"`,
stamped by the compiler at the call site. It tells you who is asking, not
whether they may. (How private that channel really is, at 0.330.4, comes up at
the end of the chapter.)#footnote[
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

There is a second rule, which the compiler doesn't yet enforce. The `Order`
agent could, in principle, call `Stock.reserve` itself. At 0.330.4 that
compiles and then fails at run time (bynk-lang/bynk#1960), so in this shop the
`api` service makes every call to another context, and the agents keep to
their own state. Because of the pattern above, the shop doesn't miss it.

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
between them are wired. At 0.330.4 several contexts also need `--inspect`, or
their debuggers collide on one port and they fail to start
(bynk-lang/bynk#1954):

#code-listing(
  [Running three contexts],
  "bynk dev --inspect -- --var AUTH_JWT_SECRET:not-a-secret",
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

The safe ways are the public ones. Put the Bynk Worker in front of your
existing ones, or call its `from http` routes from them, as any client would.
A hand-written Worker _can_ call a Bynk context's `on call` services over a
Service Binding, but at 0.330.4 only by imitating the compiler: a private
request path, a contract hash copied from the build, and a caller name it
simply asserts. That is an internal protocol, not an API. Upstream has since
documented the protocol and started signing every internal call, but neither
is in a release yet; the work is tracked as bynk-lang/bynk#1973.

== Testing a context <ix-guide-08-testing-a-context>

Each context has its own suite now. The inventory suite keeps chapter 5's and
chapter 6's cases, and the payments suite tests `fakeCharge`.

#lead-in[
A test can call a context's service as another context would, with `by
Caller(…)`:
]

#code-listing(
  [Calling a service as orders would],
  source-lines("../snippets/chapter-08/shop/tests/shop/inventory.bynk", 41, 53),
  lang: "bynk",
)

Leave the `by Caller(…)` out and, at 0.330.4, the check passes and the test
fails to compile (bynk-lang/bynk#1978), so write it every time.

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
pyramid. Bynk has no `?` for a handler's `HttpResult`, as chapter 3 showed, so
the alternative is to move the decisions into functions that return a
`Result`, and match once.

And compensation is yours. The type checker can see that `Stock.reserve`
returns a `Result` that you handled. It can't see that you released the stock
on every path that should.

Finally, a warning that matters as soon as you deploy. At 0.330.4 the internal
channel is less private than it looks. A context's Worker answers its
`on call` services on every route it has, and a deployed Worker keeps
Cloudflare's default `workers.dev` address unless you turn it off. Anyone who
finds that address can call the services, and name any caller they like. The
fix is on Bynk's main branch, signing every call between contexts with a key
per pair (bynk-lang/bynk#2004 and #2012), and isn't in a release yet. Until it
is, turn off the `workers.dev` route for contexts with no public routes of
their own, such as inventory. That doesn't protect a context that has public
routes too, because every route serves the internal paths; chapter 12 comes
back to this when it deploys.

== Where this leaves the shop <ix-guide-08-where-this-leaves-the-shop>

The shop is three Workers that call each other with the types checked at both
ends. Its payments are still a function that says yes under a thousand. The
next chapter puts a real processor behind a _capability_, and shows how to
keep the fake for tests without editing the code that uses it.
