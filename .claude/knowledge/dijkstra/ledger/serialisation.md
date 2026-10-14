# Serialisation and PlutusV4

## Blocks (CIP-176)

The segregated block layout of Conway is gone.
A block is a header and a body, and each transaction is written in full before the next:

```
block      = [header, block_body]
block_body = [ transactions      : [* block_transaction]
             , leios_certificate : leios_certificate / nil
             , peras_certificate : peras_certificate / nil ]
```

The two certificates are the Leios and Peras additions ([leios.md](../leios.md), [peras.md](../peras.md)).
CIP-176 motivates the change with nested transactions, which segregated serialisation would make hard to specify, and with the certificates that Leios and Peras add to the body.
It also says the block body hash becomes a single hash over `block_body`; the CDDL comment on `block_body_hash` reads "merkle triple root".

Header body changes against Conway:

| Conway | Dijkstra |
|---|---|
| `protocol_version` | `header_version_info = [highest_supported_major_version, self_reported_software_tag]` |
| none | `block_body_contains_leios_cert : bool` |
| none | `eb_references_announcement : [eb_hash, eb_size] / nil` |

Sources: [dijkstra.cddl header](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L58), [block body](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L110), [CIP-176](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0176/README.md).

## `isValid` removal (CIP-167)

The flag records the phase 2 outcome.
The transaction author does not sign it, so a standalone transaction no longer carries it.
The block producer sets it and appends it as the last element of each transaction in a block.

```
block_transaction   = [transaction_body, transaction_witness_set, auxiliary_data / nil, bool]
mempool_transaction = [transaction_body, transaction_witness_set, auxiliary_data / nil]
                    / [transaction_body, transaction_witness_set, true, auxiliary_data / nil]
```

- The second `mempool_transaction` form exists for transactions that cross the era boundary; it accepts only `true`, and encoders should not produce it.
- A node ignores the flag of a transaction from an untrusted peer and evaluates it as if valid.
  If phase 2 then fails, it keeps the transaction with the flag false, so that collateral can be collected.
- The ledger rule `UTXOS` requires the result of evaluating all scripts of the batch to equal the top-level flag ([Utxo.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Utxo.lagda.md#L408)).
- Sub-transactions have no flag; they follow the top-level one ([nested-transactions.md](nested-transactions.md)).

Source: [CIP-167](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0167/README.md), [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L8).

## Other encoding changes

- `redeemers` is a map only: `{+ [tag, index] => [data, ex_units]}`.
  Conway also allowed a flat array.
- `redeemer_tag` gains `6` for guarding ([guards.md](guards.md)).
- `language = 0 .. 3`; tag `3` is Plutus V4.
- Script hash prefix byte `"\x04"` for V4; a `script` choice `[4, plutus_v4_script]`, also valid in reference scripts of outputs.
- Witness set key `8` holds `nonempty_set<plutus_v4_script>`; auxiliary data map key `5` holds V4 scripts.
- `cost_models` accepts key `3` for V4.
- Native scripts have a seventh variant ([guards.md](guards.md)).
- Pool registration carries an optional BLS key ([pool-bls-key.md](pool-bls-key.md)).

## PlutusV4 script context

Sub-transactions and top-level guards cannot run under V3 or earlier (CIP-118), which is why a new language version exists.
The Agda spec treats `TxInfo` abstractly; the concrete data shape below is from the Plutus V4 module.

```
ScriptContext { scriptContextTxInfo, scriptContextRedeemer,
                scriptContextScriptInfo, scriptContextScriptHash }
```

- V3 has three fields; V4 adds `scriptContextScriptHash`, the hash of the running script.
- `ScriptInfo` constructors carry no script hash: `MintingScript`, `SpendingScript TxOutRef (Maybe Datum)`, `WithdrawingScript AccountId`, `CertifyingScript Integer TxCert`, `VotingScript Voter`, `ProposingScript Integer ProposalProcedure`, `GuardingScript Integer (Maybe TopTxInfo)`.
- The `ScriptPurpose` that keys `txInfoRedeemers` has a leading `ScriptHash` on every constructor, including `Guarding`.
- `TxInfo` adds `txInfoSubTxIx`, `txInfoDirectDeposits`, `txInfoAccountBalanceIntervals`, `txInfoGuards` and `txInfoRequiredTopLevelGuards`.
- `TxInfo` has `txInfoWithdrawals` where V3 has `txInfoWdrl`, and no longer has a fee field or a signatories field (`txInfoGuards` holds credentials instead).
- `txInfoTreasuryDonation` is a plain `Lovelace`.

Sub-transaction handling of the context is in [nested-transactions.md](nested-transactions.md) and [guards.md](guards.md).
Every place a Plutus script can appear (witness set, reference script, auxiliary data) has a V4 form, so the language range of the era is V1 to V4.

## References

- [Dijkstra CDDL](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl) and [Conway CDDL](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/conway/impl/cddl/data/conway.cddl): wire formats.
- [CIP-167](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0167/README.md) and [CIP-176](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0176/README.md): design intent.
- [Plutus V4 Contexts](https://github.com/IntersectMBO/plutus/blob/86ff3451334f7e6c5ba021a86a202ac3fd562385/plutus-ledger-api/src/PlutusLedgerApi/V4/Contexts.hs#L492): `ScriptContext`, `ScriptInfo`, `TxInfo`.
- [CIP-118](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0118/README.md): why V4.

## Ongoing work

- https://github.com/IntersectMBO/cardano-ledger/issues/5605
