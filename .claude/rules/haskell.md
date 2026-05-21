---
paths:
  - "**/*.hs"
  - "**/*.cabal"
  - "cabal.project"
  - "cabal.project.local"
---

# Build and project layout
- **Always run `cabal` from `/work`** (the metarepo root where `cabal.project` lives), NEVER from inside a subproject.
  The metarepo `cabal.project` orchestrates builds across all subprojects.

# Changelog fragments
- **Never wrap description text in changelog fragments.**
  Keep the entire description on a single line after `description: |` regardless of length.
  The YAML literal block scalar preserves line breaks, so wrapping introduces unwanted newlines.

# Haskell code navigation
- **ctags first** for finding definitions.
  `/work/agent-tags` is a hasktags index covering the project and its dependencies.
  Use `grep -m5 '^SymbolName\t' /work/agent-tags` before anything else when looking up a symbol.
  This is instant, precise, and always the first thing to try.
  If `/work/agent-tags` is missing or stale, fall back to Serena (`find_symbol`) or grep, then suggest running `/regenerate-tags` to rebuild.
- **HLS** (Haskell only): use for go-to-definition, type info, and diagnostics in Haskell projects.
  **After every edit to a `.hs` file**, check HLS diagnostics on the changed lines before reporting the edit as complete.

# cardano-rpc patterns
- Never manually edit generated code (e.g. proto-lens output in `gen/`).
  Use nix dev shell to run code generation tools (e.g. `nix develop --command bash -c "cd cardano-rpc && buf generate proto"`).
- `Proto msg` is a grapesy newtype wrapper.
  Internal functions should use plain proto-lens types, not `Proto`-wrapped.
  Use `getProto`/`fmap getProto` only at the RPC handler boundary.
- RIO hides many Prelude functions.
  `sortBy` is NOT re-exported by RIO - import from `Data.List`.
  Check RIO re-exports before assuming standard functions are in scope.
- RIO's `^.` works with proto-lens van Laarhoven lenses.
  No need for `lens-family` dependency.
- Use `toList` (from `GHC.IsList`) instead of deprecated `valueToList` for `Value`.
- Prefer backtick-infix sections over lambdas (e.g. `` (`f` y) `` not `\x -> f x y`).
  hlint catches this.
- When sending raw CBOR over RPC, use `readTextEnvelopeFromFile` + `textEnvelopeRawCBOR` instead of `readFileTextEnvelope` + `serialiseToCBOR`.
  The latter round-trips through CBOR deserialisation/serialisation unnecessarily.
  If you also need the decoded Haskell value, call `deserialiseFromTextEnvelope` on the same `TextEnvelope`.

# cardano-api era constraints
- `IsEra` (from `Cardano.Api.Experimental`) only provides `useEra :: Era era` and does NOT imply `IsShelleyBasedEra`.
  For `Tx era` operations (`HasTextEnvelope`, `SerialiseAsCBOR`, `getTxBody`, etc.) use `IsShelleyBasedEra era` as the constraint.
  `EraCommonConstraints` includes `IsShelleyBasedEra` but is a large constraint synonym; prefer the minimal constraint.

# Haskell style
- Use readable value names, not acronyms: `shelleyBasedEra` not `sbe`, `policy` not `pid`, `network` not `nw`, `credential` not `cred`, `address` not `addr`, `value` not `val`, `tokenName` not `aname`, `quantity` not `qty`.
- Don't create trivial one-liner helpers that just wrap `defMessage & lens .~ value` - inline them at call sites.
- Use `OverloadedLists` and list literals instead of deprecated `valueFromList`.
- Check that type constraints are actually needed before adding them.
- **Always add Haddock comments over function parameters** when writing Haddock documentation.
  Use the `-- ^` syntax on each parameter to describe its purpose.
- **Always use `do` instead of `let ... in`.**
  Write `do { let x = ...; expr }` not `let x = ... in expr`.
- **Always prefer `$` over `()`** for function application.
  Write `f $ g x` not `f (g x)`.
- **Prefer dots over multiple dollars** in function application chains.
  Write `f . g . h $ u v` not `f $ g $ h $ u v`.
- **No staircase pattern.** Never nest `case ... of Just/Nothing` producing rightward drift.
  Use `MaybeT` + `Alternative` (`<|>`) to flatten sequential `IO (Maybe a)` fallbacks:
  ```haskell
  -- WRONG (staircase):
  do x <- action1
     case x of
       Just v -> pure v
       Nothing -> do y <- action2
                     case y of ...
  -- RIGHT:
  fromMaybe fallback <$> runMaybeT
    (  MaybeT action1
   <|> MaybeT action2
   <|> MaybeT action3
    )
  ```
  For pure `Maybe` chains without `IO`, use plain `<|>` on `Maybe` (its `Alternative` instance).
- **Never use `BlockArguments`** extension.
- **Never use `putStrLn`** in library code - use `Data.Text.IO.hPutStrLn stdout` for `Text` output (`say` is not available in RIO 0.1.24.0).
- **Never modify `fourmolu.yaml`**, hlint rules, or cabal gild rules unless explicitly asked.
- In Hedgehog tests, use `H.nothingFail` from hedgehog-extras instead of `case ... Nothing -> H.failure; Just x -> do`.
  Import convention: `import Hedgehog as H` + `import Hedgehog.Extras qualified as H`.
- In Hedgehog tests, use `H.leftFail` / `H.leftFailM` from hedgehog-extras instead of `case ... Left err -> H.annotateShow err >> H.failure; Right x -> do`.
  Only applies to success cases where any `Left` is unexpected; keep the explicit `case` when specific `Left` patterns are valid outcomes.
- In Hedgehog tests, never use `H.assert` - always use `H.assertWith` from hedgehog-extras.
  `assertWith v (p -> Bool)` reports the value on failure via `noteShow_`, subsuming a separate `H.annotate`.
- Use `H.propertyOnce` (from hedgehog-extras) instead of `H.property` for tests with no generators (`forAll`) - i.e., unit tests with fixed data.
- In `retryUntilJustM`, match the guard condition to the expected postcondition exactly.
  A weaker guard (e.g. `> 0` when the assertion expects `=== 2`) causes the retry to exit early and the assertion to fail.
- Prefer `GHC.IsList` (`GHC.Exts`) `toList`/`fromList` over specialised container versions (e.g. `Set.fromList`, `Data.Foldable.toList`).
