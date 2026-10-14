# cardano-rpc

Domain knowledge about the cardano-rpc gRPC server, moved out of AGENTS.md.

- Haskell gRPC server embedded in cardano-node via UTxO RPC spec.
- Currently uses Node-to-Client IPC (one connection per request, double serialisation).
  Planned: node kernel access - in-process access to `NodeKernel` (ChainDB, Mempool, Config) replacing N2C IPC (ADR-019).
- Roadmap: UTxORPC parity, conformance tests, node kernel access, HTTP endpoint, streaming (ChainSync), governance/stake queries, ecosystem tooling.
- Key ADRs: ADR-018 (architecture), ADR-019 (node kernel access) in cardano-node-wiki/docs/.
- Design docs and stories: `cardano-rpc/docs/node-kernel-access/` exists ONLY on the unmerged cardano-api branch `mgalazyn/feature/node-kernel-access` (its "spec" commit), NOT on master (verified 2026-09-03) - on master, the ADRs above are the only design docs.
- **`google.protobuf.FieldMask` is deliberately unimplemented across cardano-rpc** (decided 2026-09-22): every mask-carrying request is accepted and ignored (full response). A flat-top-level-paths-only implementation for WatchMempool was extracted into the parked commit "Support field mask in WatchMempool method" on the node-kernel-access branch, pending a proper cross-service design (path normalisation, nested paths, INVALID_ARGUMENT on unknown paths - a parked sketch sits commented out in `Server/Internal/UtxoRpc/Query.hs` near `readParamsMethod`). Don't add per-method mask handling ad hoc; when that commit ships as a PR it needs its own new herald fragment.
