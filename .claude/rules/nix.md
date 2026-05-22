---
paths:
  - "**/flake.nix"
  - "**/flake.lock"
  - "**/*.nix"
  - "cabal.project"
---

# cardano-node nix attribute paths
- Attribute paths live under `hydraJobs`, not top-level packages.
  Use `nix build 'path:.#hydraJobs.native.<target>'` for native builds.
  Top-level categories: `native`, `musl`, `windows`, `cardano-deployment`, `required`, `nonrequired`.
  Attribute paths within categories use slashes, not colons.
  Tests: `hydraJobs.native.tests/cardano-testnet/cardano-testnet-test`, `hydraJobs.native.checks/cardano-testnet-11.0.0-inplace-cardano-testnet-test/cardano-testnet-test`.
  Libraries: `hydraJobs.native.cardano-testnet`, `hydraJobs.native.cardano-node`, `hydraJobs.native.cardano-cli`.
  Other targets: `hydraJobs.native.gen-plutus`, `hydraJobs.native.calibrate-script`, `hydraJobs.native.tx-generator`.
  Example: `nix build 'path:.#hydraJobs.native.gen-plutus' --allow-import-from-derivation --accept-flake-config`.
