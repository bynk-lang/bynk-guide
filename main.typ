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

#part-page(2, [State])

#include "chapters/04-an-agent-is-a-durable-object.typ"
#include "chapters/05-other-kinds-of-storage.typ"
#include "chapters/06-state-with-a-lifecycle.typ"

#part-page(3, [Who is calling, and who is it for])

#include "chapters/07-actors.typ"
#include "chapters/08-contexts-and-service-bindings.typ"
#include "chapters/09-capabilities-and-providers.typ"
#include "chapters/10-the-host-boundary.typ"

#part-page(4, [Confidence and delivery])

#include "chapters/11-testing-at-three-tiers.typ"
#include "chapters/12-run-it-ship-it-debug-it.typ"

#part-page(5, [Beyond a request])

#include "chapters/13-events.typ"
#include "chapters/14-time-and-queues.typ"
#include "chapters/15-changing-a-deployed-system.typ"

#set heading(numbering: none)
#include "chapters/epilogue.typ"

#recto-break()
#include "backmatter/issues.typ"

#recto-break()
#include "backmatter/glossary.typ"
