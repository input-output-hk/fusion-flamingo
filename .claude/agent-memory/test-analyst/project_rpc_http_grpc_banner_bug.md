---
name: project-rpc-http-grpc-banner-bug
description: cardano-testnet standalone CLI's gRPC endpoint startup banner - was dead code, fixed 2026-09-09
metadata:
  type: project
---

FIXED as of 2026-09-09. Originally found the same day while smoke-testing the new `RpcEnabledHttp`/`--grpc-listen-ports` feature on `mgalazyn/update` (cardano-node submodule): running `cardano-testnet cardano --enable-grpc-http --grpc-listen-ports <ports>` as a standalone binary never printed the expected `gRPC endpoint of <node>: http://127.0.0.1:<port>` banner lines.

Original root cause: the banner (`putStrLn "gRPC endpoint of %s: ..."`) lived only in `Testnet.Property.Run.runTestnet` (cardano-testnet/src/Testnet/Property/Run.hs:100-102), a function with zero callers anywhere in the repo. The actual standalone CLI path, `runCardanoOptions` in `Parsers/Run.hs`, never touched it.

**Fix verified 2026-09-09**: the team moved the endpoint logging into the live CLI path itself - `runCardanoOptions` in `Parsers/Run.hs` now emits it via RIO `logInfo` right after "Testnet started", in both the `NoUserProvidedEnv` and `StartFromEnv` branches. Re-ran the standalone happy-path smoke test after the fix (`cardano-testnet cardano --output-dir /tmp/rpc-smoke/testnet --enable-grpc-http --grpc-listen-ports 7301,7302,7303`) and got exactly:
```
Testnet started
gRPC endpoint of node1: http://127.0.0.1:7301
gRPC endpoint of node2: http://127.0.0.1:7302
gRPC endpoint of node3: http://127.0.0.1:7303
Waiting for shutdown (Ctrl+C)
```
Cross-checked port ownership via `ss -tlnp` against each PID's cmdline to confirm these were genuinely this run's own nodes, not stale squatters (see [[project_cardano_testnet_standalone_run_gotchas]] for why that check matters).

**Why:** Keeping this record so a future session doesn't waste time re-discovering or re-reporting the same defect - it's fixed and verified, not a live issue.

**How to apply:** If this regresses again, the fix location is `runCardanoOptions` in `cardano-testnet/src/Parsers/Run.hs` (RIO `logInfo`, uses `displayShow`/`fromString`, `Testnet.Types (NodeRpcEndpoint (..), TestnetNode (..))`, `Cardano.Api.IO (unFile)`, `forM_`) - check there first before assuming it moved back to the dead `Testnet.Property.Run.runTestnet` path.
