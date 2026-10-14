# Forum announcement draft

Paste-ready body for forum.cardano.org (developers category); strategy and fact-check table in [announcement.md](announcement.md).
Post body paragraphs are single lines because Discourse renders every newline as a line break.

Fill in before posting:

1. Earliest supported commit is e95d55ed94 (node master, 2026-09-16, merge of PR #6679): it bumps the node to cardano-rpc ^>=11.4, the first CHaP release with gRPC reflection, so `nix run` on latest master serves the whole Try-it flow, reflection included (resolved 2026-09-17; the earlier "reflection is in no node build" caveat is obsolete).
   Before posting: re-run the Try-it commands against a fresh cluster.
   The testnet command and grpcurl calls mirror `cardano-rpc/README.md`; keep them in sync with it.
2. Pin the quickstart link to the release tag instead of master when known, and confirm all five languages (go, haskell, python, rust, typescript) are in that release; some come from PRs #1341/#1342 and the local branch, not master.
3. Open decisions from [announcement.md](announcement.md): pre-brief Benkort; whether to wait for the SDK v1alpha fix (utxorpc/spec#209) so the post can say "point your existing provider at it".
4. Two-link cap: the account can post at most 2 links, so the body carries exactly two (quickstart root dir, cardano-api issues). Everything else stays plain text; mind that Discourse autolinks bare URLs and bare domains (like the spec site), which would count as extra links.

---

Title: cardano-node now speaks UTxO RPC: typed, streaming chain data straight from the node

cardano-node can now serve typed, streaming chain data over gRPC, from the node process itself, with nothing else to deploy. The interface is called cardano-rpc and it has been growing inside the node since version 10.7.0. It is now ready to build against, so here is what it does and how to try it in a few minutes.

**What it is**

cardano-rpc is a gRPC server compiled into the node itself. It implements the open UTxO RPC spec (v1beta), the same interface Dolos (TxPipe), Dingo (Blink Labs) and Demeter's hosted endpoints already serve. It is off by default; one line in the node configuration, `EnableRpc: true`, turns it on.

Implemented so far:

- Query: `ReadParams`, `ReadUtxos`, `SearchUtxos` (by address), `ReadGenesis`, `ReadEraSummary`
- Submit: `SubmitTx`, `EvalTx`
- Sync: `ReadTip`, `FollowTip`, `FetchBlock`

`FollowTip` is the one to try first: a single long-lived call that streams fully parsed blocks as the chain advances, rollbacks included.

It listens on a unix socket by default, or on TCP and TLS via `--grpc-listen-port` and `--grpc-tls-certificate`. The server supports gRPC reflection, so `grpcurl` and `grpcui` just work, without any proto files.

**Try it**

One nix command starts a local testnet with the gRPC server enabled:

```
nix run 'github:IntersectMBO/cardano-node#cardano-testnet' -- \
  cardano --num-pool-nodes 1 --enable-grpc-http --grpc-listen-port-base 50051 --output-dir /tmp/demo-cluster
```

The cluster is ready once it logs `gRPC endpoint of node1: http://127.0.0.1:50051`, typically under a minute once binaries are cached (full usage guide in cardano-testnet's README in the cardano-node repo). Then, from a second terminal with grpcurl on PATH (`nix shell 'nixpkgs#grpcurl'` works), list the services and read the chain tip:

```
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext localhost:50051 utxorpc.v1beta.sync.SyncService/ReadTip
```

And to watch blocks arrive live, follow the tip; the stream prints every new block as the chain grows, until you press Ctrl+C:

```
grpcurl -plaintext -d '{}' localhost:50051 utxorpc.v1beta.sync.SyncService/FollowTip
```

On your own node, the same server is enabled with `EnableRpc: true` in the node configuration; that needs cardano-node built from master at commit `e95d55ed94` or newer (for gRPC reflection support).

From there, pick your language: the [quickstarts](https://github.com/IntersectMBO/cardano-api/tree/master/cardano-rpc#quickstart) for Go, Haskell, Python, Rust and TypeScript take you the rest of the way.

**Why build it into the node**

UTxO RPC is a community specification. It came out of TxPipe's Catalyst Fund 11 work, Dolos is its reference implementation, and there are already servers from TxPipe, Blink Labs and Demeter, client SDKs in five languages, and providers in MeshJS, Lucid Evolution and Blaze. cardano-rpc adds the node itself to that list.

Anyone who wants typed data out of a Haskell node either runs a bridge process next to it or hand-rolls the node-to-client mini-protocols. Every infrastructure provider we have talked to maintains some version of that layer themselves. Now the node offers one out of the box: a typed protobuf interface served straight from the node process.

If you have ever patched your own node integration in a hurry at a hard fork because it did not know the new era yet, this is the gap that closes: cardano-rpc is built on cardano-api, so era handling, CBOR, ledger queries, transaction evaluation and submission come from the same libraries the node uses. A new era becomes a compile error in the gRPC layer before the release can ship; hard fork support cannot lag behind the node's.

**What about Ogmios, Kupo and Dolos?**

cardano-rpc covers much of the same ground as Ogmios: typed queries, transaction submission and chain following against a local node. If it fits your stack, your deployment gets simpler: one process fewer to run and upgrade. It is not a drop-in swap, though: cardano-rpc speaks UTxO RPC rather than Ogmios' JSON-RPC, so moving over is a client-side change too, and Ogmios deployments keep working exactly as they do today; nothing here deprecates Ogmios or Kupo. And the shared spec is where it gets good: Dolos and the other UTxO RPC servers implement the same interface, so the same client code works against any of them, and you pick the server that fits your deployment.

cardano-rpc also stays out of indexer territory on purpose. Searches by credential or asset need a secondary index, so they belong in indexers; the node serves the data it already has.

**Known gaps and what is next**

The published MeshJS and Evolution SDK providers cannot reach cardano-rpc yet: the upstream @utxorpc packages they build on still export only the older v1alpha API. The fix is merged upstream (utxorpc/spec#209) and waiting on a release; until it ships, the quickstarts and `grpcurl` are the way in.

If you run infrastructure, build SDKs or maintain a dApp backend, we would love to hear what you need from this interface: in the thread below, or as issues on [IntersectMBO/cardano-api](https://github.com/IntersectMBO/cardano-api/issues).
