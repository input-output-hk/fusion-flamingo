# Reddit post draft

For r/cardano or r/CardanoDevelopers.
Reddit culture notes: no emojis, no marketing voice, and answer questions in the comments quickly after posting.
The Ogmios/Kupo coexistence paragraph was dropped from the body on 2026-09-17; expect that question as an early comment and answer it from the counterargument prep in [announcement.md](announcement.md) (the forum post's coexistence section is the template).

---

Title: cardano-node now speaks UTxO RPC: typed, streaming chain data straight from the node

**cardano-node can now serve typed, streaming chain data over gRPC**, from the node process itself, with nothing else to deploy. The interface is called **cardano-rpc**, it has been growing inside the node since version 10.7.0, and we just published its first proper introduction on the Cardano forum.

What you get today:

- chain queries: protocol parameters, UTxOs by address, genesis, era summary
- transaction submission and evaluation
- chain sync: read the tip, fetch blocks, follow the chain live

`FollowTip` is the one to try first: a single long-lived call that streams fully parsed blocks as the chain advances, rollbacks included.

**Try it.** One nix command starts a [local testnet](https://github.com/IntersectMBO/cardano-node/tree/master/cardano-testnet#readme) with the gRPC server enabled:

    nix run 'github:IntersectMBO/cardano-node#cardano-testnet' -- \
      cardano --num-pool-nodes 1 --enable-grpc-http --grpc-listen-port-base 50051 --output-dir /tmp/demo-cluster

Then, from a second terminal with [grpcurl](https://github.com/fullstorydev/grpcurl) on PATH:

    grpcurl -plaintext localhost:50051 list
    grpcurl -plaintext -d '{}' localhost:50051 utxorpc.v1beta.sync.SyncService/FollowTip

The server supports gRPC reflection, so grpcurl works without any proto files. There are [quickstarts](https://github.com/IntersectMBO/cardano-api/tree/master/cardano-rpc#quickstart) for Go, Haskell, Python, Rust and TypeScript.

Full announcement with more background: [forum post](https://forum.cardano.org/t/cardano-node-now-speaks-utxo-rpc-typed-streaming-chain-data-straight-from-the-node/156854)

Happy to answer questions here.
