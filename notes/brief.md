# Editorial brief

## Working proposition

The online Bynk Book documents the language and *Architecture that compiles*
argues for its design. Neither teaches a reader to build with it. This book is
the middle: a guided path from knowing nothing about Bynk to being able to
design, test, deploy and change a multi-context service, by building one shop a
chapter at a time.

## Reader

An experienced TypeScript or Cloudflare developer. They have written a Worker,
know what a Durable Object and a Service Binding are for, and have used
`wrangler`. They need not have decided to adopt Bynk.

So the book does not explain the platform. Each chapter maps a Bynk construct
to the thing the reader would otherwise write by hand (a `fetch` handler, a
Durable Object class, middleware that checks a token, a vitest suite with
miniflare), and shows the emitted TypeScript only where it makes the point.

## Promise

By the end the reader has built, tested and deployed a four-context service,
knows what each Bynk construct buys over the hand-written version, and knows
where Bynk can't yet do what they would want.

## This book is

- a tutorial that builds one evolving system, `bynk-lang/shop`, one concept per
  chapter;
- written for readers who already know the platform;
- candid about the language's current limits, with the issue that tracks each;
- built so that every listing is compiled, formatted and type-checked in CI.

## This book is not

- the language reference (that stays in the online Bynk Book);
- the argument for Bynk's design (that is *Architecture that compiles*);
- a platform primer for Cloudflare Workers;
- a catalogue of features.

## Scope

Bynk 1.0 will promise stability for the Foundations layer: bounded contexts, the
service and agent split, actors, `Result`-returning handlers, the core storage
surface and cross-agent calls. Everything else (capabilities, events, sagas,
the query algebra, rich storage kinds, held connections) evolves additively
through 1.x.

So the book is **thorough on the Foundations layer** and **lighter on the
coordination layer**. Events get a chapter, and queues and cron share one.
WebSockets and `Oidc` actors are mentioned and pointed at the Book until there
is a reason to build one.

One deliberate exception: capabilities and adapters are 1.x, but they get a full
chapter. An adapter is the only place a Bynk program reaches npm, an outside
API or anything else Bynk doesn't do, and this reader will need that seam before
anything else in the coordination layer. Expect the canary to flag that chapter
more often than the Foundations chapters, and revise it rather than thin it.

## Keeping it true before 1.0

The language still changes. The defence is the one *Architecture that compiles*
uses:

- Every listing is a snippet project under `snippets/`, held by three gates
  (`bynkc check`, `bynkc fmt --check`, and a build with `tsc --strict`).
- The book pins one Bynk release (`0.330.4`) and prints it.
- The org canary re-runs the gates against every new release and opens a
  `canary` issue when a chapter stops being true. A deliberate revision, and a
  bump of the pin, then closes it.

## Teaching around the open bugs

The shop works around these upstream bugs. The book teaches the working form and
says why, rather than teaching what the compiler accepts but the runtime breaks:

- **Service coordinates, agent owns state** (accuser/bynk#1960). Cross-context
  calls are made from the service, not inside an agent handler. Present this as
  the pattern, with a note.
- **Events and deploy** (accuser/bynk#1961). The full shop can't deploy while an
  event crosses contexts, so deploy is taught on the two-context subset before
  events are added, and the events chapter says so.
- **Event fan-out in the `system` test tier** (accuser/bynk#1959). Events are
  tested end to end against `bynk dev`.
- **An adapter's binding is out of reach of `bynkc test`** (accuser/bynk#1975).
  The binding is tested with `node --test` against fake `Fetch` and `Secrets`.
- **The secrets manifest misses reads** (accuser/bynk#1976) in provider bodies
  and adapter bindings, so `bynk deploy` doesn't warn about an unset payment
  key. The deploy chapter says what to check by hand.
- **Test-only checker gaps.** `expect r == Ok(v)` is mistyped in a test case
  (accuser/bynk#1979), so tests use `expect r is Ok(v)`. A test calling a
  `by c: Caller` service needs `by Caller("…")` or `tsc` fails
  (accuser/bynk#1978).
- **Folding collected `MapEntry`s emits an unimported type**
  (accuser/bynk#1977). Entries are projected into a named record before
  `.collect()`, which is the idiom anyway.

## Working principles

1. Begin with what the reader would write by hand; introduce Bynk as the
   alternative.
2. One evolving system, not disconnected demos.
3. Show a compiler refusal where it teaches the language's rules.
4. Say what a construct costs, and where it doesn't yet work.
5. Leave exact syntax and exhaustive detail to the online Book, and link to it.
6. Compile-test, format-check and type-check every listing.
7. Use sentence case for book, part, chapter and section titles.
8. Address the reader as "you" and give build steps in the imperative ("Add a
   `Quantity` type"). Otherwise follow *Architecture that compiles*: a
   `#lead-in` before every listing, listings read from `snippets/`, compiler
   refusals quoted with `#compiler-message`, a paragraph on what the construct
   costs, a closing turn into the next chapter, and British spelling. Don't
   retell that book's arguments or reuse its examples; link to it.

## Working title

**Building with Bynk**: *A guide for TypeScript and Cloudflare developers.*
Both are provisional.
