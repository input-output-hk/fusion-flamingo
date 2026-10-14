# Protocol parameters new in Dijkstra

Dijkstra keeps every Conway parameter (keys up to 33) and adds keys 34 to 56.
The list comes from diffing the Dijkstra and Conway `PParams.hs` and the `protocol_param_update` CDDL.
Names are the Haskell names without the `dpp` prefix; the types are the CDDL types.
Groups are the governance groups of each parameter: parameters in the security group fall under the pool voting threshold for security relevant parameters (`pool_voting_thresholds` in the CDDL).

## Reference scripts and reference inputs

| Key | Name | Type | Group | Meaning |
|---|---|---|---|---|
| 34 | `maxRefScriptSizePerBlock` | `uint .size 4` | network, security | Bytes of reference scripts allowed across all transactions of a block. |
| 35 | `maxRefScriptSizePerTx` | `uint .size 4` | network, security | Bytes of reference scripts a transaction may use. In a batch the bound covers the whole batch. |
| 36 | `refScriptCostStride` | `positive_word32` | network, security | Size of one price tier in bytes. |
| 37 | `refScriptCostMultiplier` | `positive_interval` | network, security | Factor by which the per-byte price grows from one tier to the next. |
| 55 | `refInputsCostPerMultiAssetPolicy` | `coin` | economic, security | Fee per multi-asset policy in the values of a transaction's reference inputs. |
| 56 | `refInputsCostPerDatumByte` | `coin` (per byte) | economic, security | Fee per byte of datum attached to reference inputs. |

The reference script fee is tiered.
The first `refScriptCostStride` bytes cost `minFeeRefScriptCostPerByte` (key 33, from Conway) each.
Each next stride costs the previous per-byte price times `refScriptCostMultiplier`.
The total is rounded down ([Fees.lagda.md `scriptsCost`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Fees.lagda.md#L46)).
Keys 55 and 56 price reading data from disk through reference inputs; the Haskell docs give this as the reason ([PParams.hs](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/src/Cardano/Ledger/Dijkstra/PParams.hs#L291)).

## Pool rewards

| Key | Name | Type | Group | Meaning |
|---|---|---|---|---|
| 38 | `maxPledgeLeverage` | `nonnegative_interval / nil` | technical | Maximum ratio of stake to pledge before a pool's rewards stop growing (CIP-50, symbol `L`). `nil` means no cap. |
| 39 | `minPoolMargin` | `unit_interval` | economic | Lower bound on a pool's margin (CIP-23). |

CIP-50 and CIP-23 are design intent for these two keys.

## Leios

| Key | Name | Type | Symbol | Meaning |
|---|---|---|---|---|
| 40 | `leiosAnnouncementPeriodLength` | `uint .size 4`, ms | `L_hdr` | Time for an announcing header to reach the network. |
| 41 | `leiosVotePeriodLength` | `uint .size 4`, ms | `L_vote` | Time during which committee members vote on an EB. |
| 42 | `leiosDiffusionPeriodLength` | `uint .size 4`, ms | `L_diff` | Extra time after voting so a certified EB reaches everyone. |
| 43 | `leiosCommitteeSize` | `uint .size 2` | `N_c` | Number of top-stake pools seated on the voting committee. |
| 44 | `leiosQuorumStakeThreshold` | `unit_interval` | `τ` | Fraction of total active stake the signers of a certificate must carry. |
| 45 | `maxEndorserBlockReferencesSize` | `uint .size 4` | `S_EB` | Size limit of the EB itself, meaning all transaction references. |
| 46 | `maxEndorserBlockTxsSize` | `uint .size 4` | `S_EB-tx` | Total size of the transactions an EB endorses. |
| 47 | `maxEndorserBlockExUnits` | `ex_units` | none | Plutus memory and steps per EB. |
| 48 | `maxRefScriptSizePerEndorserBlock` | `uint .size 4` | `S_EB-ref` | Reference script bytes used by the transactions of one EB. |

All nine are in the network and security groups.
The Agda spec names seven of them differently:

| Haskell | Agda |
|---|---|
| `leiosAnnouncementPeriodLength` | `leiosHeaderPeriod` |
| `leiosVotePeriodLength` | `leiosVotingPeriod` |
| `leiosDiffusionPeriodLength` | `leiosDiffusionPeriod` |
| `maxEndorserBlockReferencesSize` | `leiosMaxEBSize` |
| `maxEndorserBlockTxsSize` | `leiosMaxEBTxsSize` |
| `maxEndorserBlockExUnits` | `leiosMaxEBExUnits` |
| `maxRefScriptSizePerEndorserBlock` | `leiosMaxRefScriptSizePerEB` |

Notes from the Agda spec and the Leios design (Agda [PParams.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/PParams.lagda.md#L167)):

- Timing values are milliseconds, so sub-second values work independent of the slot length.
- Zero Leios values are the protocol's disabled state, so well-formedness does not require them to be positive.
- Well-formedness requires `τ` above one half.
  CIP-164 also requires `τ` below the stake share held by the seated committee, a property of the stake distribution that parameters cannot enforce.
- The ranking block keeps `maxBlockSize`; Leios adds no parameter for it.
- Limits exist per EB only, not per transaction (CIP-164).

Concepts: [leios.md](../leios.md).

## Peras

| Key | Name | Type | Meaning |
|---|---|---|---|
| 49 | `perasMinCandidateBlockAge` | `slot_interval` | Minimum age of a block before it can be voted for. CIP-140 symbol `L`. |
| 50 | `perasHealingFactor` | `positive_interval` | Coefficient from which the length of a cool-down period is derived. |
| 51 | `perasCertBoost` | `uint .size 2` | Extra chain weight a certificate gives its block. CIP-140 symbol `B`. |
| 52 | `perasTargetCommitteeSize` | `uint .size 2` | Target size of the voting committee. |
| 53 | `perasBootstrapRound` | `nil / uint .size 4` | Round number used to start voting at a chosen time. |
| 54 | `perasQuorumThresholdSafetyMargin` | `unit_interval` | Margin added to the 75% quorum baseline; between 0 and 0.25 inclusive. |

All six are in the network and security groups.
Concepts and the CIP-140 mapping: [peras.md](../peras.md).

## References

- [dijkstra.cddl `protocol_param_update`](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L682): keys and types.
- [Dijkstra PParams.hs](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/src/Cardano/Ledger/Dijkstra/PParams.hs#L161) and [Conway PParams.hs](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/conway/impl/src/Cardano/Ledger/Conway/PParams.hs): names, types, groups.
- [Agda PParams](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/PParams.lagda.md) and [Fees](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Fees.lagda.md): Leios parameters and the reference script fee.
- [CIP-50](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0050/README.md), [CIP-23](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0023/README.md): pool reward parameters.
- [CIP-164](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0164/README.md), [CIP-140](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0140/README.md): protocol meaning.
- [Intersect Dijkstra upgrade overview](https://cardanoupgrades.docs.intersectmbo.org/dijkstra-era-upgrade/dijkstra-upgrade-overview): lists reference script pricing and limits as protocol parameters and pledge leverage with default `nil`.

## Ongoing work

- https://github.com/IntersectMBO/cardano-ledger/pull/6110
