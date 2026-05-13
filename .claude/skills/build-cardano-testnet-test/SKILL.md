---
name: build-cardano-testnet-test
description: Build the cardano-testnet-test package using cabal from /work.
disable-model-invocation: true
---

Build cardano-testnet-test and report errors/warnings.

## Procedure

1. Run `cabal build cardano-testnet-test 2>&1` from `/work` with a 10-minute timeout.
2. Parse the output for GHC errors and warnings.
3. Report the results to the user.

## Important rules
- The working directory MUST be `/work` (the metarepo root where `cabal.project` lives).
- NEVER cd into a submodule to run cabal -- the metarepo `cabal.project` orchestrates all builds.
- Use `cabal build`, not `nix build` -- cabal and GHC are available in the nix dev shell.
- Timeout: 600000ms (10 minutes).
