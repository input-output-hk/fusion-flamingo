# cardano-rpc adoption campaign

Working notes from the outreach research session of 2026-09-03/04.
Goal: get real projects consuming cardano-rpc, the UTxO RPC (u5c) gRPC server embedded in cardano-node.

## Takeaways

1. Blockfrost is the highest-value target.
   Their new Rust platform hand-rolls the exact node interface cardano-rpc provides, and they are building it right now.
   See [blockfrost.md](blockfrost.md).
2. Lace is an indirect target.
   It consumes Blockfrost through an IOG proxy and runs no chain infrastructure of its own, so the pitch there is awareness, not adoption.
   See [lace.md](lace.md).
3. `WaitForTx` is the single most valuable missing method.
   It blocks MeshJS and Evolution SDK adoption and underpins the wallet confirmation UX argument.
   Update 2026-09-16: implemented on draft PR [cardano-api#1222](https://github.com/IntersectMBO/cardano-api/pull/1222) (node kernel access), not yet merged.
   See [sdks.md](sdks.md) and [cardano-rpc-status.md](cardano-rpc-status.md).
4. Corrected 2026-09-16: cardano-rpc HAS shipped (the earlier "not in any release" claim was wrong).
   Experimental since cardano-node 10.7.0 (2026-03-25); cardano-node 11.1.1 (2026-09-08) ships cardano-rpc 11.2.0.0 with the current u5c method set.
   The release prerequisite for adoption conversations is met; the remaining production caveats are the EXPERIMENTAL flag and breaking changes between releases.
5. cardano-sieve is the natural indexer complement and an internal dogfooding target.
   Issue filed: <https://github.com/IntersectMBO/cardano-sieve/issues/4>.
   See [ecosystem.md](ecosystem.md).

## Next actions

1. Send the Marek (Blockfrost) Slack message (messages.md was removed from this directory on or before 2026-09-10; sent status unknown, confirm with Mateusz).
2. Send the Lace FYI message, or park it until mempool support ships.
3. Decide whether `WaitForTx` jumps the roadmap queue in [cardano-api#1302](https://github.com/IntersectMBO/cardano-api/issues/1302).
4. Draft the developer forum announcement: strategy in [announcement.md](announcement.md).
5. Get cardano-rpc listed as a server on <https://utxorpc.org/servers/> (it is absent as of 2026-09-16; Dolos, Blink Labs' Node API and Demeter are listed).
6. Optional: contact Santiago Carmuega (TxPipe/Demeter) and Pi Lanningham (Amaru mempool owner) about u5c alignment.

## Files

- [cardano-rpc-status.md](cardano-rpc-status.md): what cardano-rpc implements today, gaps ranked, bugs found.
- [blockfrost.md](blockfrost.md): Blockfrost's two stacks and the fit analysis.
- [lace.md](lace.md): how Lace gets chain data and why it is a weak direct target.
- [sdks.md](sdks.md): MeshJS and Evolution SDK gap analyses.
- [ecosystem.md](ecosystem.md): other u5c servers, Amaru, Demeter, cardano-sieve, Ogmios/Kupo positioning context.
- [announcement.md](announcement.md): forum announcement strategy, fact-checked claims, counterargument prep.

Removed since 2026-09-04: quickstart-draft.md (superseded by the in-repo `cardano-rpc/quickstart/`, shipped on cardano-api master plus PRs #1341/#1342) and messages.md.
