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
   first unit test. Enums wait for chapter 3, where `OrderError` needs one.
   *Replaces:* branded types, and hand-rolled validation or a schema library.
   *Shop:* `shop.values` and `OrderLine` (bynk-lang/shop#5).
3. **Failure in the type, and effects**
   Enums, `Result`, `Option`, exhaustive `match`, `?`, mapping to HTTP status. Then
   `Effect`, `<-` and `given`, and the send grid: `let _ <-` waits, `~>` does
   not, and `Effect[()]` is not `void` (a durable write must be awaited).
   *Replaces:* `throw` and `try`/`catch`, and `async`/`await` by habit.

## Part II: State

4. **An agent is a Durable Object**
   Keyed agents, `Cell`, `update`, zeroable state, one owner. An opaque value
   has no zero, so `Order` keeps its line as `Option[OrderLine]`.
   *Replaces:* a Durable Object class and its storage calls. *Shop:* `Inventory`.
5. **Other kinds of storage**
   `Map`, `Query[T]`, `Log` with `@retain`, `Cache` with `@ttl`, and `Kv`.
   Light: these are 1.x surface, not Foundations.
   *Shop:* `Inventory` keeps its reservations as `holds: Map[String, Hold]`,
   keyed by order id, so reserving twice holds the stock once and releasing is
   idempotent; a `Query` totals the units held. The timestamp on a hold waits
   for chapter 14, which needs `Clock`. Project entries into a named record
   before `.collect()`, which is the documented idiom and also avoids
   accuser/bynk#1977. `Log` is introduced here with a standalone snippet and
   used for real in chapter 10. `Cache` and `Kv` are standalone snippets: the
   shop has no natural use for them.
   *Replaces:* KV, and ad hoc indexing.
6. **State with a lifecycle**
   State machines, initial variants, invariants. A history property
   (`for all run: History[Order]`) proves the machine.
   *Replaces:* status strings and defensive checks. *Shop:* `Order`, and the
   stock invariant.

## Part III: Who is calling, and who is it for

7. **Actors**
   `Visitor`, `Bearer`, an authorisation refinement (401 vs 403), and several
   kinds of caller on one route (`User | Visitor`).
   *Replaces:* auth middleware. *Shop:* `Customer` and `Admin`.
8. **Contexts and Service Bindings**
   `consumes`, `on call`, `Caller`; the service coordinates, the agent owns
   state (footnote accuser/bynk#1960). `commons` for types shared between
   contexts. Compensation by hand: reserve, authorise, release on failure, and
   why that is not crash-safe (a Worker that dies between `reserve` and
   `release` leaks stock; sagas are planned, see chapter 14).
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
    `node --test`, because `bynkc test` can't reach it yet (accuser/bynk#1975).
    This is where a reader leaves Bynk when it can't do what they want.
    *Replaces:* a hand-written API client, and HMAC checks. *Shop:*
    `shop.gateway`, the real processor, and `POST /webhooks/processor`.

## Part IV: Confidence and delivery

11. **Testing at three tiers**
    Unit, integration and system tiers; `stub`; observation
    (`expect Cap.op called …`); end-to-end against `bynk dev`, including signed
    and forged webhooks. Teach the working forms: `expect r is Ok(v)`
    (accuser/bynk#1979), and `by Caller("…")` when a test calls a `by c: Caller`
    service (accuser/bynk#1978).
    *Replaces:* vitest with miniflare, spies, and hand-wired integration tests.
12. **Run it, ship it, debug it**
    `bynk dev`, `bynk deploy`, lock files, secrets, environments, the CI
    actions. `bynk-secrets.json` can miss reads made in provider bodies and
    adapter bindings, so `bynk deploy` won't warn that `PAYMENTS_API_KEY` is
    unset (accuser/bynk#1976); say what to check by hand. Then a deployed Worker
    that misbehaves: `Logger`, source maps back
    to `.bynk`, reading the emitted TypeScript, and what a `Result` error looks
    like in the Workers dashboard.
    *Replaces:* a deploy script, and `console.log` debugging.
    *Deploys:* the shop without events.

## Part V: Beyond a request

13. **Events**
    Emit and subscribe, at-least-once delivery, `Idempotency`.
    *Replaces:* hand-rolled queues and fan-out. *Shop:* the ledger. Says why the
    full shop can't deploy yet (accuser/bynk#1961).
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
footnote the interop track (accuser/bynk#1973).
