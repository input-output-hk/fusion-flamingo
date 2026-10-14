# Peras

Ouroboros Peras (CIP-140) adds a voting layer to Praos chain selection so that blocks become irreversible much faster.
It does not change how blocks are produced.
Committees of stake pools vote on recent blocks, and a block that gets a quorum of votes gains extra chain weight.
Settlement is fast against an adversary holding up to one quarter of the stake, and the protocol keeps Praos-like safety above that.

## Concepts

| Term | Meaning |
|---|---|
| Round | A fixed number of consecutive slots (`U`). Voting is attempted at the start of each round. |
| Committee | The voters of a round, chosen by a VRF sortition proportional to stake, like Praos slot leadership. |
| Vote | A committee member's vote for a block of its preferred chain, at least `L` slots old. |
| Certificate | Records a quorum of votes for one block in one round. Each round has at most one. |
| Boost | Extra weight `B` a certificate gives to its block. |
| Chain weight | `Wt(C) = len(C) + B * certCount(C)`, where `certCount` counts the certificates that vote for blocks on `C`. A node prefers the heaviest valid chain. |
| Cool-down | After a round without a quorum, voting pauses until the chain has healed. |
| Expiry | A certificate older than `A` rounds can no longer be included in a block. |

A node tracks its preferred chain, the latest certificate it has seen, and the latest certificate on its preferred chain.
Equivocating votes are ignored after the first.

## Voting and certificate inclusion

A member votes in round `r` if one of two pairs of conditions holds:

- Regular voting: it has seen the certificate of round `r - 1`, and the block it votes for extends the latest certified block.
- Leaving a cool-down: the latest certificate it has seen is at least `R` rounds old, and `r` is a whole number of `K` rounds after the round of the latest certificate on its chain.

A block producer records the latest certificate it has seen in a new block only when: no certificate of round `r - 2` exists, the certificate is at most `A` rounds old, and it is newer than the latest certificate already on the chain.
So certificates are typically recorded in blocks only near the start and end of a cool-down.

## Parameters

CIP-140 has seven natural-number parameters.

| Symbol | Meaning | Constraint |
|---|---|---|
| `U` | Round length in slots | `U ≥ Δ`, non-zero |
| `L` | Minimum age of a block to be voted for | `L > Δ` |
| `A` | Maximum age of an includable certificate, in rounds | `A = ⌈(T_heal + T_CQ) / U⌉` |
| `R` | Rounds to ignore certificates after entering a cool-down | `R = A` |
| `K` | Minimum rounds to wait before voting again | `K = ⌈(A + T_CP) / U⌉`, non-zero |
| `B` | Extra weight of a certificate | `B > 0` |
| `τ` | Votes needed for a certificate | `τ > 3n/4` for committee size `n` |

`Δ` is the network diffusion bound, `T_heal` the healing time, `T_CQ` the chain quality time and `T_CP` the common prefix time.

## In the ledger

- `block_body` has an optional `peras_certificate`, defined in the CDDL as plain `bytes` ([serialisation.md](ledger/serialisation.md)).
- Six protocol parameters, keys 49 to 54, carry the settings ([pparams.md](ledger/pparams.md)).

| Ledger parameter | CIP-140 |
|---|---|
| `perasMinCandidateBlockAge` | `L` |
| `perasCertBoost` | `B` |
| `perasHealingFactor` | derives the cool-down length |
| `perasTargetCommitteeSize` | target committee size |
| `perasBootstrapRound` | none (starts voting at a chosen round) |
| `perasQuorumThresholdSafetyMargin` | none (see below) |

The ledger has no parameters named `U`, `A`, `R` or `K`.
The quorum is a 75% baseline plus the safety margin, a fraction between 0 and 0.25; CIP-140 states it as a vote count above `3n/4`.

## Activation

Peras activates after the Dijkstra era starts.
The Dijkstra era carries the block body field and the parameters, and a later intra-era hard fork switches voting on.
That second hard fork is a protocol version bump inside the Dijkstra era, possible because the era already defines the structures.
Source: [Intersect Dijkstra planning](https://product.cardano.intersectmbo.org/hardfork-planning/dijkstra/).
These two phases are the hard-fork phases of [README.md](README.md), not the two stages of CIP-159 in [accounts.md](ledger/accounts.md).

## Votes and keys

CIP-140 defers the vote and certificate format to a separate proposal.
Its sketch of a vote reuses the pool's VRF and KES keys and names no BLS key; the BLS key of [pool-bls-key.md](ledger/pool-bls-key.md) is for Leios.
CIP-164 states the aim of shared voting infrastructure across Leios, Peras and other protocols.

## Divergences

- CIP-140 adds `peras_cert` to the segregated Conway block and sketches a `votes_certificate` record; the Dijkstra block body holds an opaque `peras_certificate`.
- The CIP-140 parameter set and quorum form differ from the ledger parameters, as above.

## References

- [CIP-140 Ouroboros Peras](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0140/README.md): protocol, voting rules, parameters.
- [Dijkstra PParams.hs](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/src/Cardano/Ledger/Dijkstra/PParams.hs#L272): Peras parameters and their documentation.
- [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L944): `peras_certificate`, keys 49 to 54.
- [Intersect Dijkstra upgrade overview](https://cardanoupgrades.docs.intersectmbo.org/dijkstra-era-upgrade/dijkstra-upgrade-overview): two-phase shape.

## Ongoing work

- https://github.com/IntersectMBO/cardano-ledger/pull/6126
