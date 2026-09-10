# Blockfrost

Primary outreach target.
Contact: Marek (CEO); message drafted in [messages.md](messages.md).

## Their two stacks

The legacy stack, live at blockfrost.io today, is a Node.js API reading from cardano-db-sync and PostgreSQL.
It needs 64GB boxes and their own issues document the pain: expensive address balance queries, forced resyncs on schema changes, sync times measured in days.

The new stack, `blockfrost-platform` (Rust, rolling out through their Icebreakers SPO programme), drops db-sync.
Live queries and tx submission talk to cardano-node directly over node-to-client using Pallas, TxPipe's Rust reimplementation of the Ouroboros mini-protocols (local-state-query and local-tx-submission only).
Historical and indexed data comes from an optional Dolos instance over REST.
A gateway crate routes requests across a fleet of operator-run nodes.

## Why cardano-rpc fits

Their Rust node layer reimplements exactly what cardano-rpc serves, and Pallas has to chase every era and protocol change by hand.
Dolos already speaks u5c, so one protocol could cover both their node access and their data node.
They have no mempool visibility at all today; cardano-rpc's planned mempool methods would be net-new capability for them.

## Gaps before they could adopt

See [cardano-rpc-status.md](cardano-rpc-status.md) for detail.

1. A cardano-node release containing cardano-rpc.
2. `ReadState` for pool, account and governance queries.
3. The hardcoded `GetEra` stub fixed.

Historical data stays on Dolos either way; that split is fine and matches their architecture.

## Note on Lace

Lace rides entirely on Blockfrost (see [lace.md](lace.md)), so winning Blockfrost indirectly covers Lace.
IOG is very likely a paying Blockfrost customer for Lace, which is leverage in the conversation.
