# Building with Bynk

The source of a guide to the [Bynk](https://github.com/bynk-lang/bynk) language
for TypeScript and Cloudflare developers: a tutorial that builds one
multi-context service ([`bynk-lang/shop`](https://github.com/bynk-lang/shop)) a
chapter at a time, typeset for print.

It sits between two other works, and is neither:

- the online [Bynk Book](https://bynk-lang.org/book/) documents the language;
  this teaches it by building, and links there for exact syntax;
- [*Architecture that compiles*](https://github.com/bynk-lang/architecture-that-compiles)
  argues for the language's design; this assumes the reader is willing to try it.

The title is provisional. **The book is a complete review draft**: a
preface, fifteen chapters in five parts, an epilogue, and two appendices (the
Bynk issues the chapters cite, and a glossary). Reviewers should start with
[`REVIEWING.md`](REVIEWING.md). Read [`notes/brief.md`](notes/brief.md) for the
reader, scope and principles, [`notes/outline.md`](notes/outline.md) for the
chapters, and [`notes/source-map.md`](notes/source-map.md) for where each
chapter's code lives.

## Source structure

- `main.typ` assembles the manuscript; `metadata.typ` holds its metadata.
- `template.typ` owns page design and the semantic components.
- `frontmatter/`, `chapters/`, `backmatter/` hold the text.
- `snippets/` holds the compiler-tested Bynk projects the chapters typeset.
- `notes/` is editorial planning, not manuscript prose.
- `fonts/` and `syntaxes/` are the vendored Source faces and Bynk highlighting.
- `scripts/` holds the build wrapper and the snippet gates.

The typesetting is the same as *Architecture that compiles*, copied from it, so
the two books look alike.

## Build

```sh
./scripts/build-book.sh          # writes output/pdf/bynk-guide.pdf
./scripts/build-book.sh watch
```

The build is pinned to Typst 0.15.0, which the script downloads and verifies if
it is not on `PATH`. CI builds the PDF on every push and pull request and uploads
it as the `bynk-guide` artifact; `./scripts/fetch-book-pdf.sh` downloads the
newest. A `v*` tag publishes it as a GitHub release.

## Keeping the listings true

Every listing is a project under `snippets/` held by three gates, and what
the chapters quote from running, compiling or deploying it by four more:

```sh
./scripts/check-book-snippets.sh   # bynkc check: clean, or the exact refusal quoted
./scripts/check-book-format.sh     # bynkc fmt --check
./scripts/check-book-emit.sh       # build, then tsc --strict on the emitted TypeScript
./scripts/check-book-tests.sh      # bynkc test: every case passes, quoted runs match
./scripts/check-book-responses.sh  # bynk dev: quoted HTTP responses match
./scripts/check-book-emitted.sh    # bynkc compile: quoted generated files match
./scripts/check-book-plans.sh      # bynk deploy --dry-run: quoted plans and refusals match
./scripts/check-book-issues.sh     # the issues appendix lists every issue a chapter cites
```

They use whichever `bynkc` (and `bynk`) is on `PATH`; CI installs the pinned release with
[`setup-bynk`](https://github.com/bynk-lang/setup-bynk). Non-clean expectations
are in `snippets/EXPECTATIONS.tsv`, and each quoted transcript is listed with
its project in `snippets/TRANSCRIPTS.tsv`; known format and build failures are
ratchets in `snippets/FORMAT-BASELINE` and `snippets/EMIT-BASELINE` that can
only shrink. The emit gate also checks that each committed `bynk.schema.lock`
is what compiling writes.
Chapters that print a chapter-to-chapter diff generate it with
`./scripts/make-book-diffs.sh`.

The book pins **Bynk 0.403.3** <!-- bynk-pin --> ([`BYNK_VERSION`](BYNK_VERSION), and
`bynk-version` in `metadata.typ`; CI fails if they differ). It is enrolled in
the org [canary](https://github.com/bynk-lang/.github/blob/main/canary/README.md)
as a `book`: on each new Bynk release the gates re-run. A break opens a
`canary` issue here that a deliberate revision, and a bump of the pin, closes.
A pass opens a pull request moving the pin, which a reviewer merges once the
manuscript still describes that release.

## Rights

See [`RIGHTS.md`](RIGHTS.md). The prose is all rights reserved; the snippets and
scripts are MIT or Apache-2.0.
