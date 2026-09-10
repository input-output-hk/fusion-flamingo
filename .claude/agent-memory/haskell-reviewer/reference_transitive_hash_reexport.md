---
name: transitive-hash-family-reexport
description: cardano-api data-family Hash(..)/AsType(..) exports pull in constructors transitively - grepping a module's own export list for a constructor name gives false "out of scope" alarms
metadata:
  type: reference
---

In cardano-api, `Hash (..)` (and similarly `AsType (..)`) is a data family. When a module re-exports `Hash (..)` in its own export list, that wildcard brings into scope EVERY constructor of EVERY `Hash` instance that module has imported into its own scope - not just instances it defines itself, and the constructor names never appear literally in that module's export list text.

Concretely: `Cardano.Api.Plutus.Internal.Script` exports `Hash (..)` and separately does a bare `import Cardano.Api.Key.Internal` (where `data instance Hash StakeKey = StakeKeyHash {...}` lives). Any module that does a bare `import Cardano.Api.Plutus.Internal.Script` therefore gets `StakeKeyHash` in scope, even though grepping `Cardano.Api.Plutus.Internal.Script`'s export list or source for the literal string "StakeKeyHash" finds nothing.

**Why this matters for review**: I nearly reported a false "critical - won't compile, StakeKeyHash out of scope" finding against `cardano-api/src/Cardano/Api/Compatible/Tx.hs`'s `placeholderStakeCredential`, having checked every bare-imported module's own export list for the literal constructor name or a `module Cardano.Api.Key` re-export and found none. The file actually compiles fine - the constructor arrives transitively through a `Hash (..)`/`AsType (..)` wildcard on an unrelated-looking module. I only caught the error because I ran an actual `cabal build` (against policy - see [[feedback_no_subproject_builds_solo]]) and it succeeded.

**How to apply**: before declaring a constructor "out of scope" in a cardano-api review, don't stop at grepping each import's own export list for the literal name. Check whether ANY bare-imported module re-exports `Hash (..)`/`AsType (..)` (or another open data/type family with a wildcard), and if so, check whether THAT module's own imports bring in the instance that defines the constructor. This is a multi-hop check; when in doubt, prefer asking for (or, if authorized, running) a real build over a confident-sounding static "won't compile" claim.
