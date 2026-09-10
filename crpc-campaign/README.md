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
   See [sdks.md](sdks.md) and [cardano-rpc-status.md](cardano-rpc-status.md).
4. cardano-rpc has not shipped in any cardano-node release.
   Nobody can adopt it in production until it does.
   That is the first prerequisite for every conversation below.
5. cardano-sieve is the natural indexer complement and an internal dogfooding target.
   Issue filed: <https://github.com/IntersectMBO/cardano-sieve/issues/4>.
   See [ecosystem.md](ecosystem.md).

## Next actions

1. Send the Marek (Blockfrost) Slack message: [messages.md](messages.md).
2. Send the Lace FYI message, or park it until mempool support ships.
3. Decide whether `WaitForTx` jumps the roadmap queue in [cardano-api#1302](https://github.com/IntersectMBO/cardano-api/issues/1302).
4. Optional: contact Santiago Carmuega (TxPipe/Demeter) and Pi Lanningham (Amaru mempool owner) about u5c alignment.

## Files

- [cardano-rpc-status.md](cardano-rpc-status.md): what cardano-rpc implements today, gaps ranked, bugs found.
- [blockfrost.md](blockfrost.md): Blockfrost's two stacks and the fit analysis.
- [lace.md](lace.md): how Lace gets chain data and why it is a weak direct target.
- [sdks.md](sdks.md): MeshJS and Evolution SDK gap analyses.
- [ecosystem.md](ecosystem.md): other u5c servers, Amaru, Demeter, cardano-sieve.
- [quickstart-draft.md](quickstart-draft.md): draft quickstart for `cardano-rpc/README.md`, with open verification items.
