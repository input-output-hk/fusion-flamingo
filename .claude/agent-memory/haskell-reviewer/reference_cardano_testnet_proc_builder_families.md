---
name: cardano-testnet-proc-builder-families
description: cardano-testnet has two parallel families of proc* process builders - RIO-based (production CLI path) and MonadTest-based (Hedgehog test-only) - don't expect a function in one family to be reachable from the other
metadata:
  type: reference
---

cardano-testnet keeps two separate `proc*`/`procFlex`-style builder families, and they are NOT interchangeable:

- `Testnet.Process.RunIO.procFlex :: HasCallStack => String -> String -> [String] -> RIO env CreateProcess` (plus `procFlex'`/`procCustom'`/`procCustom`) - no `MonadTest`, usable from genuinely production code that also runs via `runSimpleApp . runResourceT` outside any Hedgehog property (e.g. `Testnet.Start.Cardano.cardanoTestnet`, the real CLI entrypoint's call chain).
- `Testnet.Process.Run.procSubmitApi` / `procChairman` / `procCardanoTracer` etc. - signature `(MonadTest m, MonadCatch m, MonadIO m, HasCallStack) => [String] -> m CreateProcess`, built on `Hedgehog.Extras`'s own `H.procFlex`; these only work inside a Hedgehog `PropertyT`/`Integration` context (test code).

A library function (in `src/`, not `test/`) that needs to run both inside tests AND from the plain CLI binary (like `Testnet.CardanoTracer.startCardanoTracer`) must use the RIO-based family - it cannot have a `MonadTest` constraint. If you see a new `proc*` added to `Testnet/Process/Run.hs` for something that's actually driven from `src/`, check whether it is ever called: it may be genuinely dead, added to the wrong family. Caught on cardano-node PR #6710, where a new `procCardanoTracer` in `Process/Run.hs` was added but never called anywhere - `startCardanoTracer` correctly uses `Testnet.Process.RunIO.procFlex` instead, since it needs to work outside Hedgehog too.

See also [[reference_rio_monadfail_production_path]].
