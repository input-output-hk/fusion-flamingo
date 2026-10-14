---
name: rio-monadfail-production-path
description: RIO's RIO env monad has a MonadFail instance that bottoms out in IO's raw fail; a MonadFail constraint on a function reachable from the real CLI (not just Hedgehog tests) is a genuine "fail in IO" violation
metadata:
  type: reference
---

`rio-0.1.24.0`'s `RIO env` newtype derives `Control.Monad.Fail.MonadFail` (via `ReaderT env IO`), which threads through to `IO`'s own instance: `fail = ioError . userError`. `ResourceT (RIO env)` inherits it too.

So when a cardano-testnet library function carries a `MonadFail m` constraint (e.g. to cover an incomplete-pattern `[x] <- action` do-bind), check where it's actually *instantiated*, not just where it's used in tests. In cardano-testnet, `Parsers/Run.hs`'s `runCardanoOptions` runs `cardanoTestnet`/`createAndRunTestnet` as `runSimpleApp . runResourceT $ ...` - i.e. `m ~ ResourceT (RIO SimpleApp)` - which is the real `cardano-testnet` CLI binary's production path, with no Hedgehog involved. A `MonadFail`-triggered pattern-match failure there surfaces as a bare "Pattern match failure in do expression" `IOError`, not a descriptive `throwString`.

This directly matches [[feedback_no_fail_io]] (private memory: never use `fail` in IO, always throw explicit exceptions) - but the violation is only visible by tracing the constraint to its concrete instantiation across module boundaries, not by reading the function in isolation. Caught on cardano-node PR #6710 (`Testnet/CardanoTracer.hs:96`, the "MonadFail" fixup commit b39404f papering over a partial `head` call with `[prometheusPort] <- ...` instead of an explicit `case`/`throwString`).
