# Slack announcement draft

Short companion post pointing at the forum announcement (published 2026-09-17).
Slack formatting (single-asterisk bold, emoji codes).

---

:rocket: *cardano-node now speaks UTxO RPC*: typed, streaming chain data over gRPC, straight from the node, nothing else to deploy.

The new interface is called *cardano-rpc*. It implements the open UTxO RPC spec that the ecosystem's SDKs and data servers already support, so the same client code works across implementations. You can query the chain, submit and evaluate transactions, and follow the tip live: :satellite: `FollowTip` streams every new block to you as the chain grows.

:zap: Trying it takes minutes: one `nix run` command starts a local testnet with gRPC on, and `grpcurl` works against it out of the box. Quickstarts are there for Go, Haskell, Python, Rust and TypeScript. :hammer_and_wrench: And because it ships inside the node, hard fork support arrives with the node itself, never behind it.

:point_right: Full announcement with the try-it commands: https://forum.cardano.org/t/cardano-node-now-speaks-utxo-rpc-typed-streaming-chain-data-straight-from-the-node/156854 Feedback very welcome! :speech_balloon:
