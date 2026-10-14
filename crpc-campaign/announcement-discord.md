# Discord announcement draft

Discord variant of the Slack companion post (published forum thread linked at the end).
Discord formatting: double-asterisk bold, Unicode emoji (paste-safe; Discord also accepts :shortcodes: but converts them only on send).

---

🚀 **cardano-node now speaks UTxO RPC**: typed, streaming chain data over gRPC, straight from the node, nothing else to deploy.

The new interface is called **cardano-rpc**. It implements the open UTxO RPC spec that the ecosystem's SDKs and data servers already support, so the same client code works across implementations. You can query the chain, submit and evaluate transactions, and follow the tip live: 📡 `FollowTip` streams every new block to you as the chain grows.

⚡ Trying it takes minutes: one `nix run` command starts a local testnet with gRPC on, and `grpcurl` works against it out of the box. Quickstarts are there for Go, Haskell, Python, Rust and TypeScript. 🛠️ And because it ships inside the node, hard fork support arrives with the node itself, never behind it.

👉 Full announcement with the try-it commands: https://forum.cardano.org/t/cardano-node-now-speaks-utxo-rpc-typed-streaming-chain-data-straight-from-the-node/156854 Feedback very welcome! 💬
