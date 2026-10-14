# Pool BLS key

A stake pool can register a BLS12-381 voting key together with its pool registration.
Leios committee members sign votes with it.

## Shape

The key is an optional field of the pool registration certificate's parameters:

```
pool_params =
  ( operator : pool_keyhash, vrf_keyhash : vrf_keyhash
  , ? bls_key : bls_key / nil
  , pledge, cost, margin, reward_account, pool_owners, relays, pool_metadata )

bls_key = [bls_pubkey : bytes .size 96, bls_possession_proof : bytes .size 48]
```

Source: [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L467).
The Agda `StakePoolParams` has `bls : Maybe (BlsVKey × BlsPoP)` ([Certs.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Certs.lagda.md#L27)).

## Rules at registration and re-registration

Both `POOL-reg` and `POOL-rereg` require ([Certs.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Certs.lagda.md#L508)):

1.
   Uniqueness: the BLS key belongs to at most one pool, counting both current and future pool parameters.
   A pool re-registering may repeat its own key.
2.
   A valid proof of possession for the key.
   The check is the BLS12-381 proof of possession verification ([Pool.hs](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/src/Cardano/Ledger/Dijkstra/Rules/Pool.hs#L240)).

A pool with no key is valid.
If its stake puts it on the committee, it holds a keyless seat that cannot sign.

## Why a proof of possession

BLS aggregate signatures are open to rogue-key attacks: someone registers a key built from other keys so that an aggregate appears to include voters who never signed.
Only a key with a valid proof can hold a seat or add to a certificate (CIP-164, "Key Registration and Rotation").

## State and lifetime

- The pool state keeps the key and the epoch of its first registration; the proof is dropped (`mkStakePoolState`).
- A registered key is honoured for `maxKeyAge` epochs: the KES key lifetime rounded up to whole epochs, plus two epochs of activation delay.
  The delay exists because a key enters the stake snapshot at the next epoch boundary and the committee one boundary later.
- Expiry is judged against the epoch the committee is chosen for, not the epoch of the snapshot.
- A pool selected by stake without an honoured key gets a keyless seat: it counts for membership, cannot sign, and a certificate naming it as a signer is invalid.
- CIP-164 recommends rotating on a cadence comparable to KES key rotation, and aligning activation with VRF key activation at the epoch boundary.

Source: [Leios.lagda.md `maxKeyAge`, `honouredBlsKey`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Leios.lagda.md#L84).

## What consumes it

The Leios voting committee ([leios.md](../leios.md)): each seat holds a pool, its stake weight and the pool's honoured BLS key.
EB certificates carry an aggregate BLS signature that must verify under the keys of the named signers.
Peras votes in CIP-140 reuse the pool VRF and KES keys and name no BLS key ([peras.md](../peras.md)).

## References

- [CIP-164, key registration](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0164/README.md#votes-and-certificates): purpose, proof of possession, rotation.
- [dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L483): `bls_key`.
- [Agda Certs](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Certs.lagda.md) and [Leios](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Leios.lagda.md): pool rules, committee seats, key expiry.

## Ongoing work

None.
