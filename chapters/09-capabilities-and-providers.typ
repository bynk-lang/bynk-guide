#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let payments = "../snippets/chapter-09/shop/src/shop/payments.bynk"

= Capabilities and providers <capabilities-and-providers>

The shop takes payments with a function that approves anything under a
thousand. That was enough to give chapter 8 a failure to handle. It is not a
payment processor, and the next step is to put one behind it.

Before the real processor arrives in chapter 10, this chapter changes what
`authorise` depends on. Instead of calling a function, it is _given_ a
processor: an interface whose implementation is chosen somewhere else. That
is a _capability_. You have used two already, `Logger` from chapter 1 and
`Clock` from chapter 5. Now the shop declares one of its own, provides it, and
swaps it out in a test without touching the code that uses it.

The provider also needs configuration: which processor to use. That is the
other thing this chapter replaces, reading `env` wherever a value is needed.

== The code you would write <ix-guide-09-the-code-you-would-write>

#lead-in[
By hand, the charge reads its setting from `env` and decides:
]

#code-listing(
  [A charge that reads `env`, by hand],
  read("../snippets/chapter-09/conventional.ts"),
  lang: "typescript",
)

#lead-in[
And testing the code that calls it means mocking the module:
]

#code-listing(
  [Mocking it, by hand],
  read("../snippets/chapter-09/conventional.test.ts"),
  lang: "typescript",
)

Both work. Both are also invisible from the outside. Nothing in `charge`'s
signature says it reads `PAYMENTS_PROCESSOR`; you find out by reading it, or
when it isn't set. And `vi.mock` replaces a module by its file path, before
anything imports it, which works until someone moves the file or calls
`charge` through a different import. The test's seam is wherever the mock
happens to land.

== A capability <ix-guide-09-a-capability>

#lead-in[
The payments context begins by asking for `Secrets`, and gains a second way
for a charge to fail:
]

#code-listing(
  [What payments needs],
  source-lines(payments, 0, 11),
  lang: "bynk",
)

`consumes bynk { Secrets }` brings in the first-party `Secrets` capability, as
`consumes bynk { Logger }` did in chapter 1. `Unavailable` is for when no
processor could be asked, which a customer can retry, unlike `Declined`.

#lead-in[
Then the shop's own capability:
]

#code-listing(
  [The card processor, as an interface],
  source-lines(payments, 12, 24),
  lang: "bynk",
)

A `capability` is a named set of operations with signatures and no bodies.
Each returns an `Effect`, because calling it reaches outside the program.
`Processor` says what a card processor can do for the shop, and nothing
about how.#footnote[
  The Bynk Book, “Understand the capability model”.
]

== A provider <ix-guide-09-a-provider>

#lead-in[
`provides` says how:
]

#code-listing(
  [The one provider],
  source-lines(payments, 25, 43),
  lang: "bynk",
)

`CardProcessor` implements every operation of `Processor`, and declares what it
needs in turn: `given Secrets`. It reads `PAYMENTS_PROCESSOR`, and charges with
the fake only if the setting says `fake`. Anything else, including no setting
at all, is `Unavailable`. That is deliberate. A deployment that forgets the
setting should fail closed, refusing every charge, rather than approve them
all.

`Secrets.get` reads a value by name from the Worker's environment, and returns
an `Option`, so a missing value is something the provider has to handle, not
an `undefined` that turns up later. It is the same environment a `Bearer`
actor's `secret = "…"` reads, through one door.

#lead-in[
Leave out an operation and the provider doesn't compile, as a TypeScript class
that `implements` an interface wouldn't. Add a `refund` to the capability, and
`CardProcessor` is short of one:
]

#code-listing(
  [A capability with a second operation],
  source-lines("../snippets/chapter-09/missing-operation/src/shop/payments.bynk", 18, 25),
  lang: "bynk",
)

#compiler-message[
[bynk.provider.missing_operation] Error: provider `CardProcessor` for
capability `Processor` is missing operation `refund`
]

== Given, not imported <ix-guide-09-given-not-imported>

#lead-in[
The `authorise` service is now given a `Processor`, and calls it:
]

#code-listing(
  [The fake, and the service that uses a processor],
  source-lines(payments, 44, 63),
  lang: "bynk",
)

`given Processor` is the service's whole account of what it touches. It can't
read a secret, because it isn't given `Secrets`; only the provider is. And it
doesn't know `CardProcessor` exists. The compiler wires the one to the other in
the context's composition root, the `compose.ts` chapter 1 showed: the
provider is built once per request with the capabilities it was given, and
handed to every handler that asks for `Processor`.

A context has exactly one provider per capability.

#lead-in[
So the obvious way to keep a fake beside a real processor is refused:
]

#code-listing(
  [A second provider],
  source-lines("../snippets/chapter-09/two-providers/src/shop/payments.bynk", 44, 53),
  lang: "bynk",
)

#compiler-message[
[bynk.resolve.duplicate_provider] Error: capability `Processor` already has a
provider in this context
]

One provider means the question "what will `Processor.charge` actually do?"
has one answer, in one place. Choosing between implementations happens inside
that provider, from configuration, as `CardProcessor` does. In a test the
choice is the test's to make, which is the next section.

`fakeCharge` is now a plain function the provider calls. A fake doesn't need
to be a provider of its own; it needs to be something the real provider can
fall back to, and something a test can rely on.

#lead-in[
In orders, the new failure needs a status of its own:
]

#code-listing(
  [`orders.bynk`, chapter 8 to chapter 9],
  read("../snippets/chapter-09/orders.diff"),
  lang: "diff",
  breakable: true,
)

A declined card is still `422`. A processor that couldn't be asked is `503`,
the status that tells a client to try again. Both release the stock and
reject the order first.

== Swapping a provider in a test <ix-guide-09-swapping-a-provider>

#lead-in[
A test can replace any capability operation the code under test is given, and
see every call made to one:
]

#code-listing(
  [The payments suite],
  read("../snippets/chapter-09/shop/tests/shop/payments.bynk"),
  lang: "bynk",
)

The first two cases `stub` `Secrets.get`, so the provider sees `"fake"` without
any environment at all. The third stubs nothing: in a test a secret that
isn't stubbed isn't there, so the provider fails closed, and `expect
Secrets.get called once with name == "PAYMENTS_PROCESSOR"` checks which
setting it looked for.

The last case replaces the processor itself. `stub Processor.charge(_, _)`
stands in for `CardProcessor` entirely, and the two `expect … called` lines
check that `authorise` passed the order id as the reference. This is the seam
`vi.mock` was guessing at: not a file path but the capability the code was
given, named in its signature.#footnote[
  The Bynk Book's testing reference, “Observation”, lists every form of
  `expect … called`.
]

Calls are recorded only in the test build. A deployed Worker calls the
provider directly.

#code-listing(
  [The suites, run],
  read("../snippets/chapter-09/test-run.txt"),
  lang: "text",
)

== From outside <ix-guide-09-from-outside>

#lead-in[
Run `bynk dev` with the processor set to the fake, and an order goes through:
]

#code-listing(
  [Running with the fake processor],
  "bynk dev -- --var AUTH_JWT_SECRET:not-a-secret \\\n  --var PAYMENTS_PROCESSOR:fake",
  lang: "sh",
)

#code-listing(
  [With the fake processor],
  read("../snippets/chapter-09/responses.txt"),
  lang: "text",
)

#lead-in[
Leave `PAYMENTS_PROCESSOR` out and the same order fails closed:
]

#code-listing(
  [With no processor configured],
  read("../snippets/chapter-09/unconfigured.txt"),
  lang: "text",
)

The order gets a `503`, the stock it reserved is released, and the level is
back to ten.

== Capabilities you didn't write <ix-guide-09-capabilities-you-didnt-write>

`Secrets`, `Logger` and `Clock` come from the `bynk` surface, the first-party
capabilities every Bynk program can consume: `Fetch` for outbound HTTP,
`Random`, `Idempotency` for events (chapter 13), and a few more. Consuming
only `bynk` keeps a context portable across targets. The `bynk.cloudflare`
surface, where chapter 5's `Kv` lives, is Cloudflare's own, and ties a context
to it.

A capability your own code declares can be shared, too. A context can provide
one and list it in `exports capability { … }`, and other contexts consume it
like `bynk`'s. A shop with several contexts that all need the same rate table
or the same feature flags would put that in one small platform context. This
shop doesn't need one.#footnote[
  The Bynk Book, “Share a capability across contexts”.
]

== What it costs <ix-guide-09-what-it-costs>

A capability is an interface, a provider and a `given` clause, where a
function call used to do. For something with one implementation and no
outside world, that is ceremony: keep it a function. Reach for a capability
when the implementation reaches outside, or when a test needs to replace it.

One provider per capability means that choosing an implementation is a
decision the provider makes at run time, from configuration, and every
provider that chooses has a branch that only runs in one environment. The
fake here is a function for that reason: the branch that uses it is tested
whenever the suite stubs the setting.

And `Secrets` is an environment variable by another name. It is typed, and a
missing one is an `Option` rather than `undefined`, but it is still read at
run time, and a typo in its name is found when the value turns out to be
`None`.

== Where this leaves payments <ix-guide-09-where-this-leaves-payments>

`authorise` is given a processor, and the processor is chosen in one place.
The only real choice so far is the fake or nothing. The next chapter writes
the real one: a provider in TypeScript, against a processor's HTTP API, behind
the same `Processor` interface, and a webhook for the processor to call back.
