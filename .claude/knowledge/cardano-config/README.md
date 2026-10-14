# cardano-config

Domain knowledge about `IntersectMBO/cardano-config`, moved out of AGENTS.md.

- **The local `/work/cardano-config` checkout can lag upstream by whole major versions** (2026-10-13: branch `js/cardano-config` at 0.1.0.0 with the old split-section format, while upstream `IntersectMBO/cardano-config` main was 2.2.1.0 with the v2 envelope format; the local CHaP checkout was equally stale).
  Check `git -C /work/cardano-config log -1 origin/main` against upstream, or read upstream with `gh api`, before answering questions about its format or API.
- **cardano-config 2.x fails on any config without all four `{Byron,Shelley,Alonzo,Conway}GenesisHash` keys, legacy flat files included** (its in-memory `migrate` never computes hashes).
  cardano-node 11.2 (`koslambrou/prepare-11.2`, PR IntersectMBO/cardano-node#6671) still starts on hash-less flat files only because its old POM parser stays authoritative for them and the cardano-config failure is a warning; cardano-testnet `create-env` writes hash-less configs on purpose.
- **Mentions of "cardano-config" in the cardano-api and cardano-cli changelogs and in `Cardano.Api.Internal.Orphans.Serialisation` refer to an unrelated 2021 cardano-node package of the same name**, not to `IntersectMBO/cardano-config`.
