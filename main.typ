#import "metadata.typ": book-meta
#import "template.typ": manuscript, part-page, recto-break, rights-page, title-page

#show: manuscript.with(meta: book-meta)

#title-page(book-meta)
#rights-page(book-meta)

#set page(numbering: "i")

#include "frontmatter/contents.typ"

#recto-break()
#include "frontmatter/preface.typ"

#recto-break()
#counter(page).update(1)
#set page(numbering: "1")

#part-page(1, [From a Worker to a service])

#counter(heading).update(0)
#set heading(numbering: "1")

#include "chapters/01-a-worker-in-bynk.typ"
#include "chapters/02-types-you-can-trust.typ"
#include "chapters/03-failure-in-the-type.typ"
