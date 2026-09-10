# Lace

Indirect target.
FYI message drafted in [messages.md](messages.md); the real lever is Blockfrost, see [blockfrost.md](blockfrost.md).

## How Lace gets chain data

Lace 2.0 (the April 2026 rewrite) talks to Blockfrost's REST API through in-house providers.
The old self-hosted cardano-services backend (db-sync plus Ogmios) is gone; no Ogmios or cardano-services references remain in the repo.
It still uses cardano-js-sdk for wallet logic (keys, tx construction, domain types), but all chain data flows through Blockfrost.

Production traffic goes through an IOG reverse proxy at `blockfrost.lw.iog.io`, which injects the API key server-side.
Until a security-audit finding (re-audit 2026-02-27), the extension and mobile app shipped a shared Blockfrost key in the client bundle; the proxy move was the fix (`docs/security/nwl-audit-response.md` in the Lace repo).
What sits behind the proxy is not public; the likely reading is the hosted blockfrost.io service with an enterprise key, matching how IOG proxies Maestro and mempool.space.

## Why Lace cannot drop Blockfrost

Most of what Lace shows users is indexer data that no node interface can serve: address transaction history, rewards and withdrawals history, stake pool metadata, asset metadata, handles, governance history.
cardano-rpc covers roughly a fifth of Lace's fifteen providers.
Replacing Blockfrost would mean rebuilding it: nodes plus a chain indexer plus metadata aggregation plus an API layer.
cardano-sieve narrows the gap for UTxO and datum indexing but covers none of the rewards, pools or metadata surface (see [ecosystem.md](ecosystem.md)).

## Honest assessment of the pitch

The only user-facing benefit is submit-and-confirm UX, and it depends on `WaitForTx` and `WatchMempool`, which do not exist yet (see [cardano-rpc-status.md](cardano-rpc-status.md)).
The other arguments (hard-fork readiness, vendor independence, protocol standardisation) benefit IOG as an organisation, not the Lace team, while the costs (running a node fleet, a second provider path) land on the Lace team's budget.
Lace deliberately bought its way out of running infrastructure.

Conclusion: send a short FYI to the Lace lead, and aim the strategic conversation at whoever owns IOG wallet infrastructure and the Blockfrost contract.
Sequencing: Blockfrost first, SDKs second (see [sdks.md](sdks.md)), Lace last, once mempool support has shipped and someone else has proven it in production.
