# Nested transactions

A batch is one top-level transaction that carries a list of sub-transactions (CIP-118).
Sub-transactions may be unbalanced and pay no fee; the batch as a whole must balance.
Sub-transactions cannot contain sub-transactions.

## Shape

```
sub_transactions = nonempty_oset<sub_transaction>
sub_transaction  = [sub_transaction_body, transaction_witness_set, auxiliary_data / nil]
```

The Agda spec has one `Tx (txLevel : TxLevel)` type with `TxLevelTop` and `TxLevelSub` ([Transaction.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Transaction.lagda.md#L50)).

| Body key | Field | Top | Sub |
|---|---|---|---|
| 0, 1, 3, 4, 5, 7, 8, 9, 11, 15, 18, 19, 20, 21, 22 | inputs, outputs, ttl, certs, withdrawals, aux hash, validity start, mint, script integrity hash, network id, reference inputs, votes, proposals, treasury, donation | yes | yes |
| 14 | `guards` ([guards.md](guards.md)) | yes | yes |
| 24 | `required_top_level_guards` ([guards.md](guards.md)) | yes | yes |
| 25, 26 | `direct_deposits`, `account_balance_intervals` ([accounts.md](accounts.md)) | yes | yes |
| 2, 13, 16, 17 | fee, collateral inputs, collateral return, total collateral | yes | no |
| 23 | `sub_transactions` | yes | no |
| 27 | `starting_account_balance_intervals` | yes | no |

The `isValid` flag also exists only at the top level ([serialisation.md](serialisation.md)).
Sources: [dijkstra.cddl body](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L116) and [sub body](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L829).
The prose of Transaction.lagda.md calls `txGuards` top-level only; the Agda record and the CDDL have it at both levels.

## Processing order

Sub-transactions are applied in list order, then the top-level transaction.
For the whole batch the ledger first checks every sub-transaction and the top-level transaction in phase 1, and evaluates all Plutus scripts once at the end.
For a sub-transaction the order is UTXOW, then entities (certificates, withdrawals, direct deposits), then governance.
For the top-level transaction it is entities, then governance, then UTXOW, so that the batch balance sees the batch-wide deposit changes.
Source: [Ledger.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Ledger.lagda.md#L304) (`SUBLEDGER`, `LEDGER`).
Splitting work into sub-transactions gives control over order, for example delegating to a DRep and withdrawing rewards in one batch (CIP-118, point 8).

## Batch rules

| Rule | Source |
|---|---|
| Every spending, reference and collateral input must exist in the UTxO before any transaction of the batch is applied. | [Utxo.lagda.md `UTXO`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxo.lagda.md#L500) |
| Spending inputs of all transactions in the batch are pairwise disjoint, and each must be non-empty. | same |
| Balance holds for the batch: `consumedBatch` equals `producedBatch`. Each transaction on its own need not balance. | [Utxo.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxo.lagda.md#L320) |
| The ADA part of the mint value of each transaction is zero. | `UTXO`, `SUBUTXO` |
| Each transaction has its own validity interval, network id and treasury value checks. | `UTXO`, `SUBUTXO` |
| The size of the top-level transaction, sub-transactions included, is at most `maxTxSize`. | `UTXO`, CIP-118 point 8 |
| Scripts are shared batch-wide: a script from any witness set, output or reference input is usable by every transaction. | [Transaction.lagda.md `getAllScripts`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Transaction.lagda.md#L685) |
| Datums are not shared: each transaction supplies the datums for its own inputs. | [Utxow.lagda.md `SUBUTXOW`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxow.lagda.md#L259) |
| Each sub-transaction keeps its own `TxId`; its outputs are keyed by that id. | `outs` in Utxo.lagda.md |

Fee and collateral:

- The fee field is on the top-level body only.
- The lower bound on it uses the size of the top-level transaction, the execution units of its own redeemers, and the reference script cost ([`minfee`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxo.lagda.md#L235)).
- Collateral is top-level only.
  It is required when any redeemer in the batch exists, and it covers every script of the batch ([`collateralCheck`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxo.lagda.md#L287)).
- If a script fails, the collateral is collected and no transaction of the batch is applied (`LEDGER-I`, `SUBLEDGER-I`).

Phase 2 runs after every phase 1 check of the whole batch, so cheap checks reject a batch before any Plutus script runs (CIP-118, "Collateral and Phase-2 Invalid Transactions").

## Plutus languages and legacy mode

Sub-transactions run native scripts and Plutus V4 only.
A top-level transaction runs in normal mode (native and V4 scripts only) unless it needs a V1, V2 or V3 script.
That choice is made once per batch by [`isLegacyMode`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxow.lagda.md#L200).
Legacy mode isolates the top-level transaction from the new features, so that old scripts see nothing new:

- The top-level transaction balances by itself (`consumedLegacy` equals `producedLegacy`), and the sub-transactions balance among themselves.
- The top-level `guards` hold key hashes only, and the top level has no direct deposits or balance intervals.
- Top-level withdrawals must take the full account balance ([accounts.md](accounts.md)).
- Language use follows [`allowedLanguagesLegacy`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxow.lagda.md#L125): V3 and below are excluded when the top-level transaction uses a V4 feature.

A batch that needs new features next to old scripts places the new features in sub-transactions (CIP-118, "Using older PlutusV1 - PlutusV3 scripts").

## Script context

Each script sees only the `TxInfo` of its own transaction.
Only guard scripts at the top level also see the sub-transactions ([guards.md](guards.md), [serialisation.md](serialisation.md)).
`txInfoSubTxIx` is `Nothing` in a top-level `TxInfo` and `Just` an integer in a sub-transaction `TxInfo` ([Contexts.hs](https://github.com/IntersectMBO/plutus/blob/86ff3451334f7e6c5ba021a86a202ac3fd562385/plutus-ledger-api/src/PlutusLedgerApi/V4/Contexts.hs#L349)).

## Off-chain handling

Partially valid transactions are never sent over the network or held in the mempool.
Aggregators collect them off-chain and submit only complete batches.
CIP-118 describes no off-chain component.

## Divergences from CIP-118

- The CIP sub-transaction CDDL keeps body key 17; the ledger CDDL has no key 17 in sub-transactions.
- The CIP lets the top-level transaction carry supplemental datums for sub-transaction outputs; the Agda `UTXOW` rules check each transaction's datums against its own outputs and reference inputs.
- The CIP puts `txInfoSubTxs` in `TxInfo`; the Plutus V4 module carries the sub-transaction infos inside `GuardingScript`.
  The Agda `Validation` module names `txInfoSubTxs`, as the CIP does.

## References

- [CIP-118 Nested Transactions](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0118/README.md): design intent, use cases.
- [Dijkstra CDDL](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl): wire shape.
- [Agda Transaction](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Transaction.lagda.md), [Utxo](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxo.lagda.md), [Utxow](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxow.lagda.md), [Ledger](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Ledger.lagda.md): ledger semantics.
- [Plutus V4 Contexts](https://github.com/IntersectMBO/plutus/blob/86ff3451334f7e6c5ba021a86a202ac3fd562385/plutus-ledger-api/src/PlutusLedgerApi/V4/Contexts.hs): script context shape.

## Ongoing work

- https://github.com/IntersectMBO/cardano-ledger/issues/5123
- https://github.com/IntersectMBO/cardano-ledger/pull/6121
- https://github.com/IntersectMBO/formal-ledger-specifications/issues/999
- https://github.com/IntersectMBO/cardano-api/pull/1361
