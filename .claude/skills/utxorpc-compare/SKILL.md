---
name: utxorpc-compare
description: Compare cardano-rpc's UTxO RPC implementation against other servers (Dolos, Blink Labs, Ogmios) to check for correctness and spec conformance.
---

Compare cardano-rpc's UTxO RPC implementation with other existing implementations to check for correctness, spec conformance, and behavioural differences.

The user provides a method or feature name (e.g. "EvalTx", "SubmitTx", "ReadParams").

## Known UTxO RPC implementations

### Dolos (TxPipe) - Rust
- Repository: https://github.com/txpipe/dolos
- gRPC handlers: `src/serve/grpc/v1alpha/submit.rs`, `src/serve/grpc/v1alpha/query.rs`
- Validation logic: `crates/cardano/src/validate.rs`
- Uses pallas for ledger validation (phase 1 + phase 2).
- EvalTx runs full phase 1 validation (including balance check) before phase 2 script evaluation.

### Blink Labs cardano-node-api - Go
- Repository: https://github.com/blinklabs-io/cardano-node-api
- gRPC handlers: `internal/utxorpc/submit.go`, `internal/utxorpc/query.go`
- Thin wrapper around Ouroboros mini-protocols.
- EvalTx is not implemented as of 2026-05.

### Demeter.run - Rust proxy
- Repository: https://github.com/blinklabs-io/demeter-ext-cardano-utxorpc
- Auth proxy that forwards to upstream UTxO RPC (typically Dolos).
- No own evaluation logic.

### Ogmios (not UTxO RPC, but reference for Cardano tx evaluation)
- Repository: https://github.com/CardanoSolutions/ogmios
- `evaluateTransaction` explicitly does NOT require a balanced tx.
- Skips phase 1 validation, goes straight to script evaluation.
- Supports `additionalUtxoSet` for resolving inputs not yet on-chain.

## UTxO RPC spec
- Repository: https://github.com/utxorpc/spec
- Proto files: `proto/utxorpc/v1beta/submit/submit.proto`, `proto/utxorpc/v1beta/cardano/cardano.proto`
- The spec is generally silent on validation requirements - it defines message shapes but leaves behaviour to implementations.

## Procedure

1. Identify the method or feature the user wants compared.
2. Fetch the relevant source from each implementation using `gh api` or `WebFetch` on the raw GitHub URLs.
   Focus on the handler function and any validation/conversion logic it calls.
3. Compare against cardano-rpc's implementation in `/work/cardano-api/cardano-rpc/src/Cardano/Rpc/Server/`.
4. Report:
   - What each implementation does (or doesn't do).
   - Where cardano-rpc differs and whether the difference is intentional or a potential issue.
   - Whether the UTxO RPC spec says anything about the expected behaviour.
   - Any edge cases one implementation handles that others don't.

## Important notes
- Dolos is the most complete alternative implementation and the primary comparison target.
- Ogmios is not UTxO RPC but is the de facto standard for Cardano tx evaluation - always include it when comparing evaluation-related features.
- The spec is often silent on semantics, so "spec conformance" mostly means message shape conformance. Behavioural correctness should be judged against Cardano ledger rules and practical client needs.
- Check the upstream spec PR linked in cardano-rpc PRs (if any) for context on proto changes.
