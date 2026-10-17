#import "../template.typ": code-listing, compiler-message, lead-in

// Lines from..to of a snippet file, without the leading tabs they all
// share, so an excerpt from inside a handler isn't printed far to the right.
#let source-lines(path, from, to) = {
  let lines = read(path).split("\n").slice(from, to)
  let depth(l) = l.len() - l.trim("\t", at: start).len()
  let shared = calc.min(..lines.filter(l => l.trim() != "").map(depth))
  lines.map(l => if l.trim() == "" { l } else { l.slice(shared) }).join("\n")
}

#let payments = "../snippets/chapter-10/shop/src/shop/payments.bynk"
#let binding = "../snippets/chapter-10/shop/src/shop/gateway.binding.ts"

= The host boundary <the-host-boundary>

Sooner or later a Bynk program has to reach something Bynk didn't write: a
payment processor's API, an npm package, a service with its own idea of how
requests should look. And something will want to reach it: the processor,
calling back to say a payment was captured.

This chapter does both for the shop's payments. Outbound, the processor
becomes a real HTTP API, called from a few dozen lines of TypeScript that sit
behind a Bynk capability. Inbound, the processor's webhook is a route whose
caller is proved by a signature over the request body. Along the way the
payment gets a record of its own, an agent that moves through its states as
the notices arrive and remembers which notices it has already seen.

This is where a program leaves Bynk when Bynk can't do what it needs. The
point of the chapter is that it leaves through one named door.

== The webhook you would verify by hand <ix-guide-10-the-webhook-you-would-verify>

#lead-in[
The inbound half first. By hand, a Worker verifies a processor's signed
webhook with WebCrypto:
]

#code-listing(
  [Verifying a webhook, by hand],
  read("../snippets/chapter-10/conventional.ts"),
  lang: "typescript",
)

Every line here matters. The body has to be read raw, exactly once, before
anything parses it, because the signature is over those bytes. The timestamp
has to be checked, or a captured request can be replayed forever. And the
comparison has to take the same time however many characters match, or the
time it takes tells an attacker how close their guess was. None of this is
hard to write, and all of it is easy to get subtly wrong, once per webhook.

== An adapter <ix-guide-10-an-adapter>

Now the outbound half. The processor's API needs an HTTP client, written in
TypeScript, because that is where HTTP clients and npm live. Bynk lets that
TypeScript in through exactly one kind of declaration: an _adapter_.

#lead-in[
The shop's is `src/shop/gateway.bynk`:
]

#code-listing(
  [The gateway adapter],
  read("../snippets/chapter-10/shop/src/shop/gateway.bynk"),
  lang: "bynk",
)

An adapter is a contract with its implementation somewhere else. It declares a
capability, `Gateway`, and the types its operations use, and exports both so
contexts can consume them. Its provider is _external_: `provides Gateway =
HttpGateway given Fetch, Secrets` has no body, because the body is the
TypeScript class named by `binding "./gateway.binding.ts"`. The adapter says
what that class must implement and what it is given; it doesn't run
anything itself.#footnote[
  The Bynk Book, “Wrap a library as an adapter”, and the adapters reference.
]

#lead-in[
That is all an adapter can hold. Try putting a service in one:
]

#code-listing(
  [A service in an adapter],
  source-lines("../snippets/chapter-10/adapter-service/src/shop/gateway.bynk", 33, 37),
  lang: "bynk",
)

#compiler-message[
[bynk.adapter.disallowed_item] Error: an `adapter` may not declare a `service`
— adapters contain only capabilities, boundary types, external providers,
and helpers
]

An adapter isn't a context. It has no Worker, no state and no routes. It is
the seam, and nothing else, which makes it the one place to look when you
want to know where a program touches code the compiler can't check.

== The binding <ix-guide-10-the-binding>

#lead-in[
The binding implements `Gateway` in TypeScript:
]

#code-listing(
  [`gateway.binding.ts`, the class],
  source-lines(binding, 21, 68),
  lang: "typescript",
)

`HttpGateway implements Gateway`, the interface the compiler generated from
the adapter, and `tsc --strict` holds the class to it: a missing operation or
a wrong return type is a build error. Its constructor receives `deps`, an
object of the capabilities the adapter's provider was given, by name. So the
binding doesn't call the global `fetch` or read `env`. It calls
`deps.Fetch.send` and `deps.Secrets.get`, which is what makes it testable
with fakes, as the end of the chapter shows.

The rest is a careful HTTP client. No API key means `Unavailable` and nothing
sent. The order id is the `Idempotency-Key`, so a retried request can't
authorise twice. A `402` is a declined card. Anything else that isn't a
success, including a body the binding can't read, is `Unavailable`. The
binding returns a Bynk `Result`, built with the runtime's `Ok` and `Err`, so
its expected failures arrive as values the caller has to handle. (A binding
that throws anyway faults the handler, as any bug does.)

`Fetch` sends over the public internet. Every Worker Bynk generates sets
Cloudflare's `global_fetch_strictly_public` flag, so a `Fetch` never takes a
shortcut to another Worker on the same account.

== Choosing the processor <ix-guide-10-choosing-the-processor>

#lead-in[
The payments context consumes the adapter's capability, and chapter 9's
provider gains a real branch:
]

#code-listing(
  [`CardProcessor`, now with a gateway],
  source-lines(payments, 26, 54),
  lang: "bynk",
)

`consumes shop.gateway { Gateway }`, at the top of the file, brings
`Gateway` into the context the way `consumes bynk { Secrets }` brings in
`Secrets`. `CardProcessor` is now given both. With the fake setting it still
uses `fakeCharge`; with anything else it asks the gateway, and maps the
gateway's two errors to the shop's own. Because the gateway and the shop both
have a `Declined`, the names are qualified: `GatewayError.Declined`,
`PayError.Declined`.

#lead-in[
It would be tidier to provide a fake `Gateway` in the payments context and
skip the setting. That is refused:
]

#code-listing(
  [Providing the adapter's capability in a context],
  source-lines("../snippets/chapter-10/context-provider/src/shop/payments.bynk", 228, 238),
  lang: "bynk",
)

#compiler-message[
[bynk.provider.unknown_capability] Error: provider targets unknown capability
`Gateway` — declare the capability in the same context
]

A capability is provided where it is declared. `Gateway` belongs to the
adapter, and its one provider is the binding. A context that wants a choice
makes it in a capability of its own, as `CardProcessor` does for `Processor`.

== A record of the payment <ix-guide-10-a-record-of-the-payment>

Once the processor has authorised a charge, it owns what happens next: it
captures the money, or the charge fails, or it is refunded later. The shop
learns about each from a webhook, and needs somewhere to record it.

#lead-in[
First, what a payment can be, and what a notice is:
]

#code-listing(
  [A payment's states, and a notice],
  source-lines(payments, 68, 91),
  lang: "bynk",
)

#lead-in[
Then a `Payment` agent, keyed by the processor's authorisation id:
]

#code-listing(
  [The payment],
  source-lines(payments, 92, 137),
  lang: "bynk",
  breakable: true,
)

This is chapter 6's state machine again, with chapter 5's `Log` put to use.
`notices` keeps every notice the payment has applied, for ninety days, and it
is also the replay guard. The processor retries a webhook until it gets a
`2xx`, so the same notice can arrive twice; `notify` looks for its id in the
log first, and answers with the current status if it is there.

#lead-in[
Which notices may move which status is a pure function:
]

#code-listing(
  [The processor's events, and where they lead],
  source-lines(payments, 140, 157),
  lang: "bynk",
)

#lead-in[
And `authorise` now records each payment it takes:
]

#code-listing(
  [Recording an authorisation],
  source-lines(payments, 168, 188),
  lang: "bynk",
)

== The webhook <ix-guide-10-the-webhook>

#lead-in[
The processor calls back to a route in the payments context, as a caller of
a new kind:
]

#code-listing(
  [A signed webhook],
  source-lines(payments, 189, 228),
  lang: "bynk",
  breakable: true,
)

`ProcessorHook` is a `Signature` actor. Before the body is parsed, the boundary
reads the raw body once, reads the timestamp header, recomputes the
HMAC-SHA256 of `<timestamp>.<body>` with the secret in
`PAYMENTS_WEBHOOK_SECRET`, and compares it in constant time with the
`sha256=…` in the signature header. A timestamp more than 300 seconds from
now is refused too. Any failure is a `401`, and the handler never runs. It is
the hand-written verifier from the start of the chapter, as four lines of
declaration.#footnote[
  The Bynk Book, “Verify an inbound webhook”.
]

A notice that doesn't follow from the payment's status, such as a refund of a
payment that was never captured, or any notice for a payment the shop never
took, is a `409`. That tells the processor to try again later, which is right
if the notices simply arrived out of order.

#lead-in[
From outside, with `PAYMENTS_WEBHOOK_SECRET` set to `not-a-webhook-secret`.
The payments Worker is the third context, on 8789:
]

#code-listing(
  [Three webhooks the shop refuses],
  read("../snippets/chapter-10/responses.txt"),
  lang: "text",
)

No signature; a forged one; and a correctly signed notice from 2023, outside
the five-minute window. All three are `401`. A correctly signed, current
notice needs a signature made at the moment it is sent, so it can't be
printed here. The shop's `e2e/scenarios.sh` signs real ones, and the tests
below exercise the handler.

== Testing both halves <ix-guide-10-testing-both-halves>

#lead-in[
The Bynk half is tested in Bynk. The gateway is a capability, so a test stubs
it at its seam:
]

#code-listing(
  [Stubbing the gateway],
  source-lines("../snippets/chapter-10/shop/tests/shop/payments.bynk", 35, 64),
  lang: "bynk",
)

#lead-in[
And the webhook's replay guard, through the agent:
]

#code-listing(
  [A notice delivered twice],
  source-lines("../snippets/chapter-10/shop/tests/shop/payments.bynk", 100, 116),
  lang: "bynk",
)

At the unit tier a `Signature` actor's signature is taken as given, so these
tests are about what the shop does with a notice, not whether the notice is
genuine. The transcript above, replayed against `bynk dev` in CI, covers the
refusals.

The TypeScript half is tested in TypeScript. At 0.330.4 a Bynk test can't
reach an adapter's binding: an `as integration` case doesn't build the
binding, and a suite aimed at the adapter doesn't compile
(bynk-lang/bynk#1975). So the binding has tests of its own, run with Node
against the JavaScript that `bynkc test` leaves in `out-js/`.

#lead-in[
They build the class with fake `Fetch` and `Secrets`, which the binding's
by-name `deps` makes easy:
]

#code-listing(
  [Testing the binding with Node],
  source-lines("../snippets/chapter-10/shop/tests/bindings/gateway.test.cjs", 23, 53),
  lang: "javascript",
  breakable: true,
)

This book's CI runs both, `bynkc test .` and then `node --test
tests/bindings/*.test.cjs`, and fails if either does.

#code-listing(
  [The Bynk suites, run],
  read("../snippets/chapter-10/test-run.txt"),
  lang: "text",
)

== What it costs <ix-guide-10-what-it-costs>

The binding is TypeScript, and the compiler's guarantees stop at its
signature. `tsc` checks that `HttpGateway` implements `Gateway`; it can't check
that a `402` means a declined card. That is what the binding's own tests are
for, and they are yours to write.

The configuration a binding reads is invisible to the build. At 0.330.4 the
`bynk-secrets.json` manifest that `bynk deploy` checks doesn't see the
`Secrets.get` calls inside a provider or a binding, so it won't warn that
`PAYMENTS_API_KEY` is unset (bynk-lang/bynk#1976). Chapter 12 says what to
check by hand.

The replay guard remembers ninety days. A notice replayed after that would be
applied again, unless the state machine refuses it, as it does here: a
payment that is already refunded can't be refunded twice.

And there is still one provider per capability, so the choice between the
fake and the gateway is a branch on a setting that only one environment
takes. The fake branch is tested by the suite; the gateway branch by the
binding's tests and the gateway stubs; and the two together only by deploying.

== Where this leaves the shop <ix-guide-10-where-this-leaves-the-shop>

The shop can take an order end to end: check it, open it, hold its stock,
charge a card through a real processor, and hear back about the money. It
has tests in four places now: unit suites per context, the binding's Node
tests, the replayed transcripts, and the shop's end-to-end script. Part IV
starts by putting those into one picture: what each tier of test is for, and
which one a given question belongs to.
