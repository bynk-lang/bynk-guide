#import "../metadata.typ": book-meta

= Preface <preface>

This is a working draft. It exists so that the build, the listing gates and the
canary have something real to check while the book is planned; the chapters are
written after the outline in `notes/outline.md` is agreed.

== What this book is for

The reader is a TypeScript or Cloudflare developer: someone who has written a
Worker, knows what a Durable Object is for, and has used `wrangler`. No prior
knowledge of Bynk is assumed, and none of the platform is explained from
scratch. Each chapter maps one Bynk construct to the thing the reader would
otherwise write by hand, and builds one small service a step further.

The book teaches the language by building a single shop across its chapters.
It is not the language reference, which stays in the online Bynk Book, and it
is not the argument for the language's design, which is the subject of
_Architecture that compiles_.

Every example was checked against Bynk #book-meta.bynk-version.
