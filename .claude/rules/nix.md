---
paths:
  - "**/flake.nix"
  - "**/flake.lock"
  - "**/*.nix"
  - "cabal.project"
---

# General nix gotchas
- `nix build path:.` in a git worktree only sees **committed or staged** files (nix detects `.git` and filters via git).
  Always `git add` changed files before building; a full commit is not required.
- `nix develop` fails inside a git worktree of a submodule - nix tries to open `.git/modules/<submodule>/@worktree/<name>/` which doesn't exist.
  Run `nix develop` from the submodule's main checkout instead, then `cd` into the worktree.
- Minimise nix build round-trips: verify types, imports, and constraints carefully before building.

# haskell.nix gotchas
- haskell.nix `modules` source overrides (`packages.foo.src = mkForce ...`) only apply at **build** time.
  The **plan computation** phase fetches SRP sources independently.
  Use `inputMap` in `cabalProject'` to provide fixed sources for both phases.
- `inputMap` key must be `"url/rev"` when the value is a plain store path (no `.rev` attribute).
  Bare `"url"` makes haskell.nix try to access `.rev` on the value.
- Module overrides for packages not in the build plan fail.
  Guard with `config.packages ? ${p}`.
- **Always include a correct `--sha256:` hash** on `source-repository-package` stanzas - nix requires it for reproducible fetching.
  NEVER use placeholders like `sha256-PLACEHOLDER`. Compute the real hash before reporting the work as done.
  Use `nix-prefetch-git --quiet <url> --rev <tag> | jq -r '.sha256'` then `nix hash to-sri --type sha256 <hash>`.

# cardano-node nix attribute paths
- Attribute paths live under `hydraJobs`, not top-level packages.
  Use `nix build 'path:.#hydraJobs.native.<target>'` for native builds.
  Top-level categories: `native`, `musl`, `windows`, `cardano-deployment`, `required`, `nonrequired`.
  Attribute paths within categories use slashes, not colons.
  Tests: `hydraJobs.native.tests/cardano-testnet/cardano-testnet-test`, `hydraJobs.native.checks/cardano-testnet-11.0.0-inplace-cardano-testnet-test/cardano-testnet-test`.
  Libraries: `hydraJobs.native.cardano-testnet`, `hydraJobs.native.cardano-node`, `hydraJobs.native.cardano-cli`.
  Other targets: `hydraJobs.native.gen-plutus`, `hydraJobs.native.calibrate-script`, `hydraJobs.native.tx-generator`.
  Example: `nix build 'path:.#hydraJobs.native.gen-plutus' --allow-import-from-derivation --accept-flake-config`.
