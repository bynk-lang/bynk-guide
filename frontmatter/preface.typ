#import "../metadata.typ": book-meta

= Preface <preface>

You have probably written a Worker that grew. It started as one `fetch`
handler and became a router, then a Durable Object, then a second Worker
behind a Service Binding, with a queue between them and a cron job sweeping
up after both. Each step was reasonable. By the end, the rules that matter
most (which Worker owns which state, who may call what, what happens when a
call fails) live in middleware, in `wrangler.toml`, in tests and in the heads
of the people who wrote them.

Bynk is a language for writing those Workers so that the rules live in the
program instead, where a compiler can check them. This book teaches it by
building one service, a small shop, from a single route to four contexts that
deploy as four Workers.

== What this book is for

You are a TypeScript or Cloudflare developer. You have written a Worker, you
know what a Durable Object and a Service Binding are for, and you have used
`wrangler`. You don't need to know anything about Bynk, and you don't need to
have decided to use it.

So the book doesn't explain the platform. Each chapter starts with something
you would otherwise write by hand: a router, an input check, a Durable Object
class, auth middleware, a Miniflare harness, a deploy script. It shows that
code briefly, then builds the same thing in Bynk, and then asks what the
change costs. Every chapter ends with a section called _What it costs_,
because a language that checks more also asks more of you, and you should be
able to judge whether that trade suits your system.

The shop grows in five parts:

- *From a Worker to a service* (chapters 1–3): routes, types that refuse bad
  input, and failure in the type of a result.
- *State* (chapters 4–6): agents, the Durable Objects Bynk generates for you,
  their storage, and the rules their state must keep.
- *Who is calling, and who is it for* (chapters 7–10): actors, contexts that
  call each other, capabilities, and the boundary with TypeScript.
- *Confidence and delivery* (chapters 11–12): testing, deploying and
  debugging.
- *Beyond a request* (chapters 13–15): events, schedules and queues, and
  changing a system that is already running.

== What this book is not

It is not the language reference. The online Bynk Book owns the exact
syntax, every diagnostic code and every option, and this book's footnotes
point to it whenever a precise rule matters.

It is not the argument for the language's design either. That is the subject
of _Architecture that compiles_, a companion book about why a service's
architecture should be something its compiler can see.

== How the examples are kept true

Bynk is young, and it changes from release to release. A book about it is
only useful if what it prints is what the language does, so this one is
built like a program.

Every listing is part of a project that is compiled in CI. A listing the
compiler should accept must check, format and build cleanly, and the
TypeScript it compiles to must pass `tsc --strict`. A listing the compiler
should refuse must be refused with the exact diagnostic the page prints.
Test runs are re-run and compared, HTTP transcripts are replayed against
`bynk dev`, deploy plans are regenerated with `bynk deploy --dry-run`, and
every excerpt of generated code is compared with what the compiler writes
now.

All of it is checked against one release: Bynk #book-meta.bynk-version. The
deploy chapter's account of Cloudflare's side was also checked once, by
hand, against a scratch account.

== Limits, and their issue numbers

A young language has gaps, and the book doesn't hide them. Where Bynk
#book-meta.bynk-version doesn't do something a chapter needs, the page says
so and gives the issue that tracks it, and the appendix lists them. When a
release closes one, the book moves to that release and the chapter changes.
Its first draft cited thirty such issues; this one cites one.

The shop itself is at `bynk-lang/shop`, with tests and end-to-end scenarios
of its own. Each chapter's version of it, exactly as printed, is in this
book's source.
