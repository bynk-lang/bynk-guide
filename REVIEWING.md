# Reviewing *Building with Bynk*

Thank you for reading. This page is for reviewers. It says what the draft is,
how to read it, what kind of feedback helps most, and what is already known to
be unfinished, so you can spend your time on what only a reader can tell us.

## What you are reviewing

A complete draft of a print-first guide to the Bynk language for TypeScript and
Cloudflare developers. It has a preface, fifteen chapters in five parts, an
epilogue, and two appendices (the Bynk issues the chapters cite, and a
glossary). It runs to about 210 pages.

The book teaches by building one service, a shop, from a single route
(chapter 1) to four contexts with events, a schedule and a queue (chapter 15).
Each chapter shows what you would write by hand in TypeScript, builds the same
thing in Bynk, and ends with *What it costs*. The reader, the scope and the
principles are in [`notes/brief.md`](notes/brief.md).

The book is pinned to **Bynk 0.403.3** and describes exactly that release.

## Getting the PDF

Download the newest build from CI:

```sh
./scripts/fetch-book-pdf.sh
```

Or build it yourself (the script fetches the pinned Typst if needed):

```sh
./scripts/build-book.sh          # writes output/pdf/bynk-guide.pdf
```

You don't need Bynk installed to read or review. You do if you want to run the
examples: see chapter 1, *Installing the toolchain*, and install 0.403.3
exactly.

## What feedback helps most

In rough order of value:

1. **Did it teach you?** Where did you get lost, skim, or need to look
   something up? Where did a chapter assume something it hadn't shown?
2. **Are the comparisons fair?** Each chapter opens with the hand-written
   TypeScript a reader would otherwise use. If that code is a straw man, or not
   what an experienced Workers developer would write, say so.
3. **Are the costs honest?** Each *What it costs* section should name the real
   price of the Bynk construct. Tell us where it is too kind, or too harsh.
4. **Is it accurate about Cloudflare?** The book doesn't teach the platform,
   but it makes claims about it: Durable Objects, Service Bindings, Wrangler,
   `workers.dev`, queues, cron. Corrections are very welcome.
5. **Pace and length.** Which chapters are too long, too short, or in the wrong
   order? Chapters 8–15 carry the most caveats; is that density tolerable?
6. **Prose.** Unclear sentences, jargon used before it is defined, anything that
   reads as marketing.

Less useful at this stage: line-level typography, and the exact Bynk syntax.
Both are checked by tooling (below), and syntax is the online Bynk Book's
responsibility.

## How the claims are checked

Every listing, diagnostic, test run, HTTP transcript, deploy plan and excerpt of
generated code in the book is produced by running the real toolchain, and CI
fails if any of them stops matching. The gates are described in
[`README.md`](README.md#keeping-the-listings-true). In short, if you doubt a
listing:

- the project it comes from is under `snippets/chapter-NN/`;
  [`notes/source-map.md`](notes/source-map.md) says which file;
- [`snippets/TRANSCRIPTS.tsv`](snippets/TRANSCRIPTS.tsv) says how each quoted
  run, response, plan or excerpt is regenerated;
- [`snippets/EXPECTATIONS.tsv`](snippets/EXPECTATIONS.tsv) lists every listing
  the compiler is meant to refuse, with the diagnostic it must give.

Two things are **not** re-checked on every build:

- **Cloudflare's side of a deploy.** Chapter 12's account of a real deploy
  (secrets, staging, `workers.dev`, logs) was checked once, by hand, against a
  scratch account on 17 October 2026, with Bynk 0.330.4. What changed by
  0.371.3 (a new Worker's secrets, the staging plan, signed internal calls,
  the logged stack) is described from Bynk's changelog and hasn't been
  re-checked live. 0.377.2 changed nothing in the deploy path that its
  changelog lists; 0.403.3 was gated but its deploy path was not reviewed.
- **The states in the issues appendix.** They are a dated snapshot. The list of
  issues itself is checked against the chapters.

## Known, and not yet done

Please don't spend time reporting these; they are tracked.

- **The pin moved once already.** The first draft was checked against
  0.330.4 and worked around thirty Bynk issues; all were fixed by 0.371.3, and
  this draft removes the workarounds. If a passage still reads like a
  workaround, that is worth reporting.
- **A deliberate bug.** From chapter 8 to chapter 14 the shop charges the card
  the unit price, not the order's total. Chapter 15 finds and fixes it as its
  example of changing a running system. This is intentional.
- **Chapter 15's contract-skew example** uses a `bynk.deploy.lock` written to
  record chapter 14's shop as live, rather than one from a real deploy. The
  chapter says so.
- **No index.** The section labels are in place for one; it hasn't been built.
- **Few figures.** Apart from three tables, the book has no diagrams. If a
  chapter needs one (the contexts and their bindings in chapter 8, for
  instance), say which.
- **The title is provisional.**
- **One gate is occasionally flaky.** The HTTP transcript gate, which runs
  `bynk dev` for each project, has failed once without naming a transcript and
  passed on re-run.

## Out of scope by design

WebSockets, `Oidc` actors, localisation, static assets, the `bundle` target and
the editor tooling are mentioned and left to the online Bynk Book (the epilogue
lists them). The argument for Bynk's design is left to *Architecture that
compiles*. If you think one of these belongs in this book, that is useful
feedback; say why.

## Sending feedback

Open an issue in [`bynk-lang/bynk-guide`](https://github.com/bynk-lang/bynk-guide)
for anything specific: one issue per point, naming the chapter and section. For
general impressions, or an annotated PDF, send it to the author directly.
