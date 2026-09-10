---
name: rpc-http-port-failure-detection
description: cardano-testnet's retryOnAddressInUseError cannot catch a bind failure on the node's gRPC HTTP port; the failure is silently swallowed inside cardano-node
metadata:
  type: project
---

`cardano-testnet`'s node-startup retry mechanism only works for failures the
node process reports on stderr. `Testnet.Runtime.startNode` races
`waitForProcess` against `Ping.waitForSprocket` (waiting for the N2C unix
socket file), then treats ANY non-empty stderr content as fatal, classifying
it as `NodeAddressAlreadyInUseError` via a substring match on "Address
already in use" (`Testnet/Runtime.hs` `mkNodeNonEmptyStderrError`).
`Testnet.Start.Cardano.retryOnAddressInUseError` retries the same `startNode`
action (same args, same ports) on that specific error, on the assumption the
conflict is a transient TIME_WAIT from a prior run reusing the same
`H.randomPort`-allocated port.

This mechanism has NO reach into `cardano-node`'s gRPC/RPC server: in
`cardano-node/src/Cardano/Node/Run.hs`, the RPC server loop is started as
`withAsync (rpcServerLoop ...) $ \_ -> Node.run ...` with the async handle
discarded (no `link`, no `wait`). `async`'s `withAsync` wraps the action in
`try` internally, so an uncaught exception in the child thread (e.g. a
`bind` failure -- "Address already in use" -- when the gRPC HTTP listener's
port collides with something else) is captured into an unconsumed result
`MVar`, never rethrown, and never printed by GHC's per-thread uncaught
exception reporter. The main node process keeps running normally, with no
stderr output and no non-zero exit, and `startNode` returns `Right` (node
"started"). See also `rpcServerLoop`'s own doc-comment: "If the server exits
without a config change (crash or fatal error), disable RPC" -- confirms the
loop treats a server crash as an expected, silently-handled event, not
something meant to surface to the process's caller.

Consequence: any component whose actual liveness depends on a port/resource
that only cardano-node's RPC subsystem binds (as of 2026-09-09, the
`--enable-grpc-http` HTTP listener added in `Testnet/Start/Cardano.hs`, via
`H.randomPort testnetDefaultIpv4Address` inside the per-node
`forConcurrently` loop) has NO detection or retry path if that random port
collides with something else -- unlike the main N2C `port`, which IS probed
(`Ping.waitForSprocket`) and DOES have working retry semantics. A collision
here produces a `TestnetNode` that looks started successfully but has a dead
gRPC endpoint; a test hitting it will fail at connect/RPC-call time with a
generic, hard-to-diagnose error, not at startup.

**Why:** discovered reviewing the `--enable-grpc-http` PR (mgalazyn/update
branch, 2026-09-09) after tracing why `retryOnAddressInUseError`'s "same
port across retries" behavior -- correct for the main N2C port because
topology files reference it and its failure mode is TIME_WAIT self-healing
-- would NOT actually protect the new RPC HTTP port at all, because the
failure never reaches the retry mechanism in the first place.

**How to apply:** when reviewing any new cardano-testnet feature that adds a
`H.randomPort`-allocated port consumed by something other than the main N2C
listener, check whether the testnet harness has an explicit
readiness/connectivity probe for that specific service (like
`Ping.waitForSprocket` for N2C). If it doesn't, `retryOnAddressInUseError`
gives ZERO protection for that port -- a stderr-silent bind failure inside
cardano-node is possible for any subsystem started via a discarded
`withAsync` handle. The general "port allocation" review checklist item
should always ask "does a bind failure on THIS port actually surface to the
test harness," not just "is the port allocated randomly and retried on
conflict."
