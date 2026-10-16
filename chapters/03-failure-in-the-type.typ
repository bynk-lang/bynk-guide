#import "../template.typ": code-listing, compiler-message, lead-in

#let source-lines(path, start, end) = {
  read(path).split("\n").slice(start, end).join("\n")
}

#let orders = "../snippets/chapter-03/shop/src/shop/orders.bynk"

= Failure in the type, and effects <failure-in-the-type>

By the end of chapter 2 the shop refused any order that wasn't one. A zero
quantity or an empty sku never reached the handler. But an order can be
perfectly well formed and still be one the shop won't take.

Here is the first such order. Three units at 2,500 cents is fine. A thousand
units at 20,000 cents comes to 20,000,000 cents, or 200,000.00, and the
shop won't take a charge over 100,000.00. Every field passed its check; the order as a whole does not.

This chapter adds that rule. It is the shop's first failure that isn't about
shape, so it is where you meet `Result`: how Bynk writes "this can fail" in a
type, so that whoever calls the function has to deal with it. And because the
handler now does something besides answer, logging the order it took, this
is also where you meet effects: what `Effect`, `<-` and `given` have meant
since chapter 1, and when you don't have to wait for one.

== The Worker you would write <ix-guide-03-the-worker-you-would-write>

#lead-in[
In TypeScript the rule is a function that throws, and the handler catches.
The log line goes to `ctx.waitUntil`, so the response doesn't wait for it:
]

#code-listing(
  [A rule that throws],
  read("../snippets/chapter-03/conventional.ts"),
  lang: "typescript",
)

This is how most Workers are written, and it works. Read `total`'s
signature, though: `(line: OrderLine) => number`. Nothing in it says the
function can fail, or how. You learn that from its body, or from a comment,
or when it throws in production. The handler knows to catch `OrderTooLarge`
because whoever wrote it read the body.

The `catch` is where it gets fragile. `e` is `unknown`, because anything can
be thrown, so the handler tests it with `instanceof` and rethrows everything
else. Suppose a second rule appears next month, with its own error class.
Every caller of `total` still compiles, and every one of them now turns the
new error into a `500`. The compiler had no way to tell them.

== Failure as a value <ix-guide-03-failure-as-a-value>

Bynk has no exceptions. A function that can fail says so in its return type,
and its failure is an ordinary value, returned like any other.

#lead-in[
Start with the reasons an order can be refused. In `orders.bynk`, after
`OrderLine`:
]

#code-listing(
  [Why an order is refused],
  source-lines(orders, 10, 16),
  lang: "bynk",
)

`OrderError` is a _sum type_: a value that is exactly one of its variants.
It has one variant so far, and later chapters add more (an order id used
twice, stock that has run out, a declined card). `TooLarge` carries a
payload, the `ValidationError` that says why the total isn't a valid price.
When no variant carries anything, a sum is written `enum { … }` instead;
chapter 5's `StockError` is the first. The `embeds` line comes up shortly.

#lead-in[
Now the rule itself:
]

#code-listing(
  [The rule, as a function that can fail],
  source-lines(orders, 17, 24),
  lang: "bynk",
)

The return type is the point. `Result[Cents, OrderError]` is either
`Ok(cents)` or `Err(error)`, and a caller can't get at the `Cents` without
deciding what to do about the error. The signature now says everything the
TypeScript one left out.

The body is chapter 2 paying off. `line.qty * line.cents` multiplies two
refined values, and the product is a plain `Int`, because nothing promises
that it is a valid price. `Cents.of` admits it again, checking it against
`InRange(1, 10000000)`, and returns its own `Result`: the `Cents`, or a
`ValidationError`.

== `?`, and what `embeds` is for <ix-guide-03-question-and-embeds>

`?` after an expression unwraps an `Ok` and carries on, or returns an `Err`
from the function there and then. In `total`, if `Cents.of` succeeds, `?`
hands back the `Cents` and `total` returns it in an `Ok`. If it fails, `total`
returns the error.#footnote[
  The Bynk Book, “Work with `Result` and optional values”, and on `embeds`,
  the error-embeddings section of the types reference.
]

There is a gap there. `Cents.of` fails with a `ValidationError`, but `total`
promises an `OrderError`. Something has to turn one into the other, and that
is what `embeds ValidationError as TooLarge` says: wherever `?` meets a
`ValidationError` in a function that returns `OrderError`, wrap it in
`TooLarge`.

#lead-in[
Leave the line out and the compiler stops you:
]

#code-listing(
  [`?` with nothing to convert the error],
  read("../snippets/chapter-03/no-embeds/src/shop/orders.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.types.question_error_mismatch] Error: the `?` operator propagates an
error of type `ValidationError`, but the enclosing function returns
`Result[_, OrderError]` (and no `embeds` clause converts it)
]

The error type is part of the contract, so it can't change silently on the
way out. Either the function's error type says how it absorbs the other one,
or the function handles the other one itself.

== Choosing the response <ix-guide-03-choosing-the-response>

#lead-in[
The handler calls `total` and decides what each outcome means over HTTP:
]

#code-listing(
  [Mapping the outcome to a status],
  source-lines(orders, 25, 41),
  lang: "bynk",
)

`match` takes a value apart by its variants, and it must have an arm for
every one: `Ok`, and `Err` with each kind of `OrderError`. Leave one out and
the program doesn't compile. Add a variant to `OrderError`, and every `match`
that names variants one by one stops compiling until it says what the new
one means. That is the thing the TypeScript `catch` couldn't do.

The mapping to a status is written out, on purpose. `embeds` converts one
error to another inside the program, but nothing converts an error to an HTTP
status for you: a `TooLarge` is a `422` because this handler says so.

#lead-in[
`?` itself has no place here. Try it, the way you might `await` and let a
rejection propagate:
]

#code-listing(
  [`?` in a handler],
  source-lines("../snippets/chapter-03/question-in-handler/src/shop/orders.bynk", 13, 22),
  lang: "bynk",
)

#compiler-message[
[bynk.types.question_outside_result] Error: the `?` operator can only be
used inside a function returning `Result`
]

A handler returns an `HttpResult`, not a `Result`, so there is no `Err` for
`?` to return. Something has to choose the status, and the handler is where
that happens.

== Effects, and when not to wait <ix-guide-03-effects>

The `Ok` arm does two things: it logs the order and answers `201`. Logging is
an _effect_. It does something outside the function, and that is why a
handler's return type has been `Effect[…]` since chapter 1. A handler can
also say which outside things it may touch, and this one says so with
`given Logger`. A function like `total` has neither: it is pure, so it can't
log, call a service or read the clock, and it is trivial to test.#footnote[
  Chapter 4 of “Architecture that compiles”, “Effects should name their
  requirements”, makes the case for naming them.
]

Calling an effect raises a question TypeScript leaves to `await`: does the
handler wait for it? Bynk makes you answer at the call, with one of three
spellings.

- `let x <- op(…)` calls `op`, waits, and binds the value it returns.
- `let _ <- op(…)` waits for an operation whose value you don't need.
- `~> op(…)` sends it and doesn't wait. The handler carries on, and the
  response can go out before the send has finished.

There is no fourth spelling. A value you don't wait for has nowhere to go,
so that combination doesn't exist.#footnote[
  The Bynk Book, “Synchronous and asynchronous sends”.
]

A log line is the clearest case for `~>`: nothing that follows depends on it,
and the customer shouldn't wait for it. On Workers, `~>` becomes the same
call you would have written by hand.

#lead-in[
From the compiled handler:
]

#code-listing(
  [What `~>` compiles to],
  read("../snippets/chapter-03/emitted/send.ts"),
  lang: "typescript",
)

`deps.__exec` is the request's execution context, passed through from
`fetch`, so the log runs to completion after the response has gone.

One warning, before it matters. The choice is about _waiting_, not about
whether a value comes back. A write to storage often returns nothing, an
`Effect[()]`, just like a log line, and it still has to be waited for, or a
read later in the same handler may not see it. Chapter 4 stores state for
the first time: there, a plain assignment isn't a call at all, and the one
storage operation that is, `update`, is waited for with `let _ <-`.

== From outside <ix-guide-03-from-outside>

#lead-in[
Run `bynk dev` and place two orders:
]

#code-listing(
  [Two orders, one too large],
  read("../snippets/chapter-03/responses.txt"),
  lang: "text",
)

`UnprocessableEntity("…")` answers `422` with the message as a JSON object,
in the same style as the `400`s from chapter 2. The `bynk dev` terminal shows
`order for 7500 cents` for the first order and nothing for the second.

== Testing a rule <ix-guide-03-testing-a-rule>

#lead-in[
A pure function is the easiest thing in the program to test. The suite
keeps chapter 2's decoding cases and adds two for `total`:
]

#code-listing(
  [The orders suite],
  source-lines("../snippets/chapter-03/shop/tests/shop/orders.bynk", 11, 24),
  lang: "bynk",
)

`is Err(TooLarge(_))` checks the variant as well as the failure, so a test
fails if the rule starts failing for a different reason.

#lead-in[
Run it:
]

#code-listing(
  [The suite, run],
  read("../snippets/chapter-03/test-run.txt"),
  lang: "text",
)

Chapter 2's test that called the route is gone, and not by choice. At
0.330.4 a test can't call a route whose handler uses `~>`: the test
harness doesn't supply the execution context, and the generated test fails
to compile (bynk-lang/bynk#1994). Until that is fixed, the route is covered
by the transcript above, which CI replays against `bynk dev`, and the rule by
the tests here.

== The whole change <ix-guide-03-the-whole-change>

#lead-in[
Here is everything this chapter did to `orders.bynk`:
]

#code-listing(
  [`orders.bynk`, chapter 2 to chapter 3],
  read("../snippets/chapter-03/orders.diff"),
  lang: "diff",
)

== What it costs <ix-guide-03-what-it-costs>

Every failure is now something a caller handles, visibly. That is the
purpose, and it is also more code than a `throw` that nobody catches. A
handler that calls three fallible functions has three outcomes to map, and
you will write those matches by hand.

One error type shared by several functions has a price of its own. When
`OrderError` grows in later chapters, a `match` on `total`'s result has to
account for every variant, including those `total` can never return. The
final shop handles that with a single `Err(_)` arm for `total`. A narrower
error type for each function avoids it, at the cost of more types and more
`embeds`.

`~>` gives up something too. If a sent operation fails, nothing in the
handler finds out. That is right for a log line, and wrong for anything the
next line depends on, which is why the choice is yours to make at every call.

And a bug is still a bug. A handler that faults (an index out of range, say)
is logged and answered with a `500`, as chapter 1 showed. `Result` is for the
failures you expect, and can name.

== Where this leaves the order <ix-guide-03-where-this-leaves-the-order>

The shop now refuses an order it can't charge for, and says why. It still
remembers nothing. Place order `o1` twice and you get two `201`s, because
nothing knows that `o1` exists. The next chapter gives each order a place to
live, and the first thing it does is refuse the second one.
