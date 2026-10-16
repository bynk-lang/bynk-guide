# Source map

Where each chapter's code lives, and what it teaches from. Snippet projects live
in `snippets/chapter-NN/` and are gated here. The last chapter's project should
match `bynk-lang/shop`; a script that diffs them is a follow-up.

| Ch | Snippet projects (planned) | Shop file | Book pages to link |
| -- | -- | -- | -- |
| 1 | `chapter-01/hello` (the `bynk new` scaffold), `greet`, `dollar`, `no-status` and `one-armed-if` (refusals), `conventional*`, `emitted/` (not gated), `dev-output.txt` (not gated); transcripts `greet-responses.txt`, `dollar-responses.txt` | | introduction/install; guides/projects-build-and-deployment/start-a-project, layout, run-locally, cloudflare-workers, why-compile-to-typescript |
| 2 | `chapter-02/shop` (written, gated), `minted` and `empty-sku` (refusals), `conventional*.ts` | `values.bynk`, `orders.bynk` (`OrderLine`) | guides/type-system, type-system/decode-json |
| 3 | `chapter-03/shop`, `no-embeds` and `question-in-handler` (refusals), `conventional.ts`, `orders.diff`, `emitted/send.ts`; transcripts `test-run.txt`, `responses.txt` | `orders.bynk` (`OrderError`, `total`, the `PUT` check) | guides/type-system/result-and-optionals, effects-and-capabilities/synchronous-and-asynchronous-sends |
| 4 | `chapter-04/shop`, `non-exhaustive` and `no-arrow` (refusals), `conventional.ts`, `conventional-wrangler.toml`, `orders.diff`, `emitted/wrangler.toml`; transcripts `test-run.txt`, `responses.txt` | `orders.bynk` (`Order`, `AlreadyDecided`, `GET /orders/:id`) | guides/agents-and-state, the-agent-model; reference/agents |
| 5 | `chapter-05/shop`, `kinds` (`Log`, `Cache`, `Kv`), `query-boundary` and `no-ttl` (refusals), `conventional.ts`, `orders.diff`; transcripts `test-run.txt`, `responses.txt` | `orders.bynk` (`Inventory`, `StockError`, `Hold`, stock routes), `values.bynk` (`orderRef`) | guides/agents-and-state; reference/agents (storage kinds), reference/types (Query), reference/bynk-capabilities (Kv) |
| 6 | `chapter-06/shop`, `self-reference` and `restates` (refusals), `conventional.ts`, `inventory.diff` (hunks 3–5), `history-failure.txt` (illustrative, not gated); transcripts `test-run.txt`, `responses.txt` | `orders.bynk` (`Status`, `Order`'s transitions, cancel route), `inventory.bynk` (invariant, `release`) | guides/agents-and-state/state-machine, understand-invariants; reference/agent-invariants; reference/testing (history properties) |
| 7 | `chapter-07/shop`, `admin-in-sum` and `visitor-first` (refusals), `conventional.ts`, `routes.diff` (hunks 9, 10, 12); transcripts `test-run.txt`, `responses.txt` with `responses.env` (dev tokens) | `orders.bynk` (actors, owner, stock routes) | guides/actors (public-and-authenticated, authorisation, multiple-callers); reference/actors; reference/testing (call-site `by`) |
| 8 | `chapter-08/*` | `inventory.bynk`, `payments.bynk`, `orders.bynk` | guides/program-structure/consume-services, actors/cross-context-callers |
| 9 | `chapter-09/*` | `payments.bynk` (`Processor`, fake rule) | guides/effects-and-capabilities, effects-and-capabilities/share-across-contexts; reference/bynk-capabilities |
| 10 | `chapter-10/*` | `gateway.bynk`, `gateway.binding.ts`, `payments.bynk` (`CardProcessor`, `Payment`, webhook), `tests/bindings/` | effects-and-capabilities/wrap-a-library; actors/verify-webhooks; reference/adapters |
| 11 | `chapter-11/*` | `tests/`, `e2e/scenarios.sh` | guides/testing; reference/testing (observation) |
| 12 | `chapter-12/*` | `deploy.yml` | guides/projects-build-and-deployment, why-compile-to-typescript (source maps) |
| 13 | `chapter-13/*` | `ledger.bynk` | guides/events |
| 14 | `chapter-14/*` | `inventory.bynk` (`at`, `sweeper`, `Catalogue`), `orders.bynk` (commit) | guides/entry-points, entry-points/cron |
| 15 | `chapter-15/*` | `bynk.schema.lock` | guides/projects-build-and-deployment/contract-skew |

## Follow-ups

- `scripts/check-final-matches-shop.sh`: diff the final chapter's project
  against `bynk-lang/shop` so the book can't drift from the example.
- `make-book-diffs.sh` prints the delta from one chapter's project to the next,
  which is a tutorial's shape. Use it from chapter 3 on: chapter 2's project is
  the first shop project, not a delta from `chapter-01/hello`.
