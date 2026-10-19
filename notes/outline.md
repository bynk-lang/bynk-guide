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
   keyed by order id as text (`orderRef`), so
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
   (`bynk.history.restates_invariant`, which also catches a restated
   transition).
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
   (`responses.env`) and `--var AUTH_JWT_SECRET`. A test calls an `Admin`
   route with the base identity, and a sum route as any member.
   *Replaces:* auth middleware. *Shop:* `Customer` and `Admin`, owners, and
   the public stock lookup (bynk-lang/shop#8).
8. **Contexts and Service Bindings**
   Orders, inventory and payments as contexts sharing `shop.values`;
   `exports transparent`, `on call` services with `by c: Caller`, `consumes … as`;
   a service coordinates and an agent owns state (an agent may call another
   context; the shop chooses not to). Compensation by hand and why it isn't
   crash-safe; sagas are planned; chapter 14's sweeper. `let … else` named as
   the way to flatten the placement handler. Refusals: another context's agent
   (`bynk.consumes.unknown_service`) and a `consumes` cycle. Beside an existing
   Worker: `Foreign` actors, the typed `bynk-client.ts`, and the experimental
   `Service` capability. Internal calls are signed per pair of contexts, so
   `workers.dev` exposes nothing internal.
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
    `node --test`, and the test gate runs those.
    *Replaces:* a hand-written webhook verifier. *Shop:* already has it all;
    the chapter's copy is rewrapped to fit the page.

## Part IV: Confidence and delivery

11. **Testing at three tiers**
    Unit, integration, system. `system` suites for payments (`env { … }`,
    `by Nobody`, `by Forged`) and for the whole order flow across three
    Workers. Refusals: `bynk.tier.cross_context_needs_system`,
    `bynk.tier.mixed_system_suite`, `bynk.stub.at_system`. What else
    `system` drives (`.schedule`, `.message`, `advance Clock`) and `bynk test
    --against`. The run heads `system` suites `integration`
    (bynk-lang/bynk#2185). Beyond `bynkc test`: binding tests in Node and e2e
    against `bynk dev`.
    *Replaces:* a Miniflare harness.
12. **Run it, ship it, debug it**
    `bynk deploy` and its dry-run plan (gated by `check-book-plans.sh`, which
    allows wrapped lines): order from `consumes`, advisory Durable Objects,
    `declared`/`read`/`supplied`/`managed` secrets, and `secrets incomplete`
    for the gateway binding's reads. Supplied secrets go to every context, so
    the processor's key goes on with a scoped `--context shop.payments
    --secret` run. `--env` (the plan names `-staging` Workers) and
    `bynk.deploy.lock`. bynk-ci and bynk-deploy. `workers.dev`: the address
    returns each deploy, but unsigned internal calls get `401`. Debugging:
    `bynk dev --inspect`, `Logger`, the logged stack, `--upload-source-maps`,
    and the quiet `503` when the key is missing. *Shop:* payments logs why it
    fails closed. The live check was at 0.330.4 (2026-10-17); repeat it.
## Part V: Beyond a request

13. **Events**
    Opens Part V. Orders declares `OrderPlaced` and `OrderCancelled` and emits
    them from its route handlers (an agent could; its emissions release at
    commit). The ledger (`uses shop.values`): `Books` agent, a subscriber per
    event deduping on `env.eventId` with `Idempotency`, `GET /totals` for an
    `Admin`. Refusal: `bynk.event.emit_outside_owner`. Delivery, from the
    emitted code: inside the request, signed per edge, attempted once, a
    failure logged and dropped; `Idempotency` is in memory. Tested with
    `OnPlaced.event(e, env)`, twice. The four-context deploy plan.
    *Replaces:* hand-rolled queues and fan-out. *Shop:* the ledger.
14. **Time and queues**
    Holds gain `at: Instant` from `Clock`; `commit` turns a hold into a sale,
    and orders commits after payment (`409 reservation expired` if the
    sweeper got there first; the gateway can't void yet). A `Catalogue` agent
    lists the skus, since Durable Objects can't be listed. `service sweeper
    from cron` releases holds older than 15 minutes, measured from the
    scheduled time. Refusal: `bynk.cron.bad_params` (an `Instant`
    parameter). The generated `[triggers]` and `[[queues.consumers]]`
    (gated). `--test-scheduled` and `/__scheduled` (transcript), and
    `.schedule` in tests. A queue: `service deliveries from
    queue("stock-deliveries")`, deduped by delivery id in a `Log` in the
    agent; tested with `.message`. Bynk can't produce queue messages yet.
    *Replaces:* a hand-written `scheduled` handler and queue
    consumer. Closes chapter 8's gap.
15. **Changing a deployed system**
    What outlives a deploy: stored state, events, calls. Stored state:
    rehydration validation. Events: `OrderPlaced` gains
    `customer: String = ""`; the `bynk.schema.lock` diff (schema 1 → 2;
    committed locks are gated); refusal `bynk.event.non_additive_schema_change`
    at check time. Calls: the shop has charged the unit price since chapter
    8; the fix passes the total and renames `authorise`'s parameter, a
    contract change. Against a lock recording chapter 14 as live (with
    `contracts` and `expects`), both `--context shop.orders` and
    `--context shop.payments` are refused (`bynk.deploy.contract_skew`).
    What 1.0 is still to settle. *Replaces:* hand-written storage migrations
    and versioned RPC.
## Epilogue: Where to go next

Unnumbered (`chapters/epilogue.typ`). A table of what each chapter replaced.
The Bynk Book, and what this book left to it (WebSockets, `Oidc`,
localisation, static assets, the `bundle` target, the editor). *Architecture
that compiles*. Real programs: the shop, compat-board, examples, status. The
canary, and pinning a project's own version the same way. This book's pin
and the fixes waiting on a release. When the pin moves, revise its list.

## Not covered

WebSockets and `Oidc` actors (pointers to the Book), localisation, static
assets, sagas (pointer to the planned-features appendix), and the language
server and editor tooling. The `bundle` target is introduced in chapter 1 and
then set aside.

Chapter 8 gives one section to the reader who adopts Bynk piecemeal, beside
an existing TypeScript Worker: `Foreign` actors, the generated
`bynk-client.ts`, and the experimental `Service` capability, pointing at the
Book's "Adopt Bynk beside a TypeScript Worker". It doesn't teach the wire
format.
