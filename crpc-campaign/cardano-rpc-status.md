# cardano-rpc: implemented surface and gaps

Snapshot of master as of 2026-09-03; release and method status re-verified 2026-09-16 (the bugs section was not re-checked and is still the 2026-09-03 state).
Source: cardano-api repo, `cardano-rpc/` (Server.hs, handlers, proto files).

## Release status

Corrected 2026-09-16: cardano-rpc HAS shipped.
The first experimental cut went out in cardano-node 10.7.0 (2026-03-25), and cardano-node 11.1.1 (2026-09-08) ships cardano-rpc 11.2.0.0 with the current u5c method set (release notes highlight ReadTip, FollowTip, ReadGenesis, SearchUtxos, EvalTx, and FetchBlock returning full transactions, plus a "number of breaking changes" warning).
cardano-rpc 11.3.0.0 (cut 2026-09-04, not yet in any node release) adds TCP and TLS listeners via new node CLI flags (`--grpc-listen-port`, `--grpc-tls-certificate`) and abuse hardening (HTTP/2 concurrency bounds, eval size and redeemer caps, 20000-key UTxO read cap, 500-ref block fetch cap).
ReadEraSummary, gRPC server reflection (v1 and v1alpha, so grpcurl/grpcui work without proto files) and the Rust and Python quickstarts under `cardano-rpc/quickstart/` landed on master AFTER the 11.3.0.0 cut and shipped in cardano-rpc 11.4.0.0 (on CHaP by 2026-09-16; cardano-node master pins ^>=11.4 since commit e95d55ed94, still in no node release).
All CLI flags are marked EXPERIMENTAL.
Transport: unix socket (default), h2c, or TLS, one listener at a time, enabled with `EnableRpc: true`.
Node connection is mixed mid-migration (ADR-019): query/submit methods use N2C IPC, sync/genesis/era-history methods use in-process node kernel access.
Never claim "in-process, no IPC" publicly; the honest claim is "compiled into the cardano-node binary, same repo, same release train".

## Method status

QueryService: `ReadParams` (Conway+ only), `ReadUtxos`, `SearchUtxos` (exact-address predicates only), `ReadGenesis`, `ReadEraSummary` implemented.
`ReadData`, `ReadTx`, `ReadState` unimplemented.

SubmitService: `SubmitTx`, `EvalTx` implemented.
`WaitForTx`, `ReadMempool`, `WatchMempool` unimplemented on master.
`WaitForTx` is implemented on the unmerged node-kernel-access branch (draft PR [cardano-api#1222](https://github.com/IntersectMBO/cardano-api/pull/1222), commit dated 2026-09-07), with the mempool methods phased behind it per `plan-mempool-phases.md` on that branch.

SyncService: `ReadTip`, `FollowTip` (streaming), `FetchBlock` (max 500 refs) implemented.
`DumpHistory` unimplemented.

WatchService: not even vendored into the proto tree.

Field masks are ignored everywhere (TODOs in the handlers).

## Gaps ranked by adoption value

1. `WaitForTx`: blocks MeshJS (`onTxConfirmed`) and Evolution SDK (`awaitTx`), see [sdks.md](sdks.md); also the core of the wallet confirmation UX pitch in [lace.md](lace.md).
2. `ReadState`: pool distribution, accounts, governance; needed for Blockfrost query parity, see [blockfrost.md](blockfrost.md); the BlockQuery constructors already exist in consensus.
3. `ReadMempool` and `WatchMempool`: capability nobody else offers without polling; overlaps with Amaru's mempool work, see [ecosystem.md](ecosystem.md).
4. `DumpHistory`: bulk historical sync; the node has the full chain in the ImmutableDB.
5. Broad `SearchUtxos` predicates (credential, asset): a design decision, not just missing code; belongs in an indexer, see [ecosystem.md](ecosystem.md) on sieve, or behind an opt-in flag for private nodes.

## Bugs and rough edges found during research

1. `GetEra` (custom Node service) always returns Conway; it never queries the node.
2. The Conway-minimum gate in `ReadParams` is a raw Haskell `error`, not a graceful gRPC status.
3. Byron txs in `FetchBlock` report no fee (documented limitation, Byron fees are implicit).
