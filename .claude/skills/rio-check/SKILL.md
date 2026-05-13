---
name: rio-check
description: Check if a Haskell function or type is re-exported by the RIO module.
disable-model-invocation: true
argument-hint: [symbol-name]
---

Check whether the symbol `$ARGUMENTS` is re-exported by RIO.

## Procedure

1. Find the RIO package source in the nix store by searching for the RIO module file:
   ```
   find /nix/store -path '*/RIO.hs' -name 'RIO.hs' 2>/dev/null | head -5
   ```
   Or search the project's dependency tree:
   ```
   grep -r 'module RIO' $(nix build '.#cardano-rpc:lib:cardano-rpc' --print-out-paths 2>/dev/null)/lib/ 2>/dev/null
   ```
2. Search for the symbol in RIO's module exports and re-exports.
3. Report:
   - Whether the symbol is available from RIO
   - If NOT available, which module to import it from (e.g. `Data.List`, `Data.Map`, etc.)
   - Whether RIO hides it (some symbols are explicitly hidden, like `toList`)

## Known RIO gaps (common gotchas)
- `sortBy` — NOT in RIO, import from `Data.List`
- `on` — NOT in RIO, import from `Data.Function`
- `toList` — RIO re-exports from GHC.Exts but some modules hide it; use `GHC.IsList` or import explicitly
- `sortOn`, `sort` — available in RIO
