# Accounts: direct deposits and balance intervals

CIP-159 turns account addresses (reward addresses) into places that anyone can pay into and that transactions can assert on.
The ledger keeps its `Rewards` map, now meaning account balances: staking rewards and direct deposits increase a balance, withdrawals decrease it ([Certs.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Certs.lagda.md#L85)).
Account addresses use address header types `1110` (key hash) and `1111` (script hash) ([dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L183)).

## Fields

| Key | Field | Type | Levels |
|---|---|---|---|
| 25 | `direct_deposits` | `{+ reward_account => coin}` | top and sub |
| 26 | `account_balance_intervals` | `{+ reward_account => account_balance_interval}` | top and sub |
| 27 | `starting_account_balance_intervals` | same as 26 | top only |

```
account_balance_interval =
  [inclusive_lower_bound : coin, exclusive_upper_bound : coin / nil]
  / [inclusive_lower_bound : coin / nil, exclusive_upper_bound : coin]
  / coin
```

A bare `coin` is an exact assertion.
A `nil` lower bound means zero.
An interval is half open: `[lb, ub)`.
Agda constructors: `⟦ lb , ub ⦆`, `⟦ lb ,∞⦆`, `⟦0, ub ⦆`, `Exact c` ([Account.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Account.lagda.md#L45)).

## Direct deposits

- The deposit needs no witness from the receiving account, so the receiving script does not run.
- The account must be registered, and its network id must match the ledger's.
- Deposits are applied after the certificates of the same transaction.
- In the balance equation a deposit is on the produced side, next to outputs, fee and donation.

Source: [Entities.lagda.md `ENTITIES`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Entities.lagda.md#L178), [Utxo.lagda.md `producedTx`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxo.lagda.md#L335).

## Balance intervals

- They are phase 1 conditions: no witness, no script run.
- Every listed account must be registered.
  CIP-159 also requires the network id of each reward account to match the ledger.
- `account_balance_intervals` at each level is checked against the balances that level observes, before that level's own withdrawals, deposits and certificates.
  Sub-transactions are processed before the top level, so a top-level map sees the balances left by all sub-transactions.
- `starting_account_balance_intervals` is checked against the balances at the start of the whole batch (`rewards₀`).
- Plutus V4 scripts see the maps in `txInfoAccountBalanceIntervals` and, for the starting map, in `TopTxInfo`.

## Withdrawals

- A withdrawal may take any amount up to the balance (CIP-159); the `Withdraw` purpose is reused for partial and full withdrawals.
- In legacy mode the top-level transaction must withdraw the full balance of each account ([nested-transactions.md](nested-transactions.md)).
  Sub-transactions in legacy mode may withdraw up to the balance at the batch start.
- In normal mode the summed withdrawals of all levels must not exceed the balance at the start of the batch.
  Later sub-transactions therefore cannot withdraw what earlier ones deposited, which prevents the "phantom asset" attack named in CIP-159.
- A withdrawal does not need a voting delegation: the `ENTITIES` rule has no such premise, matching CIP-181 (Remove DRep Requirement for Reward Withdrawals).

## Scope in the ledger

CIP-159 delivers in two stages: ADA only, then multi-asset.
The Dijkstra CDDL and Agda spec hold the ADA stage: `withdrawals` and `direct_deposits` stay `reward_account => coin`, and intervals bound ADA only.
The CIP's multi-asset form changes `withdrawals` to carry a `value`; this is not in the Dijkstra CDDL.
These CIP stages are unrelated to the two Dijkstra hard-fork phases in [README.md](../README.md).

## Combining with old scripts

A transaction using these fields counts as using a V4 feature, so it cannot run V1 to V3 scripts.
Put the deposits and intervals into a sub-transaction to use them in a batch whose top level runs old scripts (CIP-118).

## References

- [CIP-159 Account Address Enhancement](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0159/README.md)
- [CIP-181 Remove DRep Requirement for Reward Withdrawals](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0181/README.md)
- [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L851): `direct_deposits` and intervals.
- [Agda Account](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Account.lagda.md), [Entities](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Entities.lagda.md): semantics.
- [Plutus V4 Contexts](https://github.com/IntersectMBO/plutus/blob/86ff3451334f7e6c5ba021a86a202ac3fd562385/plutus-ledger-api/src/PlutusLedgerApi/V4/Contexts.hs#L261): `AccountBalanceInterval`.

## Ongoing work

- https://github.com/IntersectMBO/formal-ledger-specifications/issues/1112
