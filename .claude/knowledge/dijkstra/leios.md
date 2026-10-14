# Linear Leios

Linear Leios (CIP-164) raises throughput without changing Praos security.
A block producer may publish a larger endorser block next to its ordinary block.
A committee of stake pools certifies the endorser block, and a later ordinary block includes the certificate, which brings the endorsed transactions into the ledger.
It activates with the Dijkstra hard fork ([README.md](README.md)).

## Blocks

| Name | Meaning |
|---|---|
| RB (ranking block) | A Praos block, extended to announce one EB in its header and to carry one EB certificate in its body. |
| EB (endorser block) | Made by the same pool as its announcing RB. Lists transaction references (hash and size, in insertion order), plus the validity information the ledger needs for transactions that fail phase 2. |
| Closure | The transactions an EB references. |
| CertRB | An RB whose body carries a certificate for the EB announced by the previous RB. |
| TxRB | An RB that carries transactions directly. |

The research design had a third block type, input blocks; Linear Leios has none.
Transactions travel through the normal mempool, and EBs refer to them by hash.
An RB carries either a certificate or transactions, never both, so a CertRB body has no transactions of its own.
EBs should be announced only when transactions did not fit in the RB, and never empty.

## Flow

| Step | What happens |
|---|---|
| 1 | The leader makes an RB, optionally announcing an EB in its header, and the EB. |
| 2 | Nodes fetch the EB and any missing referenced transactions. Only structural checks are done before forwarding. |
| 3 | After `3 L_hdr` (equivocation detection), committee members validate the EB and vote for `L_vote`. |
| 4 | Votes of at least `τ` of the total active stake make the EB certified. |
| 5 | A later RB may include the certificate once it is at least `⌈(3 L_hdr + L_vote + L_diff) / slotLength⌉` slots after the announcing RB. If that RB is earlier, the EB is dropped. |

`L_hdr`, `L_vote` and `L_diff` are wall-clock durations; the single conversion to slots rounds up ([parameters](ledger/pparams.md)).
The Agda spec computes the delay as `certificationDelay` ([Leios.lagda.md](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Leios.lagda.md#L179)).

A member votes for an EB only when all hold: the RB header arrived within `L_hdr`; no equivocating header for the same slot was seen; the EB was validated in time; the EB is announced by the latest RB of the voter's chain; its transactions validly extend that RB; and it is not empty.

Security rests on two constraints: reapplying a certified EB costs less than ordinary transaction processing, and a certified EB can be transmitted before the RB that certifies it must be processed ([CIP-164, Protocol Security](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0164/README.md#protocol-security)).

## Ledger CDDL

```
header_body  += block_body_contains_leios_cert : bool
              , eb_references_announcement     : [eb_hash : hash32, eb_size : uint .size 4] / nil
block_body    = [transactions, leios_certificate / nil, peras_certificate / nil]
leios_certificate = [signers : bytes .size (0 .. 8192), signature : bytes .size 48]
```

`signers` is a bitfield over seat indices; `signature` is one aggregate BLS signature ([dijkstra.cddl](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl#L58)).
CIP-164 gives the equivalent header bit (`certified_eb` there) a purpose: a syncing node can predict the size of the EBs it must fetch.

## Votes, committee and certificate

- A vote names `announcing_rb_hash`, a `voter_id` (seat index) and a BLS signature over that hash.
  It carries no eligibility proof; eligibility is a lookup in the epoch's committee.
- The committee is the `N_c` pools with the most active stake at the epoch boundary, ties broken by ascending pool key hash.
  It is fixed for the epoch.
  A vote weighs the stake of its pool.
- A seat is a pool, its weight (share of total active stake) and an optional honoured BLS key ([pool-bls-key.md](ledger/pool-bls-key.md)).
  A keyless seat cannot sign.
- A certificate is valid for a message (the hash of the announcing RB header, taken from chain context) when every signer names a seat with a key, the aggregate signature verifies under those keys, and the signers' weights sum to at least `τ` of the total active stake, not of the seated stake.
- `τ` must exceed one half and stay below the stake share of the seated committee.
  `N_c` affects liveness, never validity.

Source: [Leios.lagda.md `selectCommittee`, `ValidEBCert`](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Leios.lagda.md#L146), [CIP-164 votes and certificates](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0164/README.md#votes-and-certificates).

## Ledger and chain selection

- Transaction rules are unchanged.
  Phase 1 and phase 2 apply equally to RB and EB transactions.
- EB transactions are validated against the ledger state before the certifying RB is applied, which is the state after the announcing RB (design requirement `REQ-LedgerUntickedEBValidation`).
- Applying the transactions of a certified EB needs a cheaper path than reapplying a transaction (`REQ-LedgerTxNoValidation`, `REQ-LedgerCheapReapply`).
- A CertRB is valid when its header and certificate are valid, and that can be judged before its EB arrives, because the committee comes from the forecast ledger view.
- Chain selection keeps the densest-chain rule.
  A chain with a CertRB counts as acquired only once the certified EB's closure is held.
- Per-EB limits are protocol parameters; per-transaction limits are unchanged.

Source: [Leios design, ledger and chain selection](https://github.com/input-output-hk/ouroboros-leios/blob/614b10d21691e40ed3a3e5a3462b08497fcfe443/docs/leios-design/README.md#chain-selection), [CIP-164 ledger management](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0164/README.md#ledger-management).

## Delivery to node-to-client consumers

Source: [#1114 design](https://github.com/input-output-hk/ouroboros-leios/blob/bbdd5060ea592fd058c646f4786a8811be7be407/docs/leios-design/README.md#node-to-client).

Requirements:

- `REQ-N2CBackwardCompatible`: an existing N2C client sees no Leios-specific format change, beyond the new era.
- `REQ-N2CInlineCertifiedEbs`: once an EB is certified on the node's selected chain, `LocalChainSync` delivers its transactions in the body of the RB that announced it, after that RB's own transactions.
  The ledger applies them there, not at the CertRB's slot.
- `REQ-N2CCertifiedOnly`: no N2C mini-protocol exposes transactions of an EB that is not certified on the selected chain.

The `LocalChainSync` server sends the CertRB unchanged.
In place of the announcing RB it sends RB⁺, the RB with the EB's transactions appended to its own.
Rules:

1.
   If the next block is already on the node's chain, send RB⁺ when that block certifies the EB, else RB. A client that catches up sees no extra rollback.
2.
   At the tip, the server sends RB first.
   If the CertRB then arrives, it rolls the client back to the parent of RB, then sends RB⁺ and the CertRB.
3.
   On a chain switch that changes whether RB's EB is certified, or when a client reconnects at an RB that announced an EB, it rolls back to the parent of RB and sends RB or RB⁺ again.
   Such rollbacks can reach k + 1 blocks.

Consequences for clients:

- At the tip there is one one-block rollback per CertRB. The block sent after the rollback has the same header hash as the one removed, so a client can recognise it.
- The header's `block_body_hash` covers only the on-chain body, so it does not match RB⁺; clients must not check it against RB⁺.
- RB⁺ can be far larger than any earlier block.

## Divergences

- CIP-164 "Clients" splices the EB's transactions into the certifying block (the CertRB).
  The #1114 design puts them into the announcing RB as RB⁺, because the ledger applies them there; #1114 lists rewriting that CIP section as a task.
- The Leios design says an EB carries validity information next to the transaction hashes; the CIP-164 text lists only `transaction_references`.
- CIP-164 names the header fields `announced_eb`, `announced_eb_size` and `certified_eb`.
  The ledger CDDL has `eb_references_announcement` and `block_body_contains_leios_cert`.

## References

- [CIP-164 Ouroboros Linear Leios](https://github.com/cardano-foundation/CIPs/blob/20776563ab75c3a9d8f61a0607dac05838e08025/CIP-0164/README.md): protocol design.
- [Leios technical design](https://github.com/input-output-hk/ouroboros-leios/blob/614b10d21691e40ed3a3e5a3462b08497fcfe443/docs/leios-design/README.md): node and ledger requirements.
- [#1114 design: node-to-client](https://github.com/input-output-hk/ouroboros-leios/blob/bbdd5060ea592fd058c646f4786a8811be7be407/docs/leios-design/node-to-client.md) and its [README](https://github.com/input-output-hk/ouroboros-leios/blob/bbdd5060ea592fd058c646f4786a8811be7be407/docs/leios-design/README.md#node-to-client): RB⁺.
- [Agda Leios](https://github.com/IntersectMBO/formal-ledger-specifications/blob/61946f5f31e61dcf5652df4a66a8680afa8996a7/src/Ledger/Dijkstra/Specification/Leios.lagda.md): committee, certificate, delay.
- [Dijkstra CDDL](https://github.com/IntersectMBO/cardano-ledger/blob/a6f303ade80b2f4729403861546db828a41e6408/eras/dijkstra/impl/cddl/data/dijkstra.cddl): header and body.
- [Intersect Dijkstra planning](https://product.cardano.intersectmbo.org/hardfork-planning/dijkstra/): Leios in the Dijkstra era.

## Ongoing work

- https://github.com/input-output-hk/ouroboros-leios/issues/1106
- https://github.com/input-output-hk/ouroboros-leios/pull/1114
- https://github.com/IntersectMBO/cardano-ledger/pull/6148
