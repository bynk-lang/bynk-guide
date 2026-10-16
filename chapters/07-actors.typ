#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let orders = "../snippets/chapter-07/shop/src/shop/orders.bynk"

= Actors <actors>

Every route in the shop says `by Visitor`, and means it. Anyone can place an
order, anyone can cancel anyone's order, and anyone can tell the warehouse it
has ten thousand more widgets. Chapter 1 noted that every HTTP route has to
say who may call it. This chapter makes the shop's routes say something other
than "anyone".

In a TypeScript Worker this is middleware: a function that reads the
`Authorization` header, verifies a token, and either stops the request or
hands the handler a user. In Bynk it is an _actor_: a declaration of a kind of
caller, which a route names in its `by` clause, and which the compiler turns
into the verification. The shop gets two: a customer, who owns the orders they
place, and an administrator, who manages the stock.

== The middleware you would write <ix-guide-07-the-middleware-you-would-write>

#lead-in[
By hand, a helper verifies the token with a JWT library, and each route that
needs a caller starts by calling it:
]

#code-listing(
  [Verifying a caller, by hand],
  read("../snippets/chapter-07/conventional.ts"),
  lang: "typescript",
)

Most of this is right, and the dangerous parts are subtle: comparing the
signature in constant time, checking the expiry, refusing a token whose `sub`
is missing or empty. `jose` handles the first two; the third is easy to
forget.

The bigger risk is in the last function. A route is protected because it
begins with two `if`s. Nothing about `restock`'s signature says it needs an
administrator, and a new route that forgets those lines is public. You find
out from a review, or from a stranger.

== Declaring the callers <ix-guide-07-declaring-the-callers>

#lead-in[
In Bynk the callers are declared once, at the top of `orders.bynk`:
]

#code-listing(
  [Two kinds of caller],
  source-lines(orders, 4, 25),
  lang: "bynk",
)

`Customer` is a `Bearer` actor. It verifies an HS256 JSON Web Token from the
`Authorization: Bearer …` header, signed with the secret in the environment
variable `AUTH_JWT_SECRET`. The secret itself never appears in the code; the
name of the variable does. A verified token's `sub` claim becomes the caller's
identity, typed as `CustomerId`, a non-empty string, so a token with an empty
`sub` is refused like any other bad token.#footnote[
  The Bynk Book, “Serve public and authenticated routes”, covers what the
  verification checks.
]

`Admin` is a _refinement_ of `Customer`: a customer whose verified token also
carries a truthy `admin` claim. An admin is a customer, with a customer's
identity, and can go anywhere a customer can.

Everything the TypeScript helper did by hand now happens at the boundary,
before a handler runs. The signature is checked in constant time, the expiry
is checked, and the identity is minted only from a token that passed. A
failure is a `401`. For `Admin`, a valid token without the claim is a `403`:
the runtime never says "who are you?" when it means "you may not".#footnote[
  The Bynk Book, “Add an authorisation invariant”.
]

== Routes that say who may call <ix-guide-07-routes-that-say-who-may-call>

#lead-in[
Now each route names its caller. Placing an order needs a customer, and the
order remembers whose it is:
]

#code-listing(
  [The order records its owner],
  source-lines(orders, 78, 92),
  lang: "bynk",
)

The `PUT` handler is `by c: Customer`, and opens the order with
`c.identity`. `c` is all a handler gets: it can read `c.identity`, and it can't
build a `Customer`, change one, or reach the token's other claims. So a
handler can't be called "as" a customer except by a caller who proved it.

#lead-in[
Looking up and cancelling an order need the same customer:
]

#code-listing(
  [The routes, chapter 6 to chapter 7],
  read("../snippets/chapter-07/routes.diff"),
  lang: "diff",
  breakable: true,
)

The changes are mostly one clause each, `by Visitor` becoming `by c: Customer`
or `by a: Admin`, and the compiler does the rest. Restocking is now
administrators only.

#lead-in[
Whose order it is gets checked in `shown`, which now takes the caller's
identity:
]

#code-listing(
  [Showing an order only to its owner],
  source-lines(orders, 210, 239),
  lang: "bynk",
)

Someone else's order is `None`, just like an order that doesn't exist, and so
is a `404`. A stranger can't use the difference between `403` and `404` to
learn which order ids are in use.

== One route, more than one caller <ix-guide-07-one-route-more-than-one-caller>

The last route in the diff is new in kind. `GET /stock/:sku` serves anyone,
but not the same answer to everyone. A visitor learns whether a product is in
stock; a signed-in customer also learns how many are left. Its `by` clause is
a sum, `who: Customer | Visitor`.

The boundary tries each member in order and binds the first that verifies. A
request with a valid token is a `Customer`; any other request is a `Visitor`.
The handler `match`es on `who`, exhaustively like any sum, and each arm answers
its own way.#footnote[
  The Bynk Book, “Serve several kinds of caller from one route”.
] The answer is the `Availability` sum, which serialises with a `kind`:
`{"kind":"InStock"}` for a visitor, `{"kind":"Left","count":10}` for a
customer.

Order matters. `Visitor` accepts everyone, so it has to come last.

#lead-in[
Put it first and the compiler points out that nothing after it can match:
]

#code-listing(
  [A catch-all first],
  source-lines("../snippets/chapter-07/visitor-first/src/shop/orders.bynk", 330, 333),
  lang: "bynk",
)

#compiler-message[
[bynk.actor.unreachable_sum_arm] Error: actor `Customer` is unreachable — an
earlier `None` peer accepts every caller
]

#lead-in[
And a refinement can't be a member at all. Try giving administrators the
count and customers only the yes-or-no:
]

#code-listing(
  [A refinement in a sum],
  source-lines("../snippets/chapter-07/admin-in-sum/src/shop/orders.bynk", 330, 343),
  lang: "bynk",
)

#compiler-message[
[bynk.actor.refinement_in_sum] Error: the refinement actor `Admin` cannot be a
peer in a multi-actor sum
]

Every `Admin` is a `Customer`, so the sum can't tell them apart by how they
verify, which is the only thing a sum's members are allowed to differ by. A
refinement is a whole route's caller, or nothing.

== From outside <ix-guide-07-from-outside>

To try the routes you need tokens, and `bynk dev` needs the secret to verify
them. Pass it through to Wrangler:

#code-listing(
  [Running with a local secret],
  "bynk dev -- --var AUTH_JWT_SECRET:not-a-secret",
  lang: "sh",
)

Any HS256 token signed with that secret will do. The transcript below uses
three, for `alice`, `bob` and an administrator, `root`, held in the shell
variables `$ALICE`, `$BOB` and `$ROOT`. The shop's `e2e/scenarios.sh` has a
short shell function that mints them with `openssl`.

#lead-in[
From outside:
]

#code-listing(
  [Callers, from outside],
  read("../snippets/chapter-07/responses.txt"),
  lang: "text",
)

No token is `401`; Alice's token on an administrator's route is `403`. A
visitor learns the widgets are in stock, Alice that ten are left. And Bob
asking for Alice's order gets the same `404` as for an order that was never
placed.

== Testing as a caller <ix-guide-07-testing-as-a-caller>

#lead-in[
A test acts as a caller with a `by` clause on the call:
]

#code-listing(
  [Calling a route as a customer],
  source-lines("../snippets/chapter-07/shop/tests/shop/orders.bynk", 104, 113),
  lang: "bynk",
)

At the unit tier, `by Customer("alice")` gives the handler the identity
directly. No token is signed or checked: the test is about what the handler
does with a caller, and the verification is the compiler's, tested once,
upstream.

Two routes in this chapter aren't tested that way, and not by choice. At
0.330.4 a test can't call a route guarded by a refinement actor like `Admin`
(bynk-lang/bynk#2019), or one whose `by` is a sum of actors
(bynk-lang/bynk#2020): depending on how you write the `by`, the checker
refuses the call or the generated test doesn't compile. The transcript above, which CI replays against `bynk dev` with real
tokens, covers both.

#code-listing(
  [The suite, run],
  read("../snippets/chapter-07/test-run.txt"),
  lang: "text",
)

== What it costs <ix-guide-07-what-it-costs>

`Bearer` verifies HS256 tokens signed with a shared secret, and that is all
it does. If your identity provider signs with RS256 and publishes its keys,
you want the `Oidc` actor, which this book leaves to the Book. Whatever
issues the tokens, though, is still yours: Bynk verifies them, and doesn't
sign them in.

Claims are untyped, so a refinement's predicate is a small closed set:
`hasClaim`, `claimEquals`, and the boolean operators. Rules that need more
than the token, such as "an administrator of this store", belong in the
handler, as the owner check does.

And an actor gives you identity, not permission. `by c: Customer` proves who
is asking. Whether they may touch this particular order is still a rule you
write, as `shown` does, and test.

== Where this leaves the shop <ix-guide-07-where-this-leaves-the-shop>

The shop knows who is calling every route, and refuses anyone who shouldn't.
It is also all one Worker: orders, stock and, soon, payments, in one context.
The next chapter splits it into the separate services it really is, and calls
from one to another over Service Bindings, where the caller is another context
rather than a person.
