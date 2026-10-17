#import "../template.typ": code-listing, compiler-message, lead-in

= Run it, ship it, debug it <run-it-ship-it-debug-it>

The shop has run on a laptop since chapter 1, under `bynk dev`, and in CI
under `bynkc test`. It has never run on Cloudflare. This chapter deploys it:
three Workers, in the right order, each with the secrets it needs and none it
doesn't. Then it looks at what you have to go on when a deployed Worker
misbehaves.

Most of what deploying involves, Bynk can work out from the program: which
Workers there are, which one binds to which, which secrets an actor checks.
Some of it, at 0.330.4, it can't, and the chapter is careful to say which is
which. The shop's likeliest production failure falls into that gap.

== The script you would write <ix-guide-12-the-script-you-would-write>

#lead-in[
By hand, the shop's three Workers deploy with Wrangler, one at a time, and
their secrets go up afterwards:
]

#code-listing(
  [Deploying three Workers, by hand],
  read("../snippets/chapter-12/conventional.sh"),
  lang: "sh",
)

Two things in this script are facts about the program, kept somewhere else.
The order of the loop is the shape of the Service Bindings: orders binds to
inventory and payments, so it goes last. And the list of secrets is the list
of names the code reads, Worker by Worker. Add a binding or read a new secret
and the script is wrong until someone remembers it. There is also a window
between each `wrangler deploy` and its `secret put` in which the Worker is live
without its secrets.

== One command, and its plan <ix-guide-12-one-command-and-its-plan>

`bynk deploy` deploys every context in a project, in order. Before you run it
for real, ask it what it would do:#footnote[
  The Bynk Book, “Deploy to Cloudflare”.
]

#code-listing(
  [Asking for the plan],
  "bynk deploy --dry-run",
  lang: "sh",
)

#code-listing(
  [The shop's deploy plan],
  read("../snippets/chapter-12/plan.txt"),
  lang: "text",
)

A dry run makes no Cloudflare calls and needs no account, so CI can print it
on every pull request. Each line is something the program committed the
deploy to:

- *`deploy`* lines, one per context, in the order the last line gives. The
  order comes from the `consumes` declarations: Cloudflare resolves a Service
  Binding when a Worker is uploaded, so a Worker uploaded before one it binds
  to is rejected. A `consumes` cycle is already a compile error, so a project
  that compiles always has an order.
- *`durable object`* lines, one per agent. They are _advisory_: the generated
  `wrangler.toml` declares each class, and Cloudflare creates whichever
  namespaces are missing. There is no migration tag to keep in step, as
  chapter 4 said. Chapter 15 comes back to removing or renaming an agent,
  which Bynk never does for you.
- *`secret set`* lines, marked with how Bynk knows the name. Both of these are
  `declared`: the `Customer` actor in orders, which `Admin` refines, verifies
  tokens with `AUTH_JWT_SECRET`, and the `ProcessorHook` actor in payments
  verifies signatures with `PAYMENTS_WEBHOOK_SECRET`. Each goes only to the context
  whose actor declares it.

#lead-in[
Run it for real, with the declared secrets' values in the environment:
]

#code-listing(
  [Deploying],
  "AUTH_JWT_SECRET=… PAYMENTS_WEBHOOK_SECRET=… bynk deploy",
  lang: "sh",
)

`bynk deploy` checks Node and Wrangler, compiles the project, prints the plan,
checks that Wrangler is signed in, and asks before it changes anything (`--yes`
skips the question, for scripts). Then, context by context, it sets the
secrets and uploads the Worker. On a Worker that already exists, the secrets
go first. On a Worker's first deploy they go straight after the upload, so for
a few seconds the new Worker is live without them, and refuses what its actors
can't verify (bynk-lang/bynk#2055). Nothing is printed when a secret is set; `wrangler versions
list` shows it, as a `Secret Change` version beside the `Upload`. A missing
value for a declared secret stops the deploy, naming the secret: a Worker
without its actor's secret would refuse every request.

Secrets are set only if they are absent, because Cloudflare never gives a
value back to compare with. Pass `--force` after you rotate one. A second run
says `redeploy` for each Worker and skips each secret, saying it is already
set, though its plan still lists the `secret set` line. A deploy that
fails part-way leaves the contexts that landed deployed; fix the problem and run
it again, and it carries on in the same order.

Once the whole project has been deployed, `--context` pushes a single context,
which is what you want while you iterate on one of them. It doesn't deploy the
contexts it consumes, and if one of them has never been deployed it refuses,
rather than send an upload Cloudflare would reject.

== What the plan knows about secrets <ix-guide-12-what-the-plan-knows>

`declared` is one of three marks a `secret set` line can carry. The other two
are `read`, for a literal name passed to `Secrets.get`, and `supplied`, for a
name you give the deploy yourself. A missing `read` value is a warning rather
than an error, since `Secrets.get` returns an `Option` and the code already
handles `None`. And when a context reads a name the compiler can't see, such as
one it computes, the plan says the list is incomplete. A short list that looks
complete is the thing it is built not to print.

Payments reads three settings: `PAYMENTS_PROCESSOR` in the provider from
chapter 9, and `PAYMENTS_API_KEY` and `PAYMENTS_API_URL` in the gateway's
TypeScript binding from chapter 10. The plan above shows none of them. At
0.330.4 the compiler collects `Secrets.get` calls in handlers only, not in a
provider's body, and it can't see into a binding at all, yet it still calls
payments' list complete (`--format json` gives `"secrets_complete": true`).
The fix is on Bynk's main branch (bynk-lang/bynk#1997), not yet released. With
it, the plan reads `PAYMENTS_PROCESSOR` and marks payments incomplete.

So for now, check by hand. The shop runs in production with
`PAYMENTS_PROCESSOR` unset, which selects the real processor, and needs
`PAYMENTS_API_KEY`, which nothing will remind you to set. Forget it, and the
deploy succeeds without a warning, and every order fails. The last part of
this chapter is about finding that out.

== Supplied secrets go everywhere <ix-guide-12-supplied-secrets-go-everywhere>

#lead-in[
Name the key yourself with `--secret`, which takes its value from the
environment, and look at where it goes:
]

#code-listing(
  [`bynk deploy --dry-run --secret PAYMENTS_API_KEY`],
  read("../snippets/chapter-12/plan-spread.txt"),
  lang: "text",
)

A supplied name goes to every context in the run. Nothing tells the deploy
which contexts read it, so the choices are all of them or none, and Bynk
chooses all and lists each one so that you can see it. A `--secrets-file` is
the same, for every name in it, declared names included: put
`AUTH_JWT_SECRET` in the file and it lands on inventory and payments too. The
processor's key on Workers that never charge a card is exactly what a
hand-written script wouldn't do.

#lead-in[
To keep the key on payments, deploy the whole project once, as above, and then
give payments its key in a run of its own:
]

#code-listing(
  [Setting a secret on one context],
  "PAYMENTS_API_KEY=… bynk deploy --context shop.payments \\\n  --secret PAYMENTS_API_KEY",
  lang: "sh",
)

#code-listing(
  [Its plan],
  read("../snippets/chapter-12/plan-payments.txt"),
  lang: "text",
)

The plan above is a dry run on a project that has never been deployed. Run
after the first deploy, as it would be, the last line reads `redeploy
shop-payments`: the plan checks `bynk.deploy.lock` for what is live. Because
secrets are set only if absent, a later whole-project deploy leaves the key
where it is.

== Environments and the lock file <ix-guide-12-environments-and-the-lock-file>

`bynk deploy --env staging` deploys the same project to a named environment.
Cloudflare doesn't carry bindings into a named environment, so the deploy
writes an environment's section into the generated `wrangler.toml` each time.
You never write that section, and it goes when the build is replaced. Bynk's
deploy guide says queue names and Service Binding targets take a `-staging`
suffix there, so that the environments never share a queue or call each
other's Workers.

The first deploy also writes `bynk.deploy.lock`, beside `bynk.toml`. Commit
it. It holds no secrets. For each environment it records the ids of the KV
namespaces Cloudflare created, which exist nowhere else, and which contexts
have been deployed, which is how `--context` knows whether the contexts it
binds to are live. The shop has no KV namespace now, but a project that does
must run its first deploy from a machine that can commit the lock file. CI
refuses to create a namespace whose id it can't record.

At 0.330.4 the staging plan doesn't show this. It names the same Workers and
binding targets as the default one, `shop-orders` binding to
`shop-inventory`. The deploy does what the guide says: run for real, it
creates `shop-orders-staging`, bound to `shop-inventory-staging` and
`shop-payments-staging`, and leaves `shop-orders` alone. The plan's fix is on
Bynk's main branch (bynk-lang/bynk#2034). A project with a KV namespace should
read bynk-lang/bynk#2037 before it shares an account between environments: at
0.330.4 the bare `Kv`'s namespace keeps one title in every environment. The
shop has none.

== In CI <ix-guide-12-in-ci>

Two GitHub Actions do the work. `bynk-lang/bynk-ci` runs the format check, the
type check and the tests, and annotates diagnostics on the pull request.
`bynk-lang/bynk-deploy` installs Bynk and Node and runs `bynk deploy --yes`:

#code-listing(
  [Deploying from CI],
  read("../snippets/chapter-12/deploy.yml"),
  lang: "yaml",
  breakable: true,
)

The declared secrets come in through the job's environment, so each reaches
only its own context. The processor's key goes in the action's `secrets`
input, which becomes a `--secrets-file`, on a second step for payments
alone. Pin `version` to the release you test against; the canary tests the
newer ones.

The action never commits. When a deploy changes `bynk.deploy.lock`, it warns
and sets a `lock-changed` output, and the change is yours to commit. With
`dry-run: "true"` it prints the plan and needs no token, which makes it a
useful check on a pull request.

The shop's own `deploy.yml` is manual-only for now, for a reason that belongs
to chapter 13.

== `workers.dev`, at 0.330.4 <ix-guide-12-workers-dev>

Chapter 8 warned that the channel between contexts is less private than it
looks. Here is what that means once the shop is deployed.

The generated `wrangler.toml` sets neither `routes` nor `workers_dev`, and
when there are no routes Wrangler gives the Worker a `workers.dev` address.
It does so on every deploy, so turning the address off in the dashboard lasts
until the next one. Wrangler says so in a warning, and turns the Worker's
preview URLs back on with it. Every Worker answers its `on call` services and event
deliveries at that address, and trusts whichever caller the request claims.
So anyone who finds `shop-inventory`'s address can call `reserve`, claiming to
be orders. The contract hash each call carries doesn't stop it: a call
without the hash gets a `409` that names the one it expected.

At 0.330.4 there is no setting that keeps the address off, and it wouldn't be
enough if there were: orders and payments serve public routes as well, and
every route serves the internal paths. The fix is on Bynk's main branch. A
shared secret on every internal call comes first (bynk-lang/bynk#2004), then a
signature per pair of contexts (bynk-lang/bynk#2012). Neither is released yet.
Until they are, deploy the shop to try it, not to take real money.

== When a deployed Worker misbehaves <ix-guide-12-when-a-worker-misbehaves>

Reproduce it locally first, if you can. `bynk dev --inspect`, which every
transcript in this book has run under, opens a V8 inspector for each context,
counting up from port 9229. Bynk's source maps point back to the `.bynk`
files, so a breakpoint set in a handler stops there, and Bynk's VS Code
extension attaches with one launch configuration.#footnote[
  The Bynk Book, “Debug in VS Code”.
]

On Cloudflare, what you have is what the Worker writes. `Logger.info` is
`console.log` and `Logger.error` is `console.error`, and both reach
`wrangler tail` and Cloudflare's logs. Bynk adds one line of its own.

#lead-in[
A handler that throws, rather than returning, is caught at the top of the
Worker's `fetch`:
]

#code-listing(
  [What a fault becomes, in the emitted `index.ts`],
  read("../snippets/chapter-12/emitted/fault.ts"),
  lang: "typescript",
)

The log line names the context, the route and the error's message, and the
client gets a bare `500` with nothing of the error in it. In `wrangler tail`
that is all there is. Bynk caught the error, so the tail reports the request's
outcome as `ok`, with no exception and no stack trace. Wrangler will upload
source maps if asked (`bynk deploy -- --upload-source-maps`, or the action's
`extra-args`), and the map it builds does lead back to the `.bynk` files, with
the source inside it. But at 0.330.4 the tail has no stack trace to apply it
to (bynk-lang/bynk#2053). The message and the route are what you get; to find the line, reproduce
the fault under `bynk dev --inspect`.

And the emitted TypeScript is there to read, as chapter 1 showed. What `bynk
deploy` uploads is under `.bynk/deploy/workers/`, one directory per context,
with its handlers, its composition root and its `wrangler.toml`.

== The quiet failure <ix-guide-12-the-quiet-failure>

The shop rarely throws. Refined types turn bad input into a `400` at the
boundary, and a failure the code expects is a `Result`, which becomes a
status and a body. In Cloudflare's logs an `Err` looks like any other
response: a request and a status code, with no exception and no stack.

That makes the gap from earlier in the chapter hard to see. Deploy without
`PAYMENTS_API_KEY`, and the provider asks the gateway, the gateway finds no
key, and payments fails closed, as chapter 9 designed it to:

#code-listing(
  [Ordering with no processor key],
  read("../snippets/chapter-12/unavailable.txt"),
  lang: "text",
)

Every order is a `503`. Nothing has faulted, so nothing is logged, and nothing
in the plan said the key was needed. Failing closed is right, but failing
closed in silence leaves you with a status code and a guess.

#lead-in[
So the provider says why:
]

#code-listing(
  [`payments.bynk`, chapter 11 to chapter 12],
  read("../snippets/chapter-12/payments.diff"),
  lang: "diff",
  breakable: true,
)

Now the same order writes `processor unavailable for o1` to the payments
Worker's log, under `bynk dev` and on Cloudflare alike. The payments suite's
"cannot be reached" case checks it with
`expect Logger.error called with msg == "processor unavailable for o1"`, so the
line can't quietly disappear. From there, `wrangler secret list --name
shop-payments` shows which secrets the Worker has, and the scoped deploy
above sets the missing one.

The rule this gives is worth keeping after the fix for the plan is released:
wherever a program fails closed, log the reason. The status code is for the
client; the log is for you.

== What it costs <ix-guide-12-what-it-costs>

A deploy plan is only as good as what the compiler can see. At 0.330.4 it
misses the reads in a provider and a binding, and it will never see a name
that is computed, though it will say so. Keep a short list of the settings a
context needs that the plan doesn't show, and check it against `wrangler
secret list` after a first deploy.

Supplied secrets go to every context in the run, and the way around it is a
second, scoped deploy. That is one more step than the hand-written script,
which put each secret where it belonged because you told it to.

A multi-context deploy is resumable, not transactional. If the third context
fails, the first two stay deployed, at the new version, beside an old one.
Chapter 15 is about what that means once the contracts between them change.

And the plans in this chapter are what `bynk deploy --dry-run` prints, checked
against the release on every build of this book. What Cloudflare does with
them was checked once, by hand, against 0.330.4 on a scratch account, and
isn't re-checked on every build. Read the first real deploy's output, not
just the plan.

== Where this leaves the shop <ix-guide-12-where-this-leaves-the-shop>

The shop deploys with one command, in the order its bindings need, with each
declared secret on the Worker that checks it and the processor's key on
payments alone. It logs the one failure that would otherwise be silent. It is
not yet safe to run for real, because of `workers.dev`, and that waits on a
release.

The next chapter adds a ledger that records every order, fed by events
rather than calls, and finds that the deploy has an opinion about that too.
