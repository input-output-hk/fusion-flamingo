---
name: reference-cli-unitinterval-pparam-parser-convention
description: cardano-cli's safe idiom for UnitInterval/PositiveInterval-typed protocol-parameter CLI options, and the unsafe pattern that crashes on bad input
metadata:
  type: reference
---

In `cardano-cli/src/Cardano/CLI/EraBased/{Common,Governance/Actions}/Option.hs`, protocol-parameter options that parse a `Rational` and convert it to a bounded ledger type (`UnitInterval`, `PositiveInterval`, `NonNegativeInterval`) come in two shapes:

- **Safe (validates at parse time, clean optparse error on bad input)**: the `ReadM` itself does the bounds check and range-appropriate conversion, e.g. `pRefScriptCostMultiplier` uses `Opt.option (readRational >>= toPositiveInterval)` where `toPositiveInterval :: Rational -> Opt.ReadM PositiveInterval` calls `Opt.readerError` on failure (`Common/Option.hs`). Likewise `pTreasuryExpansion`/`pMonetaryExpansion`/`pDecentralParam` use `Opt.option readRationalUnitInterval` (`Common/Option.hs:2911-2936`), where `readRationalUnitInterval = readRational >>= checkUnitInterval` rejects out-of-`[0,1]` input inside the `ReadM`.
- **Unsafe (deferred conversion via `convertToLedger conv`, `conv` calls plain `error`)**: helpers `toUnitIntervalOrErr`/`toNonNegativeIntervalOrErr` (`Common/Option.hs:197-237`, `.../Governance/Actions/Option.hs:229-237`) call `error` on `Nothing` from `L.boundRational`. This is safe ONLY when the upstream parser already validated the range (e.g. `readRationalUnitInterval` feeding into `convertToLedger toUnitIntervalOrErr`, as the three pre-existing pparams above do) — it becomes a genuine bug the moment a new field is wired up with the unbounded `readRational` instead, because then an out-of-range CLI value causes an uncaught `error` crash rather than a normal usage message.

Caught on cardano-cli PR #1445 (Leios pparams): the new `pLeiosQuorumStakeThreshold` used `Opt.option readRational` feeding `convertToLedger toUnitIntervalOrErr`, so `--leios-quorum-stake-threshold 2` would crash instead of erroring cleanly.

**When reviewing**: any new `UnitInterval`/`PositiveInterval`/`NonNegativeInterval`-typed pparam option must either (a) use the matching `readRationalUnitInterval`/bespoke bounded `ReadM` at the option site, or (b) do the bounds check inside a `Rational -> Opt.ReadM X` conversion (the `toPositiveInterval` pattern), never route an unbounded `readRational` through a `convertToLedger <error-throwing-conv>` deferred conversion.
