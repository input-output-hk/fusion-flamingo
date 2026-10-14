# u5c ecosystem map

## Ogmios and Kupo positioning context (added 2026-09-16)

Both are actively maintained and healthy, not stale.
Ogmios v7.0.0 (2026-06-20) targets cardano-node 11.0.1 and already ships preliminary Dijkstra-era and PlutusV4 support; the repo was pushed to on 2026-09-13.
Kupo v2.12.0 (2026-07-18) targets the same node version; pushed 2026-09-10.
Never argue "Ogmios lags hard forks" empirically; the defensible hard-fork argument is structural (same repo, compile-time era coverage), see [announcement.md](announcement.md).

Matthias Benkort (KtorZ) maintains both and is currently the Cardano Foundation's Technical Director of Open-Source Development; no evidence of departure or public friction with CF/IOG.
His GitHub Sponsors funding looks thin (6 of a 42-sponsor goal), but CF employment status makes "unmaintained community tooling" framing both wrong and insulting.
No public statement from him about cardano-rpc or u5c was found (checked 2026-09-16); the narrative is unset.

Developer Ecosystem Survey 2025 (published 2025-12-11, n=109): self-hosted usage Blockfrost 16%, Ogmios 12.5%, db-sync 10.9%, Kupo 8.9%; hosted usage Blockfrost 24.6%, Demeter 11.7%.

Landmines for public communication:

1. Public issues [cardano-api#1302](https://github.com/IntersectMBO/cardano-api/issues/1302) ("stand in for Ogmios", full parity table) and [cardano-api#1229](https://github.com/IntersectMBO/cardano-api/issues/1229) ("Replace Ogmios as Kupo's chain data source") already use replacement language and will be quoted by critics; any announcement must own coexistence explicitly rather than pretend the goal is softer than the issues say.
2. IOG halted Project Acropolis in April 2026 and returned 4.1M ADA to the treasury, which fed an "IOG abandoned Cardano for Midnight" narrative that Hoskinson publicly rebutted; a tone-deaf "IOG replaces community tooling" story would reopen it.
3. u5c origin is TxPipe's Catalyst Fund 11 project "gRPC ❤️ Cardano" (₳177,082, completed 2024), which is the citable proof that the spec is community-born, not an IOG invention.
4. utxorpc.org/servers lists Dolos, Blink Labs' Node API and Demeter, but NOT cardano-rpc; getting listed is a cheap credibility action before or with the announcement.

## Servers implementing UTxO RPC

1. Dolos (TxPipe): the reference implementation, a lightweight Rust data node with first-class u5c alongside Blockfrost-compatible REST and MiniKupo.
   Blockfrost's new platform deploys it with REST only, gRPC off (see [blockfrost.md](blockfrost.md)).
2. cardano-node via cardano-rpc (ours), see [cardano-rpc-status.md](cardano-rpc-status.md).
3. Amaru (PRAGMA, Rust): u5c is listed as an external integration point in the proposal, liaison Santiago Carmuega; shipped status unconfirmed.
4. Dingo (Blink Labs, Go node): serves u5c natively via a built-in API plugin (`DINGO_PLUGINS_API_UTXORPC_CONFIG_PORT`, default 9090), alongside Blockfrost-compatible REST and Mesh APIs; confirmed 2026-09-23 by wolf31o2's forum comment and Dingo's README.
   Blink Labs' separate "Node API" (`blinklabs-io/cardano-node-api`) is a multi-protocol Go sidecar over a local Haskell node; its u5c role is what cardano-rpc absorbs (wolf31o2: "you're making Node API obsolete").
   Announcement lesson: credit Dingo, not Node API, as Blink Labs' u5c server; the forum post got this wrong.

Client side: Blaze, Lucid Evolution/Evolution SDK and MeshJS have u5c providers (see [sdks.md](sdks.md)); cardano-js-sdk, which Lace builds on, has none.

## Amaru and Pi Lanningham

Pi Lanningham (CTO of Sundae Labs, GitHub Quantumplation) is a core Amaru contributor and owns its "Mempool and Block Forge" bounded context per the PRAGMA budget proposal.
That maps directly onto cardano-rpc's unimplemented mempool methods.
Opportunity: align both nodes on the same u5c mempool semantics; Santiago Carmuega is the shared spec liaison.

## Demeter.run

TxPipe's hosted Cardano infrastructure platform: managed node access, Ogmios, Kupo, db-sync, and hosted u5c endpoints served by Dolos.
It runs Haskell cardano-nodes for the protocol-level services and Dolos for data serving (division unverified against current docs).
They already operate a cardano-node fleet, so offering u5c straight from the node is a config flag away once cardano-rpc ships in a release.
Most dApp developers who consume u5c today do it through Demeter endpoints, so conformance against Dolos is what they will notice (the `utxorpc-compare` skill exists for this).

## cardano-sieve

A brand-new Haskell pattern-filtered indexer by Jordan Millar, self-described as a Kupo replacement: follows a local node over N2C ChainSync, matches UTxOs against selectors (address, credential, policy or asset), stores in SQLite, serves Kupo-shaped REST.
Two commits old as of 2026-09-03; no releases.
No connection to Lace or Blockfrost, and no u5c support yet.

It complements cardano-rpc: sieve can serve the u5c methods that need a secondary index (broad `SearchUtxos` predicates, `ReadData`, `ReadTx`), which the node cannot serve without becoming an indexer.
Filed as <https://github.com/IntersectMBO/cardano-sieve/issues/4>.
Sieve is also a dogfooding candidate: it could sync through cardano-rpc's `FollowTip` and `FetchBlock` instead of hand-rolled N2C.
