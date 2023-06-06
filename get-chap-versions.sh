#!/bin/env bash

# displays versions and hashes for chap dependencies for the current build plan

set -euo pipefail

echo '*** Creating build plan...'
cabal build --project-file cabal-hackage.project --dry-run all >/dev/null

jq '."install-plan"[] | select(."pkg-src".repo.uri == "https://input-output-hk.github.io/cardano-haskell-packages")'< dist-newstyle/cache/plan.json

## TODO how those produced hashes relate to the versions in CHaP?
# Probable workaround:
# 1. Resolve package-version pair into toml file in https://github.com/input-output-hk/cardano-haskell-packages
# 2. Get hash from CHaP
# 3. Use git worktree to checkout package subdirectory basically emulating `cabal get` which does not seem to
#    be working for custom repositories
