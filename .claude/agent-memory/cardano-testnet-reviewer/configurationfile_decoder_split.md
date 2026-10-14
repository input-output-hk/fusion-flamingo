---
name: configurationfile-decoder-split
description: TestnetRuntime.configurationFile has two DIFFERENT Haskell-side decoders in cardano-testnet - foldEpochState's path (via cardano-api, Yaml-based, safe) and Testnet.Types.getStartTime's own private decoder (raw Data.Aeson, JSON-only, breaks on YAML content)
metadata:
  type: reference
---

When reviewing any change that makes `TestnetRuntime.configurationFile` point at a YAML-encoded (not JSON-encoded) file, check BOTH of cardano-testnet's in-process decoders, because they are not consistent:
- `Testnet.Start.Cardano.cardanoTestnet`'s `waitForBlockThrow` (and `Testnet.Components.Query.getEpochStateView`, `FoldEpochState.hs`) all go through `Cardano.Api.foldEpochState` -> `Cardano.Api.LedgerState.initialLedgerState` -> `readNodeConfig` -> `parseNodeConfig` (`cardano-api/src/Cardano/Api/LedgerState.hs:1230`), which uses `Yaml.decodeEither'`. This is YAML-safe.
- `Testnet.Types.getStartTime` (`cardano-testnet/src/Testnet/Types.hs:265-283`) has its OWN private `decodeNodeConfiguration` helper that uses `A.eitherDecodeFileStrict'` (`A = Data.Aeson`, plain strict JSON). This is NOT YAML-safe - `Data.Yaml.encodeFile`'s block-style output (unquoted keys, no outer braces/commas) fails to parse as JSON at all.

Found via IntersectMBO/cardano-node PR #6710 ("Add prometheus support to cardano-testnet"): v2 switched the tracer-enabled node config copy from `Aeson.encodeFile` to `Yaml.encodeFile` (fixing a different problem - JSON being written into a file cardano-node reads as YAML), but this made `getStartTime` broken whenever called against a tracer-enabled `TestnetRuntime`, since nothing routed that one decoder through Yaml too. Not caught by CI because no test combines `runtimeEnableTracer = TraceEnabled` with a `getStartTime` call (the new dedicated tracer test doesn't call it; the tests that do call it don't enable the tracer) - a "no test exercises the intersection" gap, not a false negative in any single test.

General lesson: `Data.Aeson.eitherDecodeFileStrict'`/`decodeFileStrict'` anywhere in cardano-testnet that targets a "node configuration" file is a latent landmine the moment that file can legitimately contain real YAML syntax - prefer `Cardano.Api.LedgerState.readNodeConfig` or `Data.Yaml` directly. See [[trace_backend_override_not_merge]] for the sibling finding in the same PR/file.
