# JS SDK gap analyses: MeshJS and Evolution SDK

Both SDKs already ship u5c providers, so "switch to cardano-rpc" means pointing existing provider code at a node instead of Dolos.
Method status in [cardano-rpc-status.md](cardano-rpc-status.md).

Correction (2026-09-09, found by live testing): the published providers do NOT work against cardano-rpc at all today.
Both are pinned to `@utxorpc/sdk` 0.6.x, which speaks the `utxorpc.v1alpha.*` services, while cardano-rpc implements `v1beta` only; every call fails with UNIMPLEMENTED, and some v1beta message shapes differ (e.g. ex-unit prices are a `RationalNumber`, not a plain number).
The method-level analysis below still holds once the SDKs move to v1beta; until then the practical path is a small hand-rolled v1beta provider (verified working example in [quickstart-draft.md](quickstart-draft.md), including a real transaction built and submitted with MeshJS wallet and tx-builder against cardano-rpc).
Root cause is upstream in utxorpc/spec, not in the SDK consumers: `@utxorpc/spec` 0.19.2 ships the generated v1beta sources in its tarball, but the package barrel exports v1alpha only, so v1beta is unreachable from the published package; `@utxorpc/sdk` 0.9.0 (2026-08-27) is just a dependency bump on top of that.
The fix is draft PR utxorpc/spec#209 (per-version barrels, Santiago Carmuega, opened 2026-08-17) with Mateusz's #208 stacked on it; once merged and released, MeshJS and Evolution need only routine dependency bumps, so no issues should be filed against them.
Once the SDKs reach v1beta, the shared blocker becomes `WaitForTx`.

## MeshJS

Provider: `U5CProvider` in the `MeshJS/providers` repo, built on `@utxorpc/sdk`.
It only calls `SearchUtxos` (exact address, matching cardano-rpc's restriction), `ReadUtxos`, `ReadParams`, `EvalTx`, `SubmitTx` and `WaitForTx`.
Everything works against cardano-rpc except `onTxConfirmed` and `awaitTransactionConfirmation`, which stream `WaitForTx` and would hang until timeout.
Most of Mesh's fetcher interface (account info, tx history, asset metadata, blocks) is unimplemented on this provider regardless of backend, so those gaps do not count against cardano-rpc.

## Evolution SDK

Formerly Lucid Evolution / Anastasia Labs; now by No Witness Labs, incubated under Intersect, repo `IntersectMBO/evolution-sdk`.
Provider: `@utxorpc/lucid-evolution-provider`, maintained by the UTxO RPC org.

Works against cardano-rpc: `getProtocolParameters`, `getUtxos(address)`, `getUtxosWithUnit(address, unit)`, `getUtxosByOutRef`, `submitTx`, `evaluateTx`.
Breaks: `getUtxos(credential)`, `getUtxosWithUnit(credential, unit)` and `getUtxoByUnit` send payment-part, delegation-part or asset-only predicates, which cardano-rpc rejects with `INVALID_ARGUMENT`; `awaitTx` streams `WaitForTx`.
`getDelegation` and `getDatum` are TODO stubs in their provider, so they fail against any backend.

## Priority order for cardano-rpc

1. `WaitForTx`: unblocks both SDKs and the wallet UX argument in [lace.md](lace.md).
2. Broad `SearchUtxos` predicates: needed for Evolution's credential and asset queries; a design question (full UTxO-set scans on a live node), candidates are an opt-in flag or a documented "point that at an indexer" stance, see sieve in [ecosystem.md](ecosystem.md).
3. `ReadData`: low urgency; Evolution's client side is a stub anyway.
