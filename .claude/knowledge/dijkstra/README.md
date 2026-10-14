# Dijkstra era

Dijkstra is the Cardano ledger era after Conway.
It is a new era with protocol version 12 (Conway covers 9 to 11).
It brings nested transactions with guards, account address deposits and balance assertions, a Plutus V4 language, a BLS voting key for stake pools, a new block and transaction encoding, new protocol parameters, and the ledger side of Ouroboros Linear Leios and Ouroboros Peras.

This directory describes the target design only.
It leaves out release status, library versions and implementation gaps.

## Feature map

| Feature | CIP | File |
|---|---|---|
| Transactions that carry sub-transactions, batch rules, legacy mode | 118 | [ledger/nested-transactions.md](ledger/nested-transactions.md) |
| `guards` replace required signers; guarding purpose; `RequireGuard`; required top-level guards | 112, 118 | [ledger/guards.md](ledger/guards.md) |
| Direct deposits into accounts, account balance intervals, partial withdrawals, no DRep delegation needed to withdraw | 159, 181 | [ledger/accounts.md](ledger/accounts.md) |
| `isValid` removed from standalone transactions; non-segregated block body; PlutusV4 tag and script context | 167, 176 | [ledger/serialisation.md](ledger/serialisation.md) |
| Protocol parameters 34 to 56: reference script and reference input pricing, pledge leverage, minimum pool margin, Leios, Peras | 23, 50, 164, 140 | [ledger/pparams.md](ledger/pparams.md) |
| BLS key and proof of possession in pool registration | 164 | [ledger/pool-bls-key.md](ledger/pool-bls-key.md) |
| Ranking blocks, endorser blocks, committee votes, certificates, delivery to node-to-client clients | 164 | [leios.md](leios.md) |
| Voting rounds, certificates, chain weight boost, cool-down | 140 | [peras.md](peras.md) |

## Canonical sources

Highest rank first.
When sources disagree, the file states the higher-ranked version and notes the divergence once.

1.
   Names and shapes of ledger data:
   - [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl) and the [Dijkstra Haskell modules](https://github.com/IntersectMBO/cardano-ledger/tree/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/src/Cardano/Ledger/Dijkstra) (cardano-ledger at `a6f303ad`).
   - [Agda `Ledger/Dijkstra/Specification`](https://github.com/IntersectMBO/formal-ledger-specifications/tree/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification) (formal-ledger-specifications at `61946f5`) for ledger semantics.
   - [Plutus V4 `Contexts.hs`](https://github.com/IntersectMBO/plutus/blob/86ff3451334f7e6c5ba021a86a202ac3fd562385/plutus-ledger-api/src/PlutusLedgerApi/V4/Contexts.hs) for the script context.
2.
   Protocol design:
   - [Leios technical design](https://github.com/input-output-hk/ouroboros-leios/blob/614b10d21691e40ed3a3e5a3462b08497fcfe443/docs/leios-design/README.md).
   - [Peras design](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0140/README.md) (CIP-140 holds the normative Agda protocol model).
   - Node-to-client delivery of certified EB transactions: the [#1114 design](https://github.com/input-output-hk/ouroboros-leios/blob/bbdd5060ea592fd058c646f4786a8811be7be407/docs/leios-design/node-to-client.md) and its [README requirements](https://github.com/input-output-hk/ouroboros-leios/blob/bbdd5060ea592fd058c646f4786a8811be7be407/docs/leios-design/README.md#node-to-client).
3.
   CIPs, design intent only (all at [CIPs `2077656`](https://github.com/cardano-foundation/CIPs/tree/20776563ab75c3a9d8f61a0607dac05838e08025)): [118](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0118/README.md), [112](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0112/README.md), [159](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0159/README.md), [164](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0164/README.md), [140](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0140/README.md), [167](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0167/README.md), [176](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0176/README.md), [181](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0181/README.md), [50](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0050/README.md), [23](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0023/README.md).

## Rollout shape

- The Dijkstra hard fork starts the era and activates Linear Leios.
  It also ships the Peras block body field and the Peras protocol parameters.
- A later intra-era hard fork inside Dijkstra activates Peras voting.
- Each fork goes through a governance action on each network.

Source: [Intersect hard fork planning](https://product.cardano.intersectmbo.org/hardfork-planning/dijkstra/) and [upgrade overview](https://cardanoupgrades.docs.intersectmbo.org/dijkstra-era-upgrade/dijkstra-upgrade-overview), checked against the raw pages.
Protocol version 12: [`ProtVerLow DijkstraEra`](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/libs/cardano-ledger-core/internal/Cardano/Ledger/Internal/Definition/Era.hs#L140).
Both pages list CIP-118, 112, 159, 167, 176, 181 and 50 and the Leios and Peras CIPs in scope.

## References

The per-topic files list their own references.
Entry points: the [Dijkstra CDDL](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl), the [Agda specification](https://github.com/IntersectMBO/formal-ledger-specifications/tree/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification), the [Intersect planning page](https://product.cardano.intersectmbo.org/hardfork-planning/dijkstra/).

## Ongoing work

- https://github.com/utxorpc/spec/pull/215
- https://github.com/IntersectMBO/cardano-api/issues/1263
- https://github.com/IntersectMBO/cardano-api/issues/1264
