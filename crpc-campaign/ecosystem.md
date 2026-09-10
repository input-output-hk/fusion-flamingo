# u5c ecosystem map

## Servers implementing UTxO RPC

1. Dolos (TxPipe): the reference implementation, a lightweight Rust data node with first-class u5c alongside Blockfrost-compatible REST and MiniKupo.
   Blockfrost's new platform deploys it with REST only, gRPC off (see [blockfrost.md](blockfrost.md)).
2. cardano-node via cardano-rpc (ours), see [cardano-rpc-status.md](cardano-rpc-status.md).
3. Amaru (PRAGMA, Rust): u5c is listed as an external integration point in the proposal, liaison Santiago Carmuega; shipped status unconfirmed.
4. Dingo (Blink Labs, Go): they maintain the Go u5c SDK; whether the listener is built into Dingo or a sidecar is unverified.

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
