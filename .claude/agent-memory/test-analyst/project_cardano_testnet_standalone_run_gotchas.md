---
name: project-cardano-testnet-standalone-run-gotchas
description: how to run the cardano-testnet binary standalone (outside cabal test) without hitting unrelated setup failures
metadata:
  type: project
---

Learned 2026-09-09 running `cabal list-bin cardano-testnet`'s output directly (e.g. for smoke-testing a CLI feature outside the hedgehog test suite).

- **Needs `CARDANO_CLI` and `CARDANO_NODE` env vars** when run from a CWD that has no `dist-newstyle` above it (e.g. a scratch/tmp dir). The binary's exec-flex resolution otherwise tries to find `dist-newstyle/cache/plan.json` relative to CWD and fails with "Could not find plan.json in the path". Get both paths from `/work` via `cabal list-bin cardano-cli` and `cabal list-bin cardano-node:exe:cardano-node`, export both before invoking.
- **The default workspace directory can exceed the AF_UNIX 108-byte path limit** if run from a deeply-nested CWD (e.g. this environment's scratchpad, which is `/tmp/claude-<pid>/-work/<uuid>/scratchpad/...`). Symptom: `pokeSockAddr: path is too long in SockAddrUnix ".../testnet/./socket/node3/sock", length 115, unixPathMax 108`, thrown from `Testnet.Ping` during node startup - unrelated to whatever feature is under test. Fix: pass `--output-dir <short-path>` (e.g. `/tmp/rpc-smoke/testnet`) to keep the derived socket paths short.
- **A mid-startup crash orphans already-started nodes.** `interruptNodesOnSigINT` (near the end of `cardanoTestnet` in `Testnet/Start/Cardano.hs`) is only wired up after ALL nodes have started; if node N fails, nodes 1..N-1 keep running with no signal handler and leak indefinitely as orphans (ppid 1) after the parent throws. Always check `ss -tlnp` / `pgrep -af cardano-node` for leftovers after ANY crashed standalone run, not just after a clean one, and kill them by PID before reusing the same ports.
- **The gRPC TCP readiness probe checks port connectivity, not process identity.** `Ping.waitForTcpPort` (called from `Testnet/Start/Cardano.hs:403-411`) just does a TCP connect; if a stale/orphaned process from a previous crashed run is already listening on the target port, the probe reports success even though the CURRENT run's own node may have failed to bind (EADDRINUSE) - and per an existing code comment, cardano-node swallows a gRPC bind failure silently (no stderr, exit 0). Caught this by cross-referencing `ss -tlnp`'s reported PID against each process's cmdline (must reference the current run's workspace path) before trusting a "port is up" result. Always do this cross-reference after any prior crash in the same session, even if ports "look" free from curl alone.

**Why:** These cost ~30 minutes of confused debugging distinguishing environment noise from a real product bug during RPC-over-HTTP smoke testing. See [[project_rpc_http_grpc_banner_bug]] for the actual bug found once these were ruled out.

**How to apply:** Before reporting a standalone cardano-testnet run's port/process checks as clean, always verify port ownership by PID+cmdline, not just "something answered curl/connect".
