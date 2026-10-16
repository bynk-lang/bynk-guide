#import "../template.typ": code-listing, compiler-message, lead-in
#import "../metadata.typ": book-meta

#let source-lines(path, start, end) = {
  read(path).split("\n").slice(start, end).join("\n")
}

#let v = book-meta.bynk-version
#let archive = "bynk-v" + v + "-x86_64-unknown-linux-gnu"

= A Worker in Bynk <a-worker-in-bynk>

Every Worker starts the same way. You write a `fetch` handler that looks at
the method and the path, decides which bit of code should answer, and builds
a `Response`. You write a `wrangler.toml` that names the Worker and points at
the handler. Then `wrangler dev`, a `curl`, and you are away.

This chapter builds that Worker in Bynk. It installs the toolchain, starts a
project, runs it, adds a route that takes a parameter, and then looks at the
TypeScript the compiler wrote for you. Nothing here is the shop yet. The point
is to see the loop (write, check, run) and to know what is underneath it
before the book starts leaning on it.

== The Worker you would write <ix-guide-01-the-worker-you-would-write>

#lead-in[
Here is the Worker this chapter ends up with, written by hand. It answers
`GET /` and `GET /hello/:name`, and nothing else:
]

#code-listing(
  [A greeting Worker, by hand],
  read("../snippets/chapter-01/conventional.ts"),
  lang: "typescript",
)

#lead-in[
And its configuration:
]

#code-listing(
  [`wrangler.toml`, by hand],
  read("../snippets/chapter-01/conventional-wrangler.toml"),
  lang: "toml",
)

This is fine code, and you could keep writing it. The router is a chain of
`if`s and a regular expression. Decoding the path parameter is your job. So
is everything the chain leaves out: a `HEAD` request, an `OPTIONS` request,
the difference between "no such route" (`404`) and "no such method on this
route" (`405`), and the headers a response should carry. Each is a few lines,
and each is a few lines you have to remember.

Keep this listing in mind. By the end of the chapter you will have the same
Worker, with all of those things, and you will not have written any of them.

== Installing the toolchain <ix-guide-01-installing-the-toolchain>

Bynk is one release, three programs. `bynkc` is the compiler: it checks,
formats, compiles and tests. `bynk` is the driver, which runs your project
locally and deploys it. `bynkc-lsp` is the language server for your editor.

#lead-in[
This book was checked against Bynk #v. Each release publishes a prebuilt
archive per platform, with a `SHA256SUMS` file to verify it against. On Linux
or macOS, download the archive for your machine (this is the x86_64 Linux
one), check it, and put the three programs on your `PATH`:
]

#code-listing(
  [Installing Bynk #v],
  (
    "base=https://github.com/bynk-lang/bynk/releases/download/v" + v + "\n"
      + "curl -LO $base/" + archive + ".tar.gz\n"
      + "curl -LO $base/SHA256SUMS\n"
      + "sha256sum -c --ignore-missing SHA256SUMS\n"
      + "tar xzf " + archive + ".tar.gz\n"
      + "cp " + archive + "/bynk* ~/.local/bin/"
  ),
  lang: "sh",
)

Pin the version. Bynk is not yet at 1.0, the language still changes between
releases, and every listing in this book is checked against #v and no
other.#footnote[
  The Bynk Book's “Install” page covers building from source with Cargo, and
  the other platforms.
]

#lead-in[
Then ask the driver what your machine can do:
]

#code-listing(
  [Checking the environment],
  "bynk doctor",
  lang: "sh",
)

`bynk doctor` groups its checks by what you are trying to do: compile, test,
run and deploy, and editor support. Compiling needs nothing else; the
compiler is built in. Testing needs Node 22 or later and `tsc`. Running and
deploying need `wrangler`, which `bynk` fetches through `npx` if you haven't
installed it. Anything missing comes with the command that fixes it.

== A new project <ix-guide-01-a-new-project>

#lead-in[
Create a project:
]

#code-listing(
  [Starting a project],
  "bynk new hello\ncd hello",
  lang: "sh",
)

`bynk new` writes four files and runs nothing.

#lead-in[
`bynk.toml` marks the project's root. It begins:
]

#code-listing(
  [`bynk.toml`, as `bynk new` writes it],
  source-lines("../snippets/chapter-01/hello/bynk.toml", 0, 4),
  lang: "toml",
)

The rest of the file is a commented `[paths]` section naming the trees to
compile, `src` and `tests`, which are the defaults. `.gitignore` keeps out
`.bynk/`, where the driver builds, and `.gitattributes` keeps `.bynk` files'
line endings as LF on every platform. And `src/hello.bynk` is the service.

#lead-in[
This is the whole of it:
]

#code-listing(
  [`src/hello.bynk`, as `bynk new` writes it],
  read("../snippets/chapter-01/hello/src/hello.bynk"),
  lang: "bynk",
)

A source file's path follows its name. `context hello` lives in
`src/hello.bynk`; a context called `shop.orders` would live in
`src/shop/orders.bynk`, and the compiler refuses a file whose path and name
disagree. That is the only layout rule there is, and from chapter 2 the shop
follows it.

== Reading the first file <ix-guide-01-reading-the-first-file>

Most of this file will take a chapter of its own to explain properly. Here is
enough to read it now.

`context hello` declares a _context_: a deployable unit with its own
services and its own state. On Cloudflare a context becomes one Worker. The
shop in this book has four of them.

`service api from http` is a group of handlers that answer HTTP. `on
GET("/")` is one route, and `()` is its parameter list, empty here. After the
arrow is what the handler returns.

`Effect[HttpResult[String]]` is that return type, read from the inside out.
`String` is the body. `HttpResult` is a response: a status with a body of that
type, so `Ok("…")` is a `200`. `Effect` says the handler may do things on the
way, such as log a line or call another service. Chapter 3 is about both.

`by v: Visitor` says who may call the route. `Visitor` is anyone at all.
Every HTTP route has to say: leave the clause out and the compiler refuses
the handler (`bynk.actor.missing_by_on_http`), because there is no safe
default. Chapter 7 is about callers.

`consumes bynk { Logger }` and `given Logger` say the handler uses the
first-party `Logger`. A handler can't reach anything it hasn't asked for,
which is how a test can swap it out. Chapter 9 is about capabilities.

`let _ <- Logger.info(…)` runs the effect and waits for it. The `_` throws
away its result, which is nothing. Chapter 3 explains the arrow.

== Running it <ix-guide-01-running-it>

#lead-in[
Run `bynk dev` from anywhere in the project, and call it from another
terminal. Abridged, it prints:
]

#code-listing(
  [`bynk dev`, abridged],
  read("../snippets/chapter-01/dev-output.txt"),
  lang: "text",
)

`bynk dev` compiled the project, wrote a Worker into `.bynk/dev/`, and
started `wrangler dev` on it, locally, with no Cloudflare account involved.
`hello from hello` is the `Logger.info` line, arriving in the terminal the
way `console.log` would. Leave it running: when you save a `.bynk` file it
rebuilds and the Worker reloads. A change that doesn't compile prints the
errors and keeps the last good build running.

There is no separate type-check step in this loop, because the build is the
type-check. When you want one without running anything, in CI or before a
commit, `bynkc check .` checks the whole project and prints nothing if it is
sound.

== A route that takes a parameter <ix-guide-01-a-route-that-takes-a-parameter>

#lead-in[
Add the second route from the hand-written Worker. Inside the service, after
the first handler:
]

#code-listing(
  [Greeting by name],
  source-lines("../snippets/chapter-01/greet/src/hello.bynk", 10, 16),
  lang: "bynk",
)

`:name` in the pattern binds the parameter of the same name. `\(name)` puts
its value into the string. `do if` runs the block only when the condition
holds. The `do` matters: a plain `if` is an expression, with a value, and
`do` makes it a statement, for its effect alone.

#lead-in[
Save, and `bynk dev` picks it up:
]

#code-listing(
  [The routes, from outside],
  read("../snippets/chapter-01/greet-responses.txt"),
  lang: "text",
)

Each response shows the status, then the body. Two things in it may surprise
you. The bodies are in quotes, because a `String` body is sent as JSON, with
`Content-Type: application/json`: that is why the hand-written Worker used
`Response.json`. And `Ada%20Lovelace` arrived as `Ada Lovelace`: the
parameter is decoded before the handler sees it.

== Two habits from TypeScript <ix-guide-01-two-habits-from-typescript>

Your fingers know TypeScript, and two of their habits go wrong in Bynk.

#lead-in[
The first is string interpolation. Write the greeting the TypeScript way:
]

#code-listing(
  [A template literal, by habit],
  read("../snippets/chapter-01/dollar/src/hello.bynk"),
  lang: "bynk",
)

#lead-in[
It compiles, and it answers:
]

#code-listing(
  [What `${name}` means in Bynk],
  read("../snippets/chapter-01/dollar-responses.txt"),
  lang: "text",
)

In Bynk, `${` has no special meaning, so `"${name}"` is just text. The
compiler can't warn you, because it is a perfectly good string. Interpolation
is `\(name)`.

#lead-in[
The second is the one-armed `if`. Write the logging line without `do`:
]

#code-listing(
  [A one-armed `if`, by habit],
  source-lines("../snippets/chapter-01/one-armed-if/src/hello.bynk", 5, 11),
  lang: "bynk",
)

#compiler-message[
[bynk.parse.expected_token] Error: expected `}` to close the block, found
`Ok`
]

The error points at the line after the `if`, and it doesn't mention `do`.
Without `do`, the `if` is read as the block's final expression, its value,
and nothing may follow it. When you see this message on the line after an
`if`, add `do`.

== The status is part of the type <ix-guide-01-the-status-is-part-of-the-type>

#lead-in[
One more mistake, because the refusal teaches something. Return the
greeting on its own, the way a TypeScript function returns a string:
]

#code-listing(
  [A body without a status],
  read("../snippets/chapter-01/no-status/src/hello.bynk"),
  lang: "bynk",
)

#compiler-message[
[bynk.types.return_mismatch] Error: handler body has type `String`, but the
declared return type is `Effect[HttpResult[String]]`
]

A handler doesn't return a body and leave the status to a default. It returns
an `HttpResult`, and the status is which one: `Ok` for `200`, `Created` for
`201`, `NotFound`, `Conflict` and the rest. So the statuses a route can answer
with are written in its code, where the compiler and the next reader can see
them. Chapter 3 builds on this, when the shop's routes start to fail.

== What the compiler wrote <ix-guide-01-what-the-compiler-wrote>

Bynk has no runtime of its own. It compiles to TypeScript, and the
TypeScript runs on the Workers runtime you already know. You can read
everything it writes, and it is worth doing once.

`bynkc compile` has two targets. The default, `bundle`, writes one flat tree
of TypeScript in which contexts call each other directly, in process.
It suits a program you will run yourself, or embed. The `workers` target writes one Cloudflare Worker per
context, with Service Bindings between them, and that is what this book
builds and deploys. `bynk dev` and `bynk deploy` choose `workers` for you.

#lead-in[
Compile with `bynkc compile . --output out --target workers` and look at what
it wrote (abridged):
]

#code-listing(
  [The `workers` target],
  read("../snippets/chapter-01/emitted/tree.txt"),
  lang: "text",
)

#lead-in[
The `wrangler.toml` is generated too:
]

#code-listing(
  [The generated `wrangler.toml`],
  read("../snippets/chapter-01/emitted/wrangler.toml"),
  lang: "toml",
)

You don't write this file, and you shouldn't edit it: the next build
replaces it. Everything it says comes from the program. When later chapters
add a Durable Object or a Service Binding, the binding appears here because
the code needs it, under a name the code and the configuration agree on.

#lead-in[
`handlers.ts` is your code, translated. The greeting line becomes:
]

#code-listing(
  [From `handlers.ts`],
  read("../snippets/chapter-01/emitted/greeting.ts"),
  lang: "typescript",
)

There is the template literal that `\(name)` stood for.

`index.ts` is the `fetch` handler you wrote by hand at the start of the
chapter, with the parts you left out put back. It answers `HEAD` as well as
`GET`. It answers `OPTIONS` with `204` and an `Allow` header. A known path
with the wrong method is a `405` with `Allow`, and an unknown path is a
`404`. Every response carries `x-content-type-options: nosniff`, and a `GET`
response carries a weak `ETag`, so a client that sends it back in
`If-None-Match` gets `304 Not Modified`. A handler that throws is logged with
the route that failed and answered with a `500`, without the error's
details. None of this was in `src/hello.bynk`, and none of it will need to be.

== What it costs <ix-guide-01-what-it-costs>

You have a new toolchain to install and pin, and a language that is not yet
at 1.0. Releases come often and can change what compiles: this book holds
itself to one release, and so should your project.

You give up some control of the Worker. The router, the headers and the
`wrangler.toml` are the compiler's, not yours, so a behaviour you want that
it doesn't offer has to come through the language, not a quick edit to the
output. The output also brings a shared runtime of a couple of thousand lines
with it, the same for every project.

And you are reading a new syntax. Most of what looked strange in
`src/hello.bynk` is the language saying out loud what a TypeScript Worker
leaves implicit: who may call, what the handler uses, how it can answer. The
rest of the book is about why that is worth it.

== Where this leaves the Worker <ix-guide-01-where-this-leaves-the-worker>

The greeting Worker takes a name as a `String`, and any string will do: a
mile long, or nothing like a name at all. For a greeting that doesn't
matter. For an order, it does. The next chapter starts the shop, and gives
the values it accepts types that refuse anything that isn't an order.
