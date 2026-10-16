#import "../template.typ": code-listing, compiler-message, lead-in

#let source-lines(path, start, end) = {
  read(path).split("\n").slice(start, end).join("\n")
}

= Types you can trust <types-you-can-trust>

The shop's first job is to take an order. A customer sends
`PUT /orders/o1` with a small JSON body: which product, how many, and the
price they were shown. Before anything is reserved or charged, the Worker
has to decide whether that body is an order at all.

You have written this Worker before. This chapter writes it twice: once in
TypeScript, the way you would today, and once in Bynk. The Bynk version is
not shorter once its doc comments are counted, and length is not the point.
The point is what each version still knows about the order once the check
has passed.

By the end of the chapter the shop has a vocabulary of its own: a sku, an
order id, a quantity and a price, each with a rule that is checked once, at
the edge, and then carried by the type. It also has its first test.

== The Worker you would write <ix-guide-02-the-worker-you-would-write>

#lead-in[
A careful TypeScript Worker validates the body with a schema library and
brands the identifiers so they can't be confused with other strings. With
zod, it looks like this:
]

#code-listing(
  [Validating an order by hand],
  read("../snippets/chapter-02/conventional.ts"),
  lang: "typescript",
)

There is nothing wrong with this code. The schema is declared once and the
type is inferred from it, so the two can't drift apart. The skus are
branded, so a plain string won't pass for one. The check happens before the
order goes any further, and a bad body is a `400`.

Look at what is left after the check, though. `line.data.qty` is a
`number`. The schema established that it is a whole number between 1 and
1,000, and then the type forgot. A function three calls later that takes
`qty: number` can't tell this value from any other number, so either it
trusts the call chain or it checks again.

#lead-in[
The brand is stronger, but it holds only while everyone agrees not to write
a cast. This compiles, wherever `Sku` is in scope:
]

#code-listing(
  [A brand is one cast away],
  read("../snippets/chapter-02/conventional-cast.ts"),
  lang: "typescript",
)

Two smaller gaps sit in the handler itself. `request.json()` throws on a
body that isn't JSON, so a truncated request is a `500`, not a `400`, unless
you remember to catch it. And the `400` says only that the order is
invalid: if you want the client to know which field failed, you format
zod's errors yourself.

None of this is a reason to stop using zod. It is the reason Bynk puts the
same ideas in the language, where the compiler can hold you to them.#footnote[
  Chapter 2 of “Architecture that compiles”, “A data shape is not a domain
  model”, makes the general argument. This chapter is the practical half.
]

== A vocabulary for the shop <ix-guide-02-a-vocabulary-for-the-shop>

The shop is a new project, set up as chapter 1 showed: a `bynk.toml`
naming it `shop`. Its units are named `shop.…`, so by the path rule from
chapter 1 their files live under `src/shop/`. The rest of the book grows
this one project.

#lead-in[
Start with the values the shop cares about, not with the request. Create
`src/shop/values.bynk` and declare them:
]

#code-listing(
  [The shop's vocabulary],
  source-lines("../snippets/chapter-02/shop/src/shop/values.bynk", 0, 22),
  lang: "bynk",
)

A `commons` holds pure types and functions: no state, no effects, nothing
that runs on its own. It compiles to plain TypeScript types and functions,
and any context in the project can use it. The text between `---` lines is
documentation. It belongs to the declaration that follows, and the
language server shows it on hover.#footnote[
  The Bynk Book, “How a program is shaped” and “Document your code”.
]

There are two kinds of type here, and they make different promises.

`Quantity` and `Cents` are _refined_ types: an `Int` with a predicate. A
`Quantity` is a whole number from 1 to 1,000, and every `Quantity` in the
program has passed that check.#footnote[
  `InRange` and `NonEmpty` are two of several predicates. The Bynk Book's
  refined-types reference lists them all, and how they combine.
] Anywhere an `Int` is wanted, you can pass a
`Quantity`: reading a refined value as its base is always safe. Going the
other way is not, so an `Int` doesn't become a `Quantity` without being
checked.

`Sku` and `OrderId` are _opaque_ types. Both are non-empty strings, so the
predicate alone can't tell them apart. `opaque` gives each its own identity:
a `Sku` is not a `String`, and it is not an `OrderId`, even though all three
are strings underneath. Outside `shop.values`, no code can see the string
inside a `Sku` or make one from a string without going through the commons.

This is the brand from the TypeScript version, with the cast taken away.

== An order line, and a route that takes one <ix-guide-02-an-order-line>

#lead-in[
Now the request. In `src/shop/orders.bynk`, the orders context uses the
vocabulary and builds a record from it:
]

#code-listing(
  [The order line and the route],
  read("../snippets/chapter-02/shop/src/shop/orders.bynk"),
  lang: "bynk",
)

`uses shop.values` brings the commons into the context. `OrderLine` is a
record, like the zod object, but its fields are the shop's types rather
than strings and numbers. The route takes the `:id` from the URL as an
`OrderId` and the body as an `OrderLine`, and for now it answers `201` with
the line it was given. Nothing is stored yet: chapter 4 gives each order a
place to live. `by Visitor` says anyone may call the route; chapter 7 is
about who is calling.

There is no validation code in the handler, and none was left out. The
parameter types are the validation.

== What happens at the boundary <ix-guide-02-what-happens-at-the-boundary>

#lead-in[
Run `bynk dev` and send it some orders. Each response below shows the
status, then the body, wrapped to fit the page:
]

#code-listing(
  [The boundary, from outside],
  read("../snippets/chapter-02/responses.txt"),
  lang: "text",
)

The compiler generated all of that. Before the handler runs, the Worker
reads the body, parses it, and checks it against `OrderLine` field by field:
the shape first, then each refinement. The first failure is the response,
with the path of the field that failed and, for a refinement, the rule it
broke. A body that isn't JSON at all is a `400`, not a `500`. The same
admission applies to `:id`: the route parameter becomes an `OrderId` by the
same check, and the handler never sees an empty one.

Once the handler starts, `body.qty` is a `Quantity`. It doesn't need
checking again here, or in any function it is passed to, because no other
kind of value can be a `Quantity`.

The rule is checked in one more place. When chapter 8 splits the shop into
contexts, an `OrderLine` sent from one Worker to another over a Service
Binding is checked again on arrival. A refined type is a promise that holds
at every boundary, not only the first.

== Who may make a sku <ix-guide-02-who-may-make-a-sku>

Values from outside are admitted by the boundary. Values you write in the
program need a way in too.

#lead-in[
Try making a `Sku` the way the TypeScript cast did, by asserting it:
]

#code-listing(
  [A sku minted outside its commons],
  read("../snippets/chapter-02/minted/src/shop/orders.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.types.opaque_unsafe_outside] Error: `Sku.unsafe(...)` is only
available within the commons that defines the opaque type `Sku`
]

`Sku.unsafe` exists: it is the opaque type's unchecked constructor. But
only `shop.values` may call it. Everywhere else, the way in is `Sku.of`,
which checks the predicate and returns a `Result`: either a `Sku`, or the
reason the text isn't one. The cast that compiled anywhere in TypeScript
compiles in exactly one place in Bynk, and that place is named in the type's
declaration.

#lead-in[
Sometimes the owner knows more than the caller. The rest of
`shop.values` uses that:
]

#code-listing(
  [Constructors the commons can vouch for],
  source-lines("../snippets/chapter-02/shop/src/shop/values.bynk", 23, 39),
  lang: "bynk",
)

`skuFrom` takes a `Label`, a refined non-empty string, so by the time it
runs the predicate has already been checked. It can use `.unsafe` without
being unsafe, and return a `Sku` rather than a `Result`. That matters for
literals. When you write `skuFrom("widget")`, the compiler checks
`"widget"` against `Label` while it compiles, so a known-good literal needs
no runtime check and no error path.

#lead-in[
A known-bad one doesn't compile:
]

#code-listing(
  [An empty sku, refused while compiling],
  source-lines("../snippets/chapter-02/empty-sku/src/shop/orders.bynk", 6, 9),
  lang: "bynk",
)

#compiler-message[
[bynk.refine.literal_violates] Error: literal "" does not satisfy
`NonEmpty` required by type `Label`
]

Tests will use these constructors constantly, and so will chapter 4's
agents, which need an id to look up.

== Decoding JSON yourself <ix-guide-02-decoding-json-yourself>

A route parses its own body. Not every piece of JSON arrives through a
route, though: a queue message, a value read back from storage, or a field
inside a webhook that carries JSON as a string. For those,
`Json.decode[OrderLine](text)` does what the route did. It parses the text,
checks the shape and every refinement, and returns a `Result`: the
`OrderLine`, or a `JsonError` that says what was wrong.#footnote[
  The Bynk Book, “Decode untrusted JSON into a typed value”.
]

You will meet `Result` properly in the next chapter. For now, the important
part is that the decoder can't hand you an `OrderLine` with a zero quantity.
It can only hand you a valid one, or tell you why it couldn't.

== The first test <ix-guide-02-the-first-test>

#lead-in[
Tests live in `tests/`, beside `src/`. A `suite` names the unit it tests,
and each `case` states what should be true. Create
`tests/shop/orders.bynk`:
]

#code-listing(
  [The orders suite],
  read("../snippets/chapter-02/shop/tests/shop/orders.bynk"),
  lang: "bynk",
)

The first two cases test the boundary directly with `Json.decode`. The
third calls the route the way the Worker would: a test addresses an HTTP
route by its pattern, followed by its parameters, so
`api.PUT("/orders/:id", …)` runs the handler with that id and body.
`expect … is Ok(_)` asks whether a result has that shape.#footnote[
  You might expect to compare whole results, as in `expect r == Ok(v)`. At
  Bynk 0.330.4 that comparison is checked against the wrong type inside a
  test case (accuser/bynk#1979), so this book writes `is` throughout.
]

#lead-in[
Run the suite with `bynkc test .`:
]

#code-listing(
  [The first green run],
  read("../snippets/chapter-02/test-run.txt"),
  lang: "text",
)

`bynkc test` compiles the project and the tests to TypeScript, type-checks
them with `tsc`, and runs them with Node. There is no test runner to choose
and no mock of the Workers runtime to configure.

== What it costs <ix-guide-02-what-it-costs>

Every type you add is a boundary someone has to cross. Admitting a value
is cheap at the edge, where the route does it for you. It is less cheap in
the middle of the program, where a value you computed has to go through
`.of` and its `Result` before it becomes a `Quantity` again. Arithmetic is
the usual case: adding two quantities gives an `Int`, because the sum may
not be a valid quantity.

Opaque types cost more than refined ones. Code that needs the text of a
`Sku`, for a log line or a third-party API, has to ask the commons for it,
and the commons has to decide to offer it. That is the point, but you will
feel it. And an opaque type has no natural zero, which matters as soon as a
value has to live in storage: chapter 4 shows what that changes.

Two costs arrive later and are worth knowing about now. Changing the type of
a field in an event is a breaking change, even when the JSON looks the same,
because a subscriber may still hold an event written under the old rule
(chapter 15). And at 0.330.4 a `Map` can't yet be keyed by an opaque type
(accuser/bynk#1982), so chapter 5 keys its maps by text.

Finally, the predicates are your judgement, not the compiler's. Nothing
stops you writing `InRange(1, 1000)` when the warehouse's real limit is 50.
A type can only carry the rule you gave it.

== Where this leaves the order <ix-guide-02-where-this-leaves-the-order>

The shop can now refuse an order that isn't one, and an order that gets in
carries its rules with it. But the handler still answers only one way:
`Created`. Real orders fail for reasons that have nothing to do with their
shape. The stock runs out, the card is declined, or the id has been used.

`Sku.of` and `Json.decode` already return a `Result`. The next chapter
makes the route do the same, so that how an order can fail is part of its
type too.
