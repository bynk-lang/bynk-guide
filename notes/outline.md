# Working outline

Provisional. Each chapter names the Bynk construct, the hand-written thing it
replaces, the snippet project that carries it, and the step of the shop it adds.
Chapters 1 to 12 deploy; 13 adds events after deploy (see `brief.md`).

Tests are not saved for chapter 11. From chapter 2 on, each chapter ends with a
unit test of what it built; chapter 11 adds the tiers above that.

The shop (bynk-lang/shop#2) now has the code for chapters 5, 10 and 14. Where
the shop works around a bug, the chapter teaches the working form and footnotes
the issue, as `brief.md` asks.

## Part I: From a Worker to a service

1. **A Worker in Bynk**
   Installing Bynk, `bynk.toml` and the project layout. A context and an HTTP
   service. `bynkc check`, `bynk dev`. What it emits. The two targets: `bundle`,
   the compiler's default, makes one TypeScript tree with in-process calls and
   no Durable Objects; `workers` makes one Worker per context, which is what
   this book builds and deploys. Say how to choose it, and what `bundle` is for.
   Two TypeScript habits that bite: interpolation is `\(expr)`, and `"${x}"`
   compiles silently as a literal; a one-armed `if` statement is `do if`.
   *Replaces:* a `fetch` handler and a `wrangler.toml`.
2. **Types you can trust**
   A `commons` (`shop.values`), records, `opaque` and refined types,
   admission at the boundary, who may mint an opaque value (`.unsafe` only in
   its commons; total constructors over a refined `Label`), `Json.decode`. A
   first unit test.
   *Replaces:* branded types, and hand-rolled validation or a schema library.
   *Shop:* `shop.values` and `OrderLine` (bynk-lang/shop#5).
3. **Failure in the type, and effects**
   Sum types (`OrderError`, with a payload; `enum` named as the payloadless
   spelling), `Result`, exhaustive `match`, `?` and `embeds`, mapping to HTTP
   status explicitly. *Shop:* `total` re-admits `qty * cents` as `Cents`, so an
   order over 100,000.00 is a `422` (bynk-lang/shop#6). Then
   `Effect`, `<-` and `given`, and the send grid: `let _ <-` waits, `~>` does
   not, and `Effect[()]` is not `void` (a durable write must be awaited).
   *Replaces:* `throw` and `try`/`catch`, and `async`/`await` by habit.

## Part II: State

4. **An agent is a Durable Object**
   Keyed agents, `Cell`, `:=` and the commit at the handler's end, zeroable
   state, one owner. An opaque value has no zero, so `Order` keeps its line as
   `Option[OrderLine]`: `Option` is taught here. Refusals: an agent call never
   awaited (`bynk.effect.unbound_effect`), and chapter 3's `match` once
   `OrderError` gains `AlreadyDecided`.
   *Replaces:* a Durable Object class and its storage calls.
   *Shop:* `Order` (open once, view) and `GET /orders/:id`.
5. **Other kinds of storage**
   `Inventory` arrives as a second agent: `available: Cell[Int]` changed with
   `update` (an effect, awaited with `let _ <-`), `holds: Map[String, Hold]`
   keyed by order id as text (`orderRef`, until bynk-lang/bynk#1982), so
   reserving twice holds once, and `held` totals the holds with a `Query`.
   `StockError` is the shop's first `enum`. Then a standalone context for
   `Log` with `@retain`, `Cache` with `@ttl`, and `Kv`. Refusals: a `Query`
   returned from a handler (`bynk.types.query_at_boundary`), and a `Cache`
   without `@ttl` (`bynk.store.cache_ttl_required`). Light: these are 1.x
   surface, not Foundations.
   *Replaces:* storage key prefixes, transactions by hand, and KV.
   *Shop:* `Inventory`, `PUT`/`GET /stock/:sku`, and reserving on placement.
   The order is opened before stock is reserved, so a refusal for stock leaves
   it behind; the transcript shows it, and chapter 6 fixes it with a status.
   The timestamp on a hold waits for chapter 14, which needs `Clock`.
6. **State with a lifecycle**
   `Status` with an initial variant, a guarded `match` per handler, and two
   `transition`s that make rejected and cancelled final. `Inventory` gains
   `invariant available_non_negative` and `release`. A history property
   (`for all run: History[Order]`) checks that only a placed order is
   cancelled, with an illustrative failing run (a shrunk counterexample).
   Refusals: `:=` reading its own cell (`bynk.cell.self_reference`), and a
   history property that restates an invariant
   (`bynk.history.restates_invariant`; a restated transition isn't caught yet,
   bynk-lang/bynk#2018).
   *Replaces:* status strings and defensive checks. *Shop:* `Order`'s
   lifecycle, rejecting on insufficient stock, `POST /orders/:id/cancel`, and
   the stock invariant (bynk-lang/shop#7 adds the transitions to the shop).

## Part III: Who is calling, and who is it for

7. **Actors**
   `Customer` (`Bearer`, identity `CustomerId`) and `Admin = Customer where
   hasClaim("admin")`; `401` vs `403`; the order records its owner and
   `shown` hides others' orders as `404`. `GET /stock/:sku` is
   `by who: Customer | Visitor`, answering an `Availability` sum. Refusals:
   a refinement in a sum (`bynk.actor.refinement_in_sum`), and `Visitor`
   first (`bynk.actor.unreachable_sum_arm`). The transcript uses real tokens
   (`responses.env`) and `--var AUTH_JWT_SECRET`. A test can't call an
   `Admin` route (bynk-lang/bynk#2019) or a sum route (bynk-lang/bynk#2020).
   *Replaces:* auth middleware. *Shop:* `Customer` and `Admin`, owners, and
   the public stock lookup (bynk-lang/shop#8).
8. **Contexts and Service Bindings**
   The shop splits into `shop.orders`, `shop.inventory` and `shop.payments`,
   all `uses shop.values`. `exports transparent`, `on call` services with
   `by c: Caller`, `consumes … as`; a service coordinates, an agent owns
   state (bynk-lang/bynk#1960). Payments is `fakeCharge`, a pure function,
   until chapter 9. Compensation by hand (release and reject on a declined
   payment) and why it isn't crash-safe; sagas are planned; chapter 14's
   sweeper. Refusals: another context's agent called directly
   (`bynk.consumes.unknown_service`), and a `consumes` cycle
   (`bynk.context.consumes_cycle`). Running several contexts needs `--inspect`
   (bynk-lang/bynk#1954). Beside an existing Worker (bynk-lang/bynk#1973). A
   warning: at 0.330.4 a deployed context answers its `on call` services on
   its `workers.dev` address with any claimed caller; fixed upstream, not yet
   released (bynk-lang/bynk#2004, #2012). Chapter 12 must turn off
   `workers.dev` for internal contexts, or the pin must move past the fix.
   *Replaces:* Service Binding glue and hand-typed RPC. *Shop:* orders,
   inventory, payments.
9. **Capabilities and providers**
   `given`, first-party capabilities (`Logger`, `Secrets`, `Fetch`, `Clock`),
   a provider you can swap, `stub` and observation in a unit test, and a
   platform context that exports a capability.
   *Replaces:* reading `env` directly, and mocks. *Shop:* `Processor` with the
   fake rule, and `authorise` taking the order id so a retry is recognisable.
10. **The host boundary**
    An `adapter` and its TypeScript binding, with `Fetch` and `Secrets` as
    by-name deps: the binding maps a real-shaped processor API's responses to
    `Approved`, `Declined` and `Unavailable` (503, failing closed when the key is
    missing). A capability declared in an adapter can't be provided by a
    context, and a capability has one provider, so `CardProcessor` chooses the
    fake or the gateway at run time from `PAYMENTS_PROCESSOR`. Then the webhook:
    a `Signature` actor with a timestamp and a replay window, a `Payment` agent
    whose state machine moves on each notice (chapter 6 again), and a `Log` of
    notices that is also the replay guard. The binding is tested with
    `node --test`, because `bynkc test` can't reach it yet (bynk-lang/bynk#1975).
    This is where a reader leaves Bynk when it can't do what they want.
    *Replaces:* a hand-written API client, and HMAC checks. *Shop:*
    `shop.gateway`, the real processor, and `POST /webhooks/processor`.

## Part IV: Confidence and delivery

11. **Testing at three tiers**
    Unit, integration and system tiers; `stub`; observation
    (`expect Cap.op called …`); end-to-end against `bynk dev`, including signed
    and forged webhooks. Teach the working forms: `expect r is Ok(v)`
    (bynk-lang/bynk#1979), and `by Caller("…")` when a test calls a `by c: Caller`
    service (bynk-lang/bynk#1978).
    *Replaces:* vitest with miniflare, spies, and hand-wired integration tests.
12. **Run it, ship it, debug it**
    `bynk dev`, `bynk deploy`, lock files, secrets, environments, the CI
    actions. `bynk-secrets.json` can miss reads made in provider bodies and
    adapter bindings, so `bynk deploy` won't warn that `PAYMENTS_API_KEY` is
    unset (bynk-lang/bynk#1976); say what to check by hand. Then a deployed Worker
    that misbehaves: `Logger`, source maps back
    to `.bynk`, reading the emitted TypeScript, and what a `Result` error looks
    like in the Workers dashboard.
    *Replaces:* a deploy script, and `console.log` debugging.
    *Deploys:* the shop without events.

## Part V: Beyond a request

13. **Events**
    Emit and subscribe, at-least-once delivery, `Idempotency`.
    *Replaces:* hand-rolled queues and fan-out. *Shop:* the ledger. Says why the
    full shop can't deploy yet (bynk-lang/bynk#1961).
14. **Time and queues**
    Cron, and queue consumers. *Shop:* each hold gains `at: Instant` from
    `Clock`, and `service sweeper from cron` releases holds older than 15
    minutes, measured from the scheduled time. Durable Objects can't be listed,
    so a `Catalogue` agent records each stocked sku. Orders now commit a hold
    after payment, and a hold the sweeper already released is a
    `409 reservation expired` rather than an oversell. The gateway can't void
    the authorisation yet; say so. Testing with `--test-scheduled` and
    `/__scheduled`. This closes the gap chapter 8 left open.
15. **Changing a deployed system**
    The schema lock, migrations of agent state, contract skew. Not light: this
    reader has migrated Durable Object storage by hand. Honest about what 1.0 is
    still to settle.

## Epilogue: Where to go next

The Book, *Architecture that compiles*, the examples index, the canary.

## Not covered

WebSockets and `Oidc` actors (pointers to the Book), localisation, static
assets, sagas (pointer to the planned-features appendix), and the language
server and editor tooling. The `bundle` target is introduced in chapter 1 and
then set aside.

Chapter 8 gives one paragraph to the reader who adopts Bynk piecemeal, beside
an existing TypeScript Worker. Checked against the emitted Workers at the
pin, 0.330.4: a Bynk `on call` service is a plain
`POST /_bynk/call/<service>` with a JSON body over a Service Binding, so a
hand-written Worker can call it, but it must send the `X-Bynk-Contract` hash
from `bynk-contracts.json` and an `X-Bynk-Caller` identity, and the hash
changes whenever the signature does. That is an internal protocol, not an API.
The supported seams are the other way round: put the Bynk Worker in front, or
call its `from http` routes. Say that, don't teach the wire format, and
footnote the interop track (bynk-lang/bynk#1973).
