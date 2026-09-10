# cardano-rpc: implemented surface and gaps

Snapshot of master as of 2026-09-03.
Source: cardano-api repo, `cardano-rpc/` (Server.hs, handlers, proto files).

## Release status

Not in any tagged cardano-node release; master only.
All CLI flags are marked EXPERIMENTAL.
Transport: unix socket (default), h2c, or TLS, one listener at a time, enabled with `EnableRpc: true`.
Node connection is mixed mid-migration (ADR-019): query/submit methods use N2C IPC, sync/genesis methods use in-process node kernel access.

## Method status

QueryService: `ReadParams` (Conway+ only), `ReadUtxos`, `SearchUtxos` (exact-address predicates only), `ReadGenesis`, `ReadEraSummary` implemented.
`ReadData`, `ReadTx`, `ReadState` unimplemented.

SubmitService: `SubmitTx`, `EvalTx` implemented.
`WaitForTx`, `ReadMempool`, `WatchMempool` unimplemented.

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
