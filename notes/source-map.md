# Source map

Where each chapter's code lives, and what it teaches from. Snippet projects live
in `snippets/chapter-NN/` and are gated here. The last chapter's project should
match `bynk-lang/shop`; a script that diffs them is a follow-up.

| Ch | Snippet projects (planned) | Shop file | Book pages to link |
| -- | -- | -- | -- |
| 1 | `chapter-01/hello` (written, gated) | | tutorials 01, 02; guides/projects-build-and-deployment/start-a-project, layout |
| 2 | `chapter-02/*` | `orders.bynk` types | guides/type-system, type-system/decode-json |
| 3 | `chapter-03/*` | `orders.bynk` handlers | guides/type-system/result-and-optionals, effects-and-capabilities/synchronous-and-asynchronous-sends |
| 4 | `chapter-04/*` | `inventory.bynk` | guides/agents-and-state |
| 5 | `chapter-05/*` | | guides/agents-and-state |
| 6 | `chapter-06/*` | `orders.bynk` (Order), `inventory.bynk` (invariant) | guides/agents-and-state/state-machine, understand-invariants; reference/testing (history properties) |
| 7 | `chapter-07/*` | `orders.bynk` actors | guides/actors, actors/multiple-callers |
| 8 | `chapter-08/*` | `inventory.bynk`, `payments.bynk`, `orders.bynk` | guides/program-structure/consume-services, actors/cross-context-callers |
| 9 | `chapter-09/*` | `payments.bynk` | guides/effects-and-capabilities, effects-and-capabilities/wrap-a-library, share-across-contexts; actors/verify-webhooks; reference/adapters |
| 10 | `chapter-10/*` | `tests/`, `e2e/scenarios.sh` | guides/testing; reference/testing (observation) |
| 11 | `chapter-11/*` | `deploy.yml` | guides/projects-build-and-deployment, why-compile-to-typescript (source maps) |
| 12 | `chapter-12/*` | `ledger.bynk` | guides/events |
| 13 | `chapter-13/*` | | guides/entry-points |
| 14 | `chapter-14/*` | `bynk.schema.lock` | guides/projects-build-and-deployment/contract-skew |

## Follow-ups

- `scripts/check-final-matches-shop.sh`: diff the final chapter's project
  against `bynk-lang/shop` so the book can't drift from the example.
- `make-book-diffs.sh` prints the delta from one chapter's project to the next,
  which is a tutorial's shape. Use it from chapter 2 on.
