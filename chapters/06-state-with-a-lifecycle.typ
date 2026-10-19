#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let orders = "../snippets/chapter-06/shop/src/shop/orders.bynk"
#let tests = "../snippets/chapter-06/shop/tests/shop/orders.bynk"

= State with a lifecycle <state-with-a-lifecycle>

Chapter 5 ended with an order that shouldn't exist. Order `o2` asked for more
stock than there was, the shop said `409`, and the order stayed behind, open,
holding nothing, answering `200` to anyone who looked it up.

The shop wasn't wrong to open the order before it checked the stock. Something
has to own the decision, and the order is the natural owner. What was missing
is a way for the order to say how the decision went. An order that has a line
and an order that has been turned down are different things, and so are an
order that was placed and one that was later cancelled.

This chapter gives the order a life: a status that starts in one place, moves
only in certain ways, and ends in a few. On the way it meets the two kinds of
rule Bynk checks on every commit, `transition` and `invariant`, and a kind of
test that drives an agent through whole histories rather than single calls.

== The Durable Object you would write <ix-guide-06-the-durable-object-you-would-write>

#lead-in[
By hand, the status is a string union stored beside the line, and each method
checks what it needs to:
]

#code-listing(
  [An order's status, by hand],
  read("../snippets/chapter-06/conventional.ts"),
  lang: "typescript",
)

The union type helps: `"canceled"` with one `l` won't compile. But the rules
about which moves are allowed are spread through the method bodies. `cancel`
checks that the order was placed; `confirm` and `reject` check nothing, so
nothing stops a caller rejecting a placed order, or confirming a rejected one.
The rule "a rejected order stays rejected" is written nowhere. It holds only as
long as every caller and every future method behaves.

== The order's states <ix-guide-06-the-orders-states>

#lead-in[
Start with the states, as an `enum`, and a record for what the agent hands
back:
]

#code-listing(
  [The states of an order],
  source-lines(orders, 28, 39),
  lang: "bynk",
)

An `enum` has no zero, so a field of one needs a starting value, and a
`Cell[Status]` without one is refused, as chapter 4's `Cell[OrderLine]` was.
That is the right answer here: a new order is `Pending` because the code says
so, not because `Pending` happens to come first.

`Snapshot` replaces chapter 4's bare `Option[OrderLine]` as what `view`
returns, because an order now has two things to report.

== The machine <ix-guide-06-the-machine>

#lead-in[
The agent, with its states and its rules:
]

#code-listing(
  [The order, with a lifecycle],
  source-lines(orders, 40, 89),
  lang: "bynk",
)

`store status: Cell[Status] = Pending` makes the field a state machine. The
initialiser names the start state, a `match` on `status` reads the current one,
and an assignment moves it.

`open` and `cancel` guard their moves with a `match`, and return an error from
any state they shouldn't move from. Both end in a `_` arm, so a sixth state
added later would fall into the error. Name every state instead when you want
the compiler to make you decide.

`confirm` and `reject` don't guard at all. The `PUT` handler calls exactly one
of them, once, straight after `open`, so there is nothing for them to check.
That is the kind of reasoning that holds until it doesn't, which is what the
two `transition` declarations are for.

== Transitions <ix-guide-06-transitions>

A `transition` is a rule about a move. It names the state before a commit as
`old` and the state after as `new`, and it must hold for every commit the agent
makes after its first.#footnote[
  The Bynk Book's testing guide, “Constrain a state change with `transition`”,
  and the agent-invariants reference.
] `rejected_is_final` says that an order that was rejected is still rejected
afterwards; `cancelled_is_final` says the same for a cancelled one.

They are checked by the runtime, at the commit, and not by the type checker.
Bynk doesn't decide which assignments to `status` are legal: any `Status` can
be assigned to it. What it does is refuse to persist a commit that breaks a
`transition`. If some future handler, or some future caller of `confirm`, tried
to move a rejected order on, the handler would fault: nothing it wrote would be
stored, and the request would end in a `500`.

That is a deliberate choice of failure. A broken transition isn't a business
outcome a caller should handle, like `NotPlaced`. It is a bug, and it stops
the bug from reaching storage.

== Placing, rejecting and cancelling <ix-guide-06-placing-rejecting-and-cancelling>

#lead-in[
Placing an order now decides it either way:
]

#code-listing(
  [Deciding the order],
  source-lines(orders, 216, 233),
  lang: "bynk",
)

#lead-in[
And a placed order can be cancelled, which gives its stock back:
]

#code-listing(
  [Cancelling an order],
  source-lines(orders, 249, 276),
  lang: "bynk",
)

`shown` and `OrderView` turn a `Snapshot` into what the customer sees, with the
status as a word. `None` means the order was never opened, and that is a
`404`.

#lead-in[
Cancelling releases the order's hold, so `Inventory` needs a `release`. It also
gains its first rule:
]

#code-listing(
  [`Inventory`, chapter 5 to chapter 6],
  read("../snippets/chapter-06/inventory.diff"),
  lang: "diff",
)

`release` is safe to call twice: once the hold is gone, it changes nothing.

#lead-in[
From outside:
]

#code-listing(
  [An order's life, from outside],
  read("../snippets/chapter-06/responses.txt"),
  lang: "text",
)

`o2` is still there after its `409`, but now it says what happened to it. And
cancelling `o1` brought its three widgets back.

== The stock invariant <ix-guide-06-the-stock-invariant>

`invariant available_non_negative: available >= 0` is the other kind of rule.
A `transition` constrains a move; an `invariant` constrains every state the
agent commits. Like a transition, it is checked at the commit, and a handler
that would break it faults instead of storing a negative count.

`reserve` already makes sure of it, by refusing to take more than is there. The
invariant says the same thing once, where every handler is held to it,
including the next one somebody writes and forgets to guard.

#lead-in[
The compiler also guards against the commonest way to break a counter. Write
the decrement as an assignment, the way you would in TypeScript:
]

#code-listing(
  [Read, subtract, write],
  source-lines("../snippets/chapter-06/self-reference/src/shop/orders.bynk", 128, 138),
  lang: "bynk",
)

#compiler-message[
[bynk.cell.self_reference] Error: the `:=` right-hand side reads `available`,
the cell being written — this is a read-modify-write
]

A `:=` that reads its own field is a read-modify-write, and Bynk wants it
spelled as one: `available.update((v) => v - qty)`, which says that the new
value depends on the old.

== Testing a life, not a moment <ix-guide-06-testing-a-life>

#lead-in[
Three new cases test single moves, and one property tests whole lives:
]

#code-listing(
  [Testing the lifecycle],
  source-lines(tests, 71, 111),
  lang: "bynk",
)

The cases are ordinary. The `property` is not. `for all run: History[Order]`
asks the test runner to generate runs of an `Order`: random sequences of its
handler calls, with arguments drawn from their types, each run against a fresh
order with its real handlers and its real transitions. `run` is the list of
steps it took, and each step carries the call and the states before and after.
The property says that whenever a step moved an order into `Cancelled`, the
order was `Placed` just before.#footnote[
  The Bynk Book's testing reference, “History properties”.
]

#lead-in[
To see what that buys, break `cancel` so that it also cancels an `Opened`
order, and run the suite. The part of the output that matters:
]

#code-listing(
  [A history property, failing],
  read("../snippets/chapter-06/history-failure.txt"),
  lang: "text",
)

The runner found a run that broke the property, then shrank it to the
shortest one that still does: open an order, then cancel it. The values in it,
and the seed, are random and will differ on your machine; the shape won't. A
handwritten case only finds that bug if you think to write that case.

#lead-in[
There is one property you shouldn't write, and the compiler stops you. Test
the stock invariant this way:
]

#code-listing(
  [A property that repeats an invariant],
  read("../snippets/chapter-06/restates/tests/shop/orders.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.history.restates_invariant] Error: history property `stock never goes
negative` merely re-checks a guarantee agent `Inventory`'s
`invariant`/`transition` already enforces on every reached state
]

Every state a run can reach has already passed the invariant, so the property
can't fail. Spend the test on something the agent doesn't already promise.
The same check catches a property that restates a `transition`.

#lead-in[
The run:
]

#code-listing(
  [The suite, run],
  read("../snippets/chapter-06/test-run.txt"),
  lang: "text",
)

== What it costs <ix-guide-06-what-it-costs>

A `transition` is a rule about pairs of states, not a table of every legal move.
Bynk has no syntax yet for "an order can go from here only to there"; you write
the moves you want to forbid, one at a time, and the rest are allowed.

Breaking a rule is a fault, not a value. The request ends in a `500`, and the
caller learns nothing it can act on. That is right for bugs and wrong for
anything a customer can cause, which is why `cancel` still returns
`Err(NotPlaced)` instead of leaning on a transition.

A history property is a sample, not a proof. It runs a bounded number of
bounded histories, and a bug that needs a long, particular run can hide from
it.

And the stored status is now part of the order's schema. Renaming a state, or
adding one in the middle, changes what every stored order means, which is
chapter 15's subject.

== Where this leaves the order <ix-guide-06-where-this-leaves-the-order>

An order is placed or turned down, can be cancelled once, and gives its stock
back when it is. But anyone can do any of it. Any visitor can place an order,
cancel someone else's, or restock the warehouse. Part III is about who is
calling, and starts with that.
