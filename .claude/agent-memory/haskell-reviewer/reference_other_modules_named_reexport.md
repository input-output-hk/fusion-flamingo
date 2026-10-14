---
name: other-modules-named-reexport
description: a function defined in a cabal other-modules file can still be public API if a sibling exposed-modules file names it in its export list
metadata:
  type: reference
---

Being in `other-modules:` in the `.cabal` file does NOT make a function private/internal-only for changelog or "is this breaking" purposes. Check every `exposed-modules` file for a literal named re-export of the function, not just the file that defines it.

Concretely, on cardano-api PR #1359: `getAnyWitnessScript`, `getTxScriptWitnessRequirements`, `getTxScriptWitnessesRequirements` are defined in `Cardano.Api.Experimental.Tx.Internal.AnyWitness`/`TxScriptWitnessRequirements`, both `other-modules`. I initially assumed this made them internal-only. They are in fact fully public: the exposed `Cardano.Api.Experimental.Tx` (`Tx.hs`) re-exports each by name in its own export list. `fromPlutusRunnable`, by contrast, lives in the exposed `AnyScriptWitness.hs` itself but is genuinely absent from every export list anywhere - that one really is internal.

**How to apply**: before calling a function "internal, shouldn't be named in a changelog fragment" or "not breaking since it's other-modules", grep for the bare function name across every file listed under `exposed-modules:` in the `.cabal` file, not just its own defining module. A function can be `other-modules` at home and still public via a named re-export elsewhere - this is a simpler, more literal cousin of [[transitive-hash-family-reexport]] (which is about wildcard data-family reachability, not named re-exports).
