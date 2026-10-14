---
name: testnet-defaults-paths-location
description: defaultNodeName/defaultNodeDataDir/defaultConfigFile/defaultGenesisFilepath etc. are defined in cardano-node's Cardano.Node.Testnet.Paths, not in cardano-testnet's Testnet.Defaults which merely re-exports them
metadata:
  type: reference
---

`Testnet.Defaults` (cardano-testnet/src/Testnet/Defaults.hs) exports `defaultNodeName`, `defaultNodeDataDir`, `defaultConfigFile`, `defaultGenesisFilepath`, `defaultSpoName`, `defaultDRepName`, `defaultCommitteeName`, `defaultDelegatorName` and their derived path helpers, but does NOT define any of them.
The actual definitions live in `cardano-node/src/Cardano/Node/Testnet/Paths.hs` (module `Cardano.Node.Testnet.Paths`), whose own haddock explains why: "Both cardano-testnet (producer) and consumers of generated testnet configurations depend on this module so that directory layout changes are kept in sync at compile time."
A plain-text grep of `Testnet/Defaults.hs` for e.g. `defaultNodeName` finds only the export-list line, nothing else - looks like a dangling export until you check ctags/agent-tags, which correctly points at `Cardano/Node/Testnet/Paths.hs:72` and friends.
Naming conventions to remember from that file: `defaultNodeName n = "node" <> show n` (node1, node2, ... regardless of SPO/relay role), `defaultNodeDataDir n = "node-data" </> defaultNodeName n`, `defaultSpoName n = "pool" <> show n` (SPO KEY directories only, unrelated to the node's own directory name).
Relevant when reviewing any code that builds testnet-output-directory paths by hand (e.g. a manifest/report feature) instead of importing this module - hand-duplicated literals should match this module's conventions and ideally call into it directly.
See [[manifest_json_pr6693]].
