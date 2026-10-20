# cardano-rpc

Domain knowledge about the cardano-rpc gRPC server, moved out of AGENTS.md.

- Haskell gRPC server embedded in cardano-node via UTxO RPC spec.
- Currently uses Node-to-Client IPC (one connection per request, double serialisation).
  Planned: node kernel access - in-process access to `NodeKernel` (ChainDB, Mempool, Config) replacing N2C IPC (ADR-019).
- Roadmap: UTxORPC parity, conformance tests, node kernel access, HTTP endpoint, streaming (ChainSync), governance/stake queries, ecosystem tooling.
- Key ADRs: ADR-018 (architecture), ADR-019 (node kernel access) in cardano-node-wiki/docs/.
- Design docs and stories: `cardano-rpc/docs/node-kernel-access/` exists ONLY on the unmerged cardano-api branch `mgalazyn/feature/node-kernel-access` (its "spec" commit), NOT on master (verified 2026-09-03) - on master, the ADRs above are the only design docs.
- **`google.protobuf.FieldMask` is deliberately unimplemented across cardano-rpc** (decided 2026-09-22): every mask-carrying request is accepted and ignored (full response). A flat-top-level-paths-only implementation for WatchMempool was extracted into the parked commit "Support field mask in WatchMempool method" on the node-kernel-access branch, pending a proper cross-service design (path normalisation, nested paths, INVALID_ARGUMENT on unknown paths - a parked sketch sits commented out in `Server/Internal/UtxoRpc/Query.hs` near `readParamsMethod`). Don't add per-method mask handling ad hoc; when that commit ships as a PR it needs its own new herald fragment.

## grapesy gotchas
- **grapesy 1.2.0 throws `GrpcException GrpcCancelled` to the client when a `serverStreaming` callback returns while the server stream is still open** (`closeRPC` in `Network.GRPC.Client.Call`, run in the `withRPC` release step after the callback returned; changelog #372).
  grapesy 1.1.1 stayed silent there because the client had already sent its final message; the 1.2.0 `withRPC` Haddock still describes the old behaviour.
  There is no cancel API, so a test that stops reading a never-ending stream (FollowTip, WatchMempool) must handle `GrpcCancelled`, and the callback result is lost unless saved before the exception.
  cardano-node resolves 1.2.0 from hackage index-state 2026-09-02T14:05:07Z (PR IntersectMBO/cardano-node#6677, verified 2026-10-16).

## Gotchas
- **SubmitTx failures reach clients with gRPC status `Unknown`**: `Submit.hs` throws via `throwEither`/`RpcException` and never calls `throwGrpcErrorWithMessage`, unlike Eval, Query and Sync.
  A ledger rejection shows in grpcurl as `Code: Unknown`, `Message: Failed to submit transaction: ...` with exit code 66 (observed 2026-10-19 on cardano-node master 4d3ad249).
- **SubmitTx decodes the tx only in the node's current era** (`determineEra`, then `deserialiseFromCBOR` for that era), while cardano-submit-api accepts every Shelley-based era.
- **RPC over TCP (`RpcListenPort`, cardano-node commit 9f25b2c126, 2026-08-28) is in no cardano-node release tag as of 2026-10-19 (newest 11.1.3)**; Unix-socket RPC (`--grpc-enable`) is in 10.7.0 and later.
