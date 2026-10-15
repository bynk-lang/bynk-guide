#import "../template.typ": code-listing, lead-in

= A Worker in Bynk <a-worker-in-bynk>

#lead-in[
  This chapter is a stub. It exists to exercise the build and the listing
  gates; the prose follows the outline.
]

The smallest Bynk service is one context with one HTTP service.

#code-listing(
  [A Worker that answers],
  read("../snippets/chapter-01/hello/src/hello/web.bynk"),
  lang: "bynk",
)
