#import "../template.typ": code-listing, compiler-message, lead-in

= Changing a deployed system <changing-a-deployed-system>

Every chapter so far has changed the shop freely. Nothing was running, so a
renamed field or a new parameter cost nothing but an edit. A deployed system
is different. Its agents hold data written by an older version of the code,
its events are in flight between Workers built at different times, and its
contexts can be deployed one at a time, so for a while they may disagree
about what a call looks like.

This chapter makes two changes to a shop that is assumed to be live. One adds
a field to an event. The other fixes a bug, one that has been in the shop
since chapter 8. Along the way it looks at what Bynk checks when you change a
running system, what it leaves to you, and what it hasn't settled yet.

You have probably done this by hand, and it is worth being plain about how
much of it Bynk still leaves to you.

== The migration you would write <ix-guide-15-the-migration-you-would-write>

#lead-in[
By hand, a Durable Object that changes the shape of what it stores migrates
its own storage before it serves a request:
]

#code-listing(
  [Migrating a Durable Object's storage, by hand],
  read("../snippets/chapter-15/conventional.ts"),
  lang: "typescript",
)

This works, and it is the standard pattern. It is also code that runs once
per object, against data nobody can see, with a version number you maintain
by hand. Every reader of `owner` has to change in the same deploy. A mistake
is found when an old object wakes up.

== What outlives a deploy <ix-guide-15-what-outlives-a-deploy>

Three things in a Bynk system outlive the code that made them:

- *An agent's stored state.* It was written by the last version of the
  agent, and the next version has to read it.
- *Events.* An event emitted by one version of orders may be delivered to a
  ledger built from another.
- *Calls between contexts.* Each context is its own Worker, deployed when it
  is deployed. Orders and payments may be running different versions of the
  same contract.

Bynk has a different answer for each, and they are not equally complete.

== Stored state <ix-guide-15-stored-state>

An agent's state is stored in the same JSON shape that crosses the wire, and
checked against the current type definitions each time an agent loads it. A
stored value that no longer fits is a `RehydrationViolation`: the agent faults
rather than run on data it can't trust, and the log names the agent and the
field, but not the value.#footnote[
  The Bynk Book's agents reference, “Rehydration validation”.
]

The lock file helps before it comes to that. `bynk.schema.lock`, beside
`bynk.toml`, records the shape of each agent's stored state as well as each
event's: every `Cell`, `Map` and `Log` with its type and refinement. `bynkc check`, `bynkc test`, the editor and every build compare the code
with the committed lock, and a stored record is stamped with the schema version it was
written under, so a record the code can't read faults at load instead of being
guessed at. That gives three rules:

- *Adding a store field is safe.* An agent loaded with state from before the
  field existed gets the field's initial value. Nothing needs migrating, and
  the next build records the new field in the lock.
- *Removing or retyping a store field is refused.* Adding a state to the
  `Status` enum counts as retyping `status`, so the order's lifecycle is under
  the same rule.
- *Tightening a type is a warning.* If the shop narrowed `Quantity` from
  `InRange(1, 1000)` to `InRange(1, 100)`, the check warns that the refinement
  on `Order.line`'s stored type changed (`bynk.agent.refinement_changed`).
  Every `Order` and every `Hold` that stored a larger quantity would fault the
  next time it loaded. Bynk doesn't coerce the value or drop it, because stored
  data that no longer fits looks exactly like corrupted data. It is a warning
  because widening a refinement is safe, and the check can't always tell which
  way you went.

#lead-in[
Delete `units` from the ledger and the check refuses:
]

#compiler-message[
[bynk.agent.non_additive_state_change] Error: agent `Books`'s stored state
changed in a way deployed data cannot be read through — field(s) removed:
units
]

There is no migration step in the language yet; the release notes say a
declared one is coming. Until then a change that would break stored data is
made in two moves, by convention: add a new field of the new type, write it
from the handlers that change the state, and read the old one only when the
new one isn't there yet. That is the hand-written migration above, done lazily,
one field at a time. The old field stays, in the code and in the lock, which
refuses its removal. An agent that was never deployed has nothing to protect:
delete its entry from the lock to record the new shape as a fresh baseline.

Agents themselves need care too. Chapter 12 showed that `bynk deploy`
declares each agent's Durable Object class and lets Cloudflare create what is
missing. Deleting or renaming an agent leaves its stored data behind, under a
class the code no longer declares, and Bynk never makes that decision for you.

== Events <ix-guide-15-events>

#lead-in[
The ledger would like to know who placed each order. Orders adds a field to
`OrderPlaced`, with a default, and fills it in:
]

#code-listing(
  [`orders.bynk`, chapter 14 to chapter 15],
  read("../snippets/chapter-15/orders.diff"),
  lang: "diff",
  breakable: true,
)

The middle hunk is the bug fix, which the next section is about.

#lead-in[
Every build reconciles each event's shape with the same `bynk.schema.lock`,
and this build changes it:
]

#code-listing(
  [`bynk.schema.lock`, chapter 14 to chapter 15],
  read("../snippets/chapter-15/schema-lock.diff"),
  lang: "diff",
  breakable: true,
)

`OrderPlaced` is now at schema 2. A field added with a default is an
_additive_ change, so the registry moves the version on by itself. Commit the
lock with the source change. Its diff in a pull request is the record of how
the event changed.#footnote[
  The Bynk Book, “Understand events”: the schema registry.
]

Additive changes are safe in both directions, which is what makes the
default necessary. A ledger built before the change still decodes the new
events: the emitted decoder reads the fields it knows and ignores the rest. A
ledger built after it decodes the old events, still being delivered from an
orders Worker that hasn't been redeployed yet, by filling `customer` with
`""`.

#lead-in[
Leave out the default and the check refuses:
]

#compiler-message[
[bynk.event.non_additive_schema_change] `OrderPlaced` changed in a way the
schema registry cannot evolve additively — field(s) added without a default:
customer
]

`bynkc check`, `bynkc test`, the editor and every build compare each event
with the committed lock, read-only, so a breaking event change fails CI and
shows in the editor before anyone builds it. Only a build writes the lock,
which is why an additive change passes the check and the next compile records
it. The same refusal meets removing a field, retyping one, or taking a
default away. A change like that is a new event. Give it a new name, emit
both while subscribers move over, and stop emitting the old one when none is
left. A subscriber can also say which versions it handles with `via
schema(N)`, and an event can state its version with `@schema(N)`, which the
registry checks rather than trusts.

== Calls between contexts <ix-guide-15-calls-between-contexts>

Since chapter 8, orders has asked payments to authorise `body.cents`: the
price of one unit. An order for three widgets at 25.00 authorised 25.00. The
fake processor never noticed, and neither did a test, because nothing
compared the charge with the order's total.

#lead-in[
The fix passes the total, `t`, which the handler has worked out since chapter
3. Payments renames its parameter so the next reader can't make the same
mistake:
]

#code-listing(
  [`payments.bynk`, chapter 14 to chapter 15],
  read("../snippets/chapter-15/payments.diff"),
  lang: "diff",
)

The fix alone changes only the number orders sends. The rename changes the
_contract_. When Bynk builds orders, it fingerprints payments' `authorise` as
orders understands it: the parameter names and types, the return type, every
field that crosses. It stamps that hash into each call. Payments' Worker
carries its own hash, and checks the two before it reads the request. If they
differ, it answers `409 ContractMismatch`, naming both, and both Workers log
it.#footnote[
  The Bynk Book, “Contract skew across independently deployed contexts”.
]

So a renamed parameter is a contract change, and so is a retyped one, an
added or removed field, a changed refinement, or a new variant. Reordering a
record's fields isn't, and nor is tightening an opaque type's predicate,
which a caller can't observe.

#lead-in[
`bynk deploy` checks the same thing before anything is pushed. Its lock file
records the contracts each Worker had when it was deployed. With a lock that
records the chapter 14 shop as live, pushing orders alone is refused:
]

#compiler-message(read("../snippets/chapter-15/skew-orders.txt"))

The new orders would send a hash the live payments rejects. The remedy is in
the message: deploy the whole project, so that both sides move together. A
contract change is a coordinated deploy. Bynk doesn't run two versions of a
contract side by side.

#lead-in[
The same check runs in the other direction. Pushing payments alone, with the
renamed parameter, would leave the live orders Worker stamping the old hash on
every call, and that is refused too:
]

#compiler-message(read("../snippets/chapter-15/skew-payments.txt"))

The lock records both halves of each contract: what every live Worker
provides, and what it was compiled to expect of the contexts it calls. So a
pushed context is checked against its callees and against its live callers,
and a `409` in production needs a push that went around `bynk deploy`.

== What 1.0 is still to settle <ix-guide-15-what-1-0-is-still-to-settle>

Bynk is pre-1.0, and the honest summary of this chapter is that it _detects_
change much better than it _manages_ it.

- *Two contract versions at once.* A contract change is a coordinated deploy
  of every context it touches. There is no way to serve the old contract and
  the new one together while callers move over.
- *Migrating agent state.* Additive changes are automatic, and breaking ones
  are refused at build by the lock and at load by the runtime. What is missing
  is the migration itself: no migration step in the language yet, and no way to
  run one across every instance.
- *Events after the fact.* There is no replay. A ledger added to a running
  shop starts from the next event, and one that missed events can't catch
  up. Replay is designed and scheduled before 1.0 but not built, and so are
  sagas, the coordinated multi-step workflows that would make chapter 8's
  release-and-reject compensation safe across a crash.#footnote[
    The Bynk Book, “Versioning & roadmap”.
  ]
- *Delivery you can rely on.* Events are delivered once, inside the
  emitting request, with no retry, and `Idempotency` remembers only as long
  as an isolate lives (chapter 13). A durable provider and retries are
  named as future work.

== What it costs <ix-guide-15-what-it-costs>

The schema lock and the contract hash are checks you would otherwise not have
at all. A renamed parameter in a TypeScript Service Binding is found when a
request fails, and an event with a missing field is found by the subscriber
that throws on it. Here both are found before anything is deployed, as long as
the deploy goes through `bynk deploy`.

But the checks only say no. When the answer is "deploy everything together"
there is no partial step, and when the answer is a `RehydrationViolation`,
the data is still there and still unreadable, and the fix is yours to write.

== Where this leaves the shop <ix-guide-15-where-this-leaves-the-shop>

The shop charges what an order comes to, and its events say who placed each
order. Both changes are recorded where the next person will look: the event's
in `bynk.schema.lock`, the call's in its contract hash. It is four contexts,
five agents with state worth keeping, two events, a schedule and a queue, and
every rule it depends on is checked by the compiler or refused at the
boundary.

That is the shop. The last pages are about where to go from here.
