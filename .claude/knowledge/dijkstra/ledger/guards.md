# Guards

A guard is a credential that a transaction must satisfy.
A key guard needs a signature, a script guard needs the script to run.
Guards replace required signers (CIP-112, with the ledger naming below).

## Body field 14

```
guards = nonempty_set<addr_keyhash> / nonempty_oset<credential>
```

Key 14 is the old `required_signers` key.
The key hash form is kept; the credential form allows script hashes.
Every guard credential is "needed" by the transaction: key hashes need a vkey witness, script hashes need the script in the batch script pool ([Validation.lagda.md `credsNeeded`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Script/Validation.lagda.md#L148)).
A guard needs no ledger action: a script runs because it is listed, not because it spends, mints or withdraws.
This replaces the withdraw-zero trick (CIP-112, Motivation).
When two sub-transactions require the same top-level guard script, it runs once with all the arguments supplied to it (CIP-118, rationale example).

## Guarding redeemer purpose

- Redeemer tag `6` is guarding: the key is `[6, index]`, where `index` is the position of the credential in the transaction's `guards` set.
- Only Plutus V4 and native scripts can be guard scripts in a sub-transaction; see [nested-transactions.md](nested-transactions.md) for language rules.
- Plutus V4 sees the purpose as `GuardingScript Integer (Maybe TopTxInfo)`.
  The `Maybe` is `Just` for a guard run at the top level and `Nothing` in a sub-transaction.
  `TopTxInfo` holds the `TxInfo` of every sub-transaction, the datums supplied through required top-level guards (keyed by `TxId`), the starting balance intervals, and an aggregated view of the batch.
  Source: [Contexts.hs `TopTxInfo`](https://github.com/IntersectMBO/plutus/blob/86ff3451334f7e6c5ba021a86a202ac3fd562385/plutus-ledger-api/src/PlutusLedgerApi/V4/Contexts.hs#L449).
- Guard scripts are the only scripts that see more than their own transaction ([Validation.lagda.md `txInfoForPurpose`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Script/Validation.lagda.md#L109)).
- A script guard in the top-level `guards` counts as a V4 feature: a transaction using it cannot also run V1 to V3 scripts ([Utxow.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxow.lagda.md#L125)).

## Native script guard clause

Native scripts gain a seventh variant, `RequireGuard credential`, with tag 6 in the CBOR form:

```
script_require_guard = (6, credential)
```

Evaluation takes the transaction's guard set as an extra argument; `RequireGuard c` holds when `c` is in that set.
The other six variants are unchanged (`RequireSig`, `RequireAllOf`, `RequireAnyOf`, `RequireMOf`, `RequireTimeStart`, `RequireTimeExpire`).
Native scripts replace Conway's Timelock scripts and run in phase 1.
Sources: [Native.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Script/Native.lagda.md#L52), [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L400).

## Required top-level guards

A sub-transaction cannot know the batch it joins.
Body key 24 lets it demand that certain guards appear in the top-level transaction:

```
required_top_level_guards = {+ credential => plutus_data / nil}
```

The value is an optional datum, passed to the guard script as its argument, because the sub-transaction author cannot supply execution units for a script that runs at the top level.

Rules ([Utxow.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxow.lagda.md#L236)):

1.
   The credentials required by the top-level transaction and by every sub-transaction must all be in the top-level `guards`.
   Only credentials are compared, never datums.
2.
   An entry is well formed when it has a datum and the credential resolves to a Plutus script (phase 2), or it has no datum and the credential is a key hash or resolves to a native script (phase 1).
3.
   Key hashes are valid required top-level guards, not only scripts.
4.
   Two sub-transactions may require the same credential with different datums; the guard script sees each datum, keyed by the `TxId` that required it, in `TopTxInfo`.

The Plutus V4 `TxInfo` carries the field as `txInfoRequiredTopLevelGuards :: Map Credential (Maybe Datum)`.

## Divergences

- CIP-112 names the script type "Observe", the body field `required_observers`, the native script clause `RequireObserver` and the purpose `Observe`.
  The ledger, the Agda spec and CIP-118 use guards, `guards`, `RequireGuard` and the guarding purpose.
- CIP-118 types required top-level guards as `[(ScriptHash, Data)]` with mandatory data, and says only sub-transactions carry them.
  The ledger CDDL uses a credential with optional datum, and key 24 is in both body shapes; `UTXOW` checks the top-level body's own entries as well.

## References

- [CIP-112 Observe Script Type](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0112/README.md): motivation for guards.
- [CIP-118](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0118/README.md): required top-level guards and `TxInfo` visibility.
- [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L644): `guards` and key 24.
- [Dijkstra Scripts.hs](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/src/Cardano/Ledger/Dijkstra/Scripts.hs): `GuardingPurpose`, `RequireGuard`.
- [Agda Utxow](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxow.lagda.md), [Validation](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Script/Validation.lagda.md), [Native](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Script/Native.lagda.md): semantics.
- [Plutus V4 Contexts](https://github.com/IntersectMBO/plutus/blob/86ff3451334f7e6c5ba021a86a202ac3fd562385/plutus-ledger-api/src/PlutusLedgerApi/V4/Contexts.hs): `GuardingScript`, `TopTxInfo`.

## Ongoing work

- https://github.com/IntersectMBO/formal-ledger-specifications/issues/1002
