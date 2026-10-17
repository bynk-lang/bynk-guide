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
   released (bynk-lang/bynk#2004, #2012). Turning `workers.dev` off doesn't
   last (each deploy re-enables it), so chapter 12 says to try the shop, not
   run it for real, until the pin moves past the fix.
   *Replaces:* Service Binding glue and hand-typed RPC. *Shop:* orders,
   inventory, payments.
9. **Capabilities and providers**
   `capability Processor`, one provider `CardProcessor given Secrets` that
   uses `fakeCharge` when `PAYMENTS_PROCESSOR=fake` and fails closed
   (`Unavailable`, a `503`) otherwise; `authorise` is `given Processor`.
   `Secrets` returns an `Option`. Tests `stub` `Secrets.get` and
   `Processor.charge` and observe with `expect … called`. The `bynk` and
   `bynk.cloudflare` surfaces, and `exports capability` (prose only).
   Refusals: a second provider (`bynk.resolve.duplicate_provider`), and a
   provider missing an operation (`bynk.provider.missing_operation`). Two
   transcripts of one project, with and without the setting.
   *Replaces:* reading `env` directly, and `vi.mock`. *Shop:* `Processor`,
   `CardProcessor`, `PayError.Unavailable` and the `503`.
10. **The host boundary**
    The `shop.gateway` adapter (`Gateway`, `GatewayError`, an external provider
    `HttpGateway given Fetch, Secrets`) and its TypeScript binding;
    `CardProcessor given Gateway, Secrets` chooses the fake or the gateway;
    a `Payment` agent with a `Log` of notices as the replay guard; and the
    `ProcessorHook` `Signature` webhook. Refusals: a service in an adapter
    (`bynk.adapter.disallowed_item`), and a context providing the adapter's
    capability (`bynk.provider.unknown_capability`). The transcript shows
    three refused webhooks (unsigned, forged, stale; the stale one's
    signature is in `responses.env`). The binding is tested with
    `node --test` (bynk-lang/bynk#1975), and the test gate now runs those.
    *Replaces:* a hand-written webhook verifier. *Shop:* already has it all;
    the chapter's copy is rewrapped to fit the page.

## Part IV: Confidence and delivery

11. **Testing at three tiers**
    `unit` (stubs, observation, properties, platform doubles), `integration`
    (one word, same body), and `system` (a suite of its own, context-path
    calls, participants from `consumes`, real JSON wire in Node). The `system`
    example is payments: fail-closed over the wire, and an unsigned notice
    refused at the boundary. Refusals: a unit case that crosses contexts
    (`bynk.tier.cross_context_needs_system`), and a mixed suite
    (`bynk.tier.mixed_system_suite`). Where `system` stops at 0.330.4: no
    Worker with `~>` routes (fixed by bynk-lang/bynk#2005, unreleased),
    stubs ignored (bynk-lang/bynk#2026), literal arguments not admitted
    (bynk-lang/bynk#2025). Beyond `bynkc test`: binding tests and e2e against
    `bynk dev`. Habits: `is` (#1979), `by Caller` (#1978), local names (#2024).
    *Replaces:* vitest with Miniflare, spies, and hand-wired integration tests.
12. **Run it, ship it, debug it**
    `bynk deploy` and its dry-run plan (gated by `check-book-plans.sh`):
    order from `consumes`, advisory Durable Objects, `declared`/`read`/
    `supplied` secrets. At 0.330.4 the plan misses reads in provider bodies
    and adapter bindings and still says complete (bynk-lang/bynk#1976, fixed
    unreleased by #1997), so `PAYMENTS_API_KEY` is checked by hand. Supplied
    secrets go to every context (ADR 0195), so the key goes on with a scoped
    `--context shop.payments --secret` run; declared values come from the
    environment. `--env` and `bynk.deploy.lock`; the staging plan's unsuffixed
    names (bynk-lang/bynk#2028). bynk-ci and bynk-deploy. `workers.dev`: no
    durable workaround at 0.330.4. Debugging: `bynk dev --inspect`, `Logger`,
    the emitted fault handler, `--upload-source-maps`, and the quiet `503`
    when the key is missing. *Shop:* payments logs why it fails closed.
    *Replaces:* a deploy script, and `console.log` debugging.
    *Deploys:* the shop without events. Nothing here was run against a live
    account; when the pin moves, check the live deploy's output too.

## Part V: Beyond a request

13. **Events**
    Emit and subscribe, at-least-once delivery, `Idempotency`.
    The ledger's Worker won't pass `tsc` while events carry commons types
    (bynk-lang/bynk#2027): `check-book-emit.sh` will need a `build-fail` row
    or a baseline for chapter 13's project until it is fixed.
    *Replaces:* hand-rolled queues and fan-out. *Shop:* the ledger. Says why the
    full shop can't deploy yet (bynk-lang/bynk#1961; fixed on main
    2026-10-16, unreleased at 0.330.4).
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
