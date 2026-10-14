---
name: process-run-vs-runio-split
description: cardano-testnet has TWO parallel families of proc<Binary> helpers (Testnet.Process.Run, MonadTest-constrained, for Hedgehog Integration code; Testnet.Process.RunIO, RIO-constrained, for plain-IO library code like cardanoTestnet itself) - they are not interchangeable, so an unused helper in one family isn't necessarily dead/wrong
metadata:
  type: reference
---

`Testnet.Process.Run` (e.g. `procNode`, `procSubmitApi`, `procCardanoTracer`) has signatures constrained by `MonadTest m` and is meant to be called from Hedgehog `Integration`/`Property` code — e.g. `Testnet.SubmitApi.withSubmitApi :: SubmitApiConf -> [String] -> (String -> Integration ()) -> Integration ()` calls `procSubmitApi` directly because `withSubmitApi` itself only ever runs inside `Integration`.
`Testnet.Process.RunIO` (e.g. `procNode`, `procKesAgent`, `procFlex`) has `RIO env`-constrained signatures and is what plain-IO library code uses — e.g. `Testnet.Runtime.startNode` and `Testnet.Start.Cardano.cardanoTestnet` run outside any Hedgehog context (the `cardano-testnet cardano` CLI entry point is not a Hedgehog property), so they call the RunIO-flavoured helpers via `runRIO ()`.

Consequence for review: if a new "start a process" function in library code (like `cardanoTestnet`'s call graph) reimplements `procFlex "some-binary" "SOME_ENV"` instead of reusing a same-named helper already added to `Testnet.Process.Run`, that is NOT necessarily duplication to flag as a bug — check which monad the call site runs in first. It only becomes a real "dead code" finding if the `Process.Run` helper is unused *and* no Hedgediog-level test exists that would plausibly call it (as found in PR #6710's `procCardanoTracer`, added but never called from either `CardanoTracer.hs` — correctly RunIO-flavoured — or the new `EnableTracer.hs` test).
See [[sprocket_required_for_af_unix_sockets]] (same PR, same file).
