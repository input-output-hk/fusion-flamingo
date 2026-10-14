---
name: reference-numericunderscores-pragma-check
description: NumericUnderscores is not in cardano-api's common default-extensions; underscored literals need the pragma per-file
metadata:
  type: reference
---

`NumericUnderscores` is NOT part of cardano-api's `common project-config` `default-extensions` (only `ImportQualifiedPost` and `OverloadedStrings`), nor of `common maybe-unix`/`maybe-Win32`/`text`.
Several test files (`Test/Cardano/Api/Transaction/Collateral.hs`, `Autobalance.hs`, `Experimental/Collateral.hs`, `Experimental/Fee.hs`, `Transaction/Fixtures.hs`, `Transaction/Body/Plutus/RedeemerIndex.hs`) that use underscore-separated numeric literals (`10_000_000`) do carry an explicit `{-# LANGUAGE NumericUnderscores #-}` pragma.

**Why:** caught on cardano-api PR #1359 - a new test (`Test/Cardano/Api/Transaction/Body/Plutus/Scripts.hs`) used `10_000_000`/`2_000_000` literals but its pragma list only had `DataKinds, FlexibleContexts, GADTs, LambdaCase, ScopedTypeVariables, TypeApplications` - a genuine compile error, not a style nit.

**How to apply:** whenever a diff introduces underscore-separated numeric literals in cardano-api (or any submodule), check the file's own pragma list for `NumericUnderscores` and cross-check the relevant cabal stanza's `default-extensions` before assuming it's implied - don't rely on "other files in the project do this" without checking THIS file's pragmas.
