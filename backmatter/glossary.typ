= Appendix: Glossary <glossary>

The Bynk terms this book uses, each with the chapter that introduces it. The
Bynk Book's reference has the exact rules.

#let term(name, chapter, body) = block(above: 1.1em, below: 1.1em, breakable: false)[
  #set par(first-line-indent: 0pt)
  *#name* #h(0.4em) #text(size: 0.85em, fill: rgb("#6b6880"))[ch. #chapter]
  #v(-0.45em)
  #pad(left: 1.2em, body)
]

#term[actor][7][
  Who is calling a handler, declared on the handler with `by`. An actor is
  admitted at the boundary: a `Bearer` actor by a signed token, a `Signature`
  actor by an HMAC over the request, `Visitor` by nothing at all. A
  _refinement actor_ such as `Admin = Customer where hasClaim("admin")`
  narrows another.
]

#term[adapter][10][
  A unit that declares capabilities whose provider is written in TypeScript,
  in a _binding_ file beside it. The one place a Bynk program reaches npm or
  an outside API directly.
]

#term[agent][4][
  A unit of state with a key, compiled to a Durable Object. Its `store`
  fields are its state; its handlers are the only code that changes them, and
  each handler's changes commit together.
]

#term[`Caller`][8][
  The actor of an `on call` service: the name of the context that called it,
  stamped by the compiler at the call site.
]

#term[capability][9][
  A named set of operations, each returning an `Effect`, that a handler is
  _given_. `Logger`, `Clock`, `Secrets`, `Fetch`, `Events` and `Idempotency`
  are Bynk's own; a program can declare more.
]

#term[commons][2][
  A unit of shared types and pure functions, used by contexts with `uses`.
  It deploys as nothing on its own.
]

#term[context][8][
  A unit that deploys as one Worker. A context `consumes` another to call its
  `on call` services, which become Service Binding calls.
]

#term[contract hash][15][
  A fingerprint of a cross-context call's shape, stamped into the caller and
  the callee when each is built. A call whose hashes differ is refused with
  `409 ContractMismatch`, and `bynk deploy` refuses a push that would cause
  one.
]

#term[`Effect`][1][
  The type of a computation that reaches outside the program. `<-` runs one
  and binds its result, `~>` sends one without waiting, and `do` runs one for
  its effect alone.
]

#term[`embeds`][3][
  Declares that an error type can carry another, so `?` converts the inner
  error into the outer one.
]

#term[event][13][
  A fact a context declares and emits with `Events.emit`, for any number of
  other contexts to subscribe to with `from Events(E)`.
]

#term[invariant][6][
  A condition on an agent's state, checked at every commit. A handler that
  would break one fails, and nothing it changed is kept. A _transition_ is the
  same for a pair of states, before and after.
]

#term[opaque type][2][
  A type whose representation only its own commons can see, so a `Sku` can't
  be passed where an `OrderId` is wanted, though both are strings.
]

#term[provider][9][
  The implementation of a capability, declared with `provides`. A context has
  one provider per capability.
]

#term[refined type][2][
  A type with a predicate, such as `Int where InRange(1, 1000)`. A value is
  checked against it where it enters the program, and a literal is checked
  when it is compiled.
]

#term[rehydration][15][
  Loading an agent's stored state, checked against the current types. A value
  that no longer fits is a `RehydrationViolation`.
]

#term[`Result`][3][
  `Ok(value)` or `Err(error)`: a failure the caller has to handle, in the
  type. `?` returns early with the error.
]

#term[schema lock][15][
  `bynk.schema.lock`, the record of each event's shape and version. A build
  refuses an event change that isn't additive.
]

#term[service][1][
  The entry point of a context, with a protocol: `from http`, an `on call`
  service, `from cron`, `from queue(…)` or `from Events(E)`.
]

#term[store][4][
  An agent's state field: a `Cell`, `Map`, `Set`, `Cache` or `Log`. A `Query`
  reads several stores at once.
]

#term[tier][11][
  How much of the world a test case makes real: `unit` (the default),
  `integration` (real collaborators in one context) or `system` (built
  Workers, over the JSON wire).
]
