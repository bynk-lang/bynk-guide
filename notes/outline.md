# Working outline

Provisional. Each chapter names the Bynk construct, the hand-written thing it
replaces, the snippet project that carries it, and the step of the shop it adds.
Chapters 1 to 11 deploy; 12 adds events after deploy (see `brief.md`).

Tests are not saved for chapter 10. From chapter 2 on, each chapter ends with a
unit test of what it built; chapter 10 adds the tiers above that.

## Part I: From a Worker to a service

1. **A Worker in Bynk**
   Installing Bynk, `bynk.toml` and the project layout. A context and an HTTP
   service. `bynkc check`, `bynk dev`. What it emits. The two targets: `bundle`,
   the compiler's default, makes one TypeScript tree with in-process calls and
   no Durable Objects; `workers` makes one Worker per context, which is what
   this book builds and deploys. Say how to choose it, and what `bundle` is for.
   *Replaces:* a `fetch` handler and a `wrangler.toml`.
2. **Types you can trust**
   Records, enums, `opaque` types, refined types, admission at the boundary,
   `Json.decode`. A first unit test.
   *Replaces:* branded types, and hand-rolled validation or a schema library.
3. **Failure in the type, and effects**
   `Result`, `Option`, exhaustive `match`, `?`, mapping to HTTP status. Then
   `Effect`, `<-` and `given`, and the send grid: `let _ <-` waits, `~>` does
   not, and `Effect[()]` is not `void` (a durable write must be awaited).
   *Replaces:* `throw` and `try`/`catch`, and `async`/`await` by habit.

## Part II: State

4. **An agent is a Durable Object**
   Keyed agents, `Cell`, `update`, zeroable state, one owner.
   *Replaces:* a Durable Object class and its storage calls. *Shop:* `Inventory`.
5. **Other kinds of storage**
   `Map`, `Cache` with `@ttl`, `Log` with `@retain`, `Query[T]`, and `Kv`.
   Light: these are 1.x surface, not Foundations. Needs a shop step or
   standalone snippets; the shop uses none of them today.
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
   `release` leaks stock; sagas are planned, see chapter 13).
   *Replaces:* Service Binding glue and hand-typed RPC. *Shop:* orders,
   inventory, payments.
9. **Capabilities, providers and adapters**
   `given`, first-party capabilities (`Fetch`, `Logger`, `Secrets`), a
   provider you can swap, and a platform context that exports a capability.
   Then the host boundary: an `adapter` with a TypeScript binding wraps a real
   payment API behind `Processor`, and a `Signature` actor verifies its
   webhook. This is where a reader leaves Bynk when it can't do what they want.
   May split in two.
   *Replaces:* reading `env` directly, mocks, a hand-written API client, and
   HMAC checks. *Shop:* the payment processor, fake then real.

## Part IV: Confidence and delivery

10. **Testing at three tiers**
    Unit, integration and system tiers; `stub`; observation
    (`expect Cap.op called …`); end-to-end against `bynk dev`.
    *Replaces:* vitest with miniflare, spies, and hand-wired integration tests.
11. **Run it, ship it, debug it**
    `bynk dev`, `bynk deploy`, lock files, secrets, environments, the CI
    actions. Then a deployed Worker that misbehaves: `Logger`, source maps back
    to `.bynk`, reading the emitted TypeScript, and what a `Result` error looks
    like in the Workers dashboard.
    *Replaces:* a deploy script, and `console.log` debugging.
    *Deploys:* the shop without events.

## Part V: Beyond a request

12. **Events**
    Emit and subscribe, at-least-once delivery, `Idempotency`.
    *Replaces:* hand-rolled queues and fan-out. *Shop:* the ledger. Says why the
    full shop can't deploy yet (accuser/bynk#1961).
13. **Time and queues**
    Cron, and queue consumers. *Shop:* a cron job that releases stale
    reservations, closing the gap chapter 8 left open.
14. **Changing a deployed system**
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
