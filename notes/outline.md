# Working outline

Provisional. Each chapter names the Bynk construct, the hand-written thing it
replaces, the snippet project that carries it, and the step of the shop it adds.
Chapters 1 to 11 deploy; 12 adds events after deploy (see `brief.md`).

## Part I: From a Worker to a service

1. **A Worker in Bynk**
   A context and an HTTP service. `bynkc check`, `bynk dev`. What it emits.
   *Replaces:* a `fetch` handler and a `wrangler.toml`.
2. **Types you can trust**
   Records, enums, refined types, admission at the boundary.
   *Replaces:* hand-rolled validation or a schema library.
3. **Failure in the type**
   `Result`, `Option`, exhaustive `match`, mapping to HTTP status.
   *Replaces:* `throw` and `try`/`catch`.

## Part II: State

4. **An agent is a Durable Object**
   Keyed agents, `Cell`, `update`, zeroable state, one owner.
   *Replaces:* a Durable Object class and its storage calls. *Shop:* `Inventory`.
5. **Other kinds of storage**
   `Map`, `Cache` with `@ttl`, `Log` with `@retain`, `Query[T]`.
   *Replaces:* KV, and ad hoc indexing.
6. **State with a lifecycle**
   State machines, initial variants, invariants.
   *Replaces:* status strings and defensive checks. *Shop:* `Order`, and the
   stock invariant.

## Part III: Who is calling, and who is it for

7. **Actors**
   `Visitor`, `Bearer`, an authorisation refinement (401 vs 403).
   *Replaces:* auth middleware. *Shop:* `Customer` and `Admin`.
8. **Contexts and Service Bindings**
   `consumes`, `on call`, `Caller`; the service coordinates, the agent owns
   state (footnote accuser/bynk#1960).
   *Replaces:* Service Binding glue and hand-typed RPC. *Shop:* orders,
   inventory, payments.
9. **Capabilities and providers**
   `given`, first-party capabilities, a provider you can swap.
   *Replaces:* reading `env` directly, and mocks. *Shop:* the payment processor.

## Part IV: Confidence and delivery

10. **Testing at three tiers**
    Unit, integration and system tiers; `stub`; end-to-end against `bynk dev`.
    *Replaces:* vitest with miniflare, and hand-wired integration tests.
11. **Run it, then ship it**
    `bynk dev`, `bynk deploy`, lock files, secrets, environments, the CI
    actions. *Replaces:* a deploy script. *Deploys:* the shop without events.

## Part V: Beyond a request

12. **Events**
    Emit and subscribe, at-least-once delivery, `Idempotency`.
    *Replaces:* hand-rolled queues and fan-out. *Shop:* the ledger. Says why the
    full shop can't deploy yet (accuser/bynk#1961).
13. **Time and queues**
    Cron, and queue consumers. Light.
14. **Changing a deployed system**
    The schema lock, migrations, contract skew. Light, and honest about what
    1.0 is still to settle.

## Epilogue: Where to go next

The Book, *Architecture that compiles*, the examples index, the canary.

## Not covered

WebSockets and `Oidc` actors (pointers to the Book), the `bundle` target, and
the language server and editor tooling.
