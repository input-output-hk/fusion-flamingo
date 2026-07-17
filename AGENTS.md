# Project Instructions

<!-- Keep this file lean. Only add things that are NOT inferrable from reading
     the source code: surprising gotchas, easy-to-make mistakes, external facts,
     local workstation details, and behavioural rules for AI agents. Everything else
     (host configs, services, modules, flake inputs, etc.) lives in the code. -->

# Rules for AI agents
- When you discover a surprising gotcha, easy-to-make mistake, or non-obvious fact about this project, add it to this file (AGENTS.md) - NOT to private memory.
  This file is the shared knowledge base for the project.
- **Never add CPP (`{-# LANGUAGE CPP #-}`) without explicit user permission.**
  Find a CPP-free solution or ask; mind that CI builds with multiple GHC versions (9.6 upwards), so version-gated syntax needs a different approach.
- **Never run builds (`cabal build`, `nix build`) in subprojects without explicit user permission.**
  The metarepo orchestrates builds; subproject builds can interfere. Always ask first.
- **Run `scripts/devshell/prettify`** on changed Haskell files after edits, but only in subprojects that have this script.
  Check the script exists before running it - not every repo has one (e.g. cardano-node does not).

# Directory structure
- Always execute nix commands in each subproject's root directory.
- Never modify the nix store.
- Worktrees ALWAYS reside in each subproject's `@worktree`.
  Each worktree has a separate folder e.g. `cardano-api/@worktree/my-feature`.
- **Always create worktrees on a branch**, never detached HEAD.
  Use `git worktree add -b <branch> <path> <start-point>` to create a local branch tracking the remote.
  Never use `git worktree add <path> <remote-ref>` without `-b` - it creates a detached HEAD.
- **When checking out a PR whose head branch already exists locally, reuse that branch** (`git worktree add <path> <branch>`, no `-b`) if it points at the PR head commit.
  Never create a suffixed duplicate branch (e.g. `<branch>-pr1234`) - the work then lands on a branch the PR does not track.
  If the existing local branch diverges from the PR head, stop and ask the user.
- **After creating a worktree, rewrite both worktree pointer files to relative paths** (the container mounts the metarepo at `/work` but the host uses a different path, so the absolute paths git writes break git on the host).
  **Not every subproject is a submodule - check first** with `git -C /work/<subproject> rev-parse --git-common-dir`:
  some (e.g. cardano-node) are submodules with gitdir `/work/.git/modules/<subproject>`, others (e.g. cardano-api) are standalone clones with gitdir `/work/<subproject>/.git`.
  Derive the relative paths from the real gitdir; never assume the submodule layout.
  Submodule case:
  `<subproject>/@worktree/<name>/.git` -> `gitdir: ../../../.git/modules/<subproject>/worktrees/<name>` (three `../`),
  `/work/.git/modules/<subproject>/worktrees/<name>/gitdir` -> `../../../../../<subproject>/@worktree/<name>/.git` (five `../`).
  Standalone case:
  `<subproject>/@worktree/<name>/.git` -> `gitdir: ../../.git/worktrees/<name>` (two `../`),
  `/work/<subproject>/.git/worktrees/<name>/gitdir` -> `../../../@worktree/<name>/.git` (three `../`).
  Verify with `git -C /work/<subproject> worktree list` - it must show the real worktree path, not a phantom one.

# Tool preferences for code navigation
- **Semantic tools** for references and type info.
  For "find references", "who calls X", "find consumers/producers", or "show me the type of X" queries, prefer semantic tools over grep.
- **Serena** (any language): use `find_referencing_symbols` for reference lookups, `get_symbols_overview` and `find_symbol` for exploring types and signatures without reading whole files.
- **Grep**: reserve for text-level searches - comments, string literals, non-code patterns, or when semantic tools are unavailable.
- Language-specific rules in `.claude/rules/<lang>.md` may add additional navigation tooling (e.g. ctags) on top of the above.
- **Serena diagnostics go stale after out-of-band edits.**
  Serena's language server opens files once and never sees changes made on disk by other tools (Edit/Write), so `get_diagnostics_for_file` keeps reporting the old snapshot - `touch`, symbol lookups and project re-activation do NOT refresh it.
  Edit Haskell files through Serena's own tools (`replace_in_files`, `replace_symbol_body`) so the server gets change notifications.
- **Never wait on HLS warming up.**
  If HLS is running and responsive, use it for diagnostics.
  If it is not running, restart it in the background (fire and forget) so it is warm later, and carry on without it.
  Whenever HLS is not available or returns stale or empty results, verify with `cabal build <target>` / `cabal test <target>` from `/work` - never block on HLS.
  Verification builds from the metarepo root `/work` are always permitted; the no-builds rule above is about building inside subproject directories.

# haskell.nix gotchas
- Test fixtures inside a test suite's `hs-source-dirs` are included in nix `checks` automatically:
  haskell.nix's component source filter (`lib/clean-cabal-component.nix`) keeps entire `hs-source-dirs` trees, and the check (`lib/check.nix`) runs with CWD at the package root, so package-root-relative fixture paths resolve.
  `extra-source-files` is therefore only needed for files OUTSIDE `hs-source-dirs`, and it also controls sdist contents - never list test-only fixtures there, or they ship with the Hackage/CHaP release.

# GitHub gotchas
- `gh pr edit` fails against IntersectMBO repos with a `projectCards` GraphQL deprecation error (classic projects sunset).
  Update PRs via REST instead: `gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -f title=... -F body=@file`.
- `gh api -f body=@file` does NOT read the file - `-f`/`--raw-field` treats the value literally, posting the filename as the body.
  Only `-F`/`--field` expands `@file`; always verify the posted body in the API response.

# GitHub Actions
- Use `cachix/install-nix-action@v30` with IOG trusted keys and substituters.
  Pattern: `nix run github:input-output-hk/cardano-dev#<app> -- <args>`.
  Reference: cardano-api's `check-cabal-files.yml`.

# Project context

## cardano-rpc
- Haskell gRPC server embedded in cardano-node via UTxO RPC spec.
- Currently uses Node-to-Client IPC (one connection per request, double serialisation).
  Planned: node kernel access - in-process access to `NodeKernel` (ChainDB, Mempool, Config) replacing N2C IPC (ADR-019).
- Roadmap: UTxORPC parity, conformance tests, node kernel access, HTTP endpoint, streaming (ChainSync), governance/stake queries, ecosystem tooling.
- Key ADRs: ADR-018 (architecture), ADR-019 (node kernel access) in cardano-node-wiki/docs/.
- Design docs and stories: `cardano-api/cardano-rpc/docs/node-kernel-access/`.

## herald
- Changelog/release automation CLI in `/work/cardano-dev/herald/`.
- Nix flake at `/work/cardano-dev/flake.nix` (top level), exposed as `apps.herald`.
  External ref: `github:input-output-hk/cardano-dev#herald`.
- GHA composite actions at `.github/actions/{validate,release}/action.yml`.
- **`herald validate --diff` only counts fragments ADDED since the fork point.**
  Modifying a fragment that already exists on the base branch (e.g. reusing a merged PR's fragment by bumping its `pr:` field) does not count - the check fails with "has modified files but no changelog fragment".
  Each PR needs its own new fragment file; never repurpose merged fragments.

# GHC gotchas
- **GHC 9.10 rejects let-bound tuple patterns whose type is only pinned by later uses** when the components come out of an eon-constraint continuation (MonoLocalBinds).
  GHC 9.12 infers these; CI builds 9.6/9.10/9.12, so give such pattern bindings explicit component type signatures (with a scoped `era` via explicit `forall`).
- **Unreachable GADT case arms under unsatisfiable constraint bundles trigger `-Woverlapping-patterns`.**
  While an era's wiring is unfinished upstream (e.g. Dijkstra), a concrete-era case arm inside `shelleyBasedEraConstraints` scope can be provably dead and must be omitted; the case stays exhaustive, and becomes non-exhaustive (a compile warning) exactly when the era lands - a useful tripwire.

# cardano-api experimental API gotchas
- `Cardano.Api.Experimental` does NOT re-export `AnyScriptWitness`/`AnyScriptWitnessSimple`.
  Import `Cardano.Api.Experimental.AnyScriptWitness` directly (it is an exposed module).
- `Cardano.Api.Experimental` does NOT re-export `Convert (..)` either (defined in `Cardano.Api.Experimental.Era`).
  Without it, dispatch from `Era era` to an eon (e.g. `AlonzoEraOnwards`) needs a hand-rolled two-arm case.
- The experimental `Era` GADT constructor names (`ConwayEra`, `DijkstraEra`) clash with old-API `CardanoEra` constructors that plain `Cardano.Api` re-exports.
  Import the experimental `Era` type without `(..)`, or qualified, in modules that also import `Cardano.Api`.
- `obtainCommonConstraints` implies `L.BabbageEraTxBody (LedgerEra era)`, whose superclass chain provides `AlonzoEraTxOut`/`BabbageEraTxOut` unconditionally (every `IsEra` era is Alonzo-onwards).
  So ledger `TxOut` construction needs no era-conditional dispatch - `forEraMaybeEon` checks for script-data support are unnecessary under `IsEra`.
  Public recipe: `mkCoinTxOut` (`Cardano.Ledger.Core`) + `datumTxOutL` (`Cardano.Ledger.Api.Tx.Out`) + `DatumHash . hashData . toAlonzoData @(LedgerEra era)` (`toAlonzoData` via `Cardano.Api.Plutus`; `hashData`/`Datum (..)` from `Cardano.Ledger.Plutus.Data`).
  The `@(LedgerEra era)` type application is required - point-free composition leaves `toAlonzoData`'s era unpinned ("Cannot satisfy: ProtVerLow <= ProtVerHigh era0").
- cardano-api symbol reachability depends on export-list chains, not module names or paths: `Cardano.Api.Tx.Internal.Output` is `other-modules` in 11.3 (so `toBabbageTxOutDatum` and the `ScriptDataHash` constructor are unreachable outside the package), yet `AlonzoEraOnwards (..)` IS in scope via plain `Cardano.Api` despite living in an `Internal` other-module, because the exposed `Cardano.Api.Era` re-exports it.
  Verify against the package's cabal `exposed-modules` and export lists, never path names.
- There is NO experimental analogue of `toBabbageTxOutDatum` (checked cardano-api 11.3 and current master): the ledger-lens recipe above IS the idiomatic way (cardano-api's own `FromJSON (Exp.TxOut era)` instance uses it internally).
  False friend: the experimental `Datum ctx era` GADT in `Cardano.Api.Experimental.Tx` has TxOut-flavoured constructor names (`TxOutDatumHash`/`TxOutDatumInline`/`TxOutSupplementalDatum`) but is ONLY for reference-input datum collection (`TxInsReference`), not for attaching datums to a `TxOut` under construction.
  Supplemental datums pair the TxOut's `DatumHash` with `setTxSupplementalDatums` on the `TxBodyContent`.
- Native script patterns (`RequireAllOf` etc.) are NOT in `Cardano.Api.Ledger`.
  Import `Cardano.Ledger.Shelley.Scripts` for them; a qualified import avoids needing the `PatternSynonyms` extension in the import list.
- `PolicyAssets`' Show instance prints `policyAssetsFromList`, but no such function exists.
  Use `GHC.Exts.fromList` (`IsList` instance); `valueFromList` for `Value` is deprecated in favour of `fromList` too.
- Era TAG types (`BabbageEra` etc.) and `CardanoEra` constructors pun the same names in different namespaces.
  Importing `CardanoEra (..)` without the tag types makes a type-position `BabbageEra` resolve to the DataKinds-promoted constructor, giving a baffling kind error ("'BabbageEra' has kind 'CardanoEra BabbageEra'").
  Import the tag types explicitly alongside `CardanoEra (..)` in explicit import lists.

# Ledger witness serialisation gotchas
- `rawSerialiseVerKeyDSIGN`/`rawSerialiseSigDSIGN` are not re-exported by cardano-ledger or cardano-api.
  To get raw key/signature bytes from ledger witnesses (`WitVKey`, `BootstrapWitness`), depend on `cardano-crypto-class` directly and import `Cardano.Crypto.DSIGN.Class` (also provides the `SignedDSIGN` newtype constructor for unwrapping signatures).
- `BootstrapWitness` field accessors (`bwKey`, `bwSignature`, `bwChainCode`, `bwAttributes`) are NOT exported via `Cardano.Ledger.Api` (only the abstract type is).
  Import `Cardano.Ledger.Keys.Bootstrap` for them (also exports `ChainCode (..)`).
- `originalBytes` (memoised original CBOR, e.g. of a plutus `Data`) is available without extra imports: `Cardano.Ledger.<Era>.Core` modules re-export `Cardano.Ledger.Core`, which re-exports `Cardano.Ledger.Hashes` including `SafeToHash (..)`.

# Ledger TxCert gotchas
- `Cardano.Ledger.Api.Tx.Cert` exports the cert classes with only a method subset: `mkRegTxCert`/`mkDelegTxCert` are NOT reachable through it.
  Import `Cardano.Ledger.Shelley.TxCert (ShelleyEraTxCert (..))` / `Cardano.Ledger.Conway.TxCert (ConwayEraTxCert (..))` for the smart-constructor methods (same qualified alias is fine - the re-exported names are the same entities).
- `TxCert`/`ShelleyLedgerEra` are non-injective type families, so `mkRegTxCert`/`mkDelegTxCert` need an explicit type application `@(ShelleyLedgerEra era)` when the result is only consumed by a class method (`show`, `isRegStakeTxCert`); GHC cannot invert the family from the context.

# Ledger PParams HKD gotchas
- The `hkd*L` class lenses (e.g. `hkdMaxTxSizeL`) always need explicit type applications `@era @f` at use sites.
  `PParamsHKD` and `HKD` are non-injective type families, so GHC cannot infer `f` from a `PParamsHKD f era` value; a signature abstracting over `f` also needs `AllowAmbiguousTypes` in the defining module.
  Pattern: cardano-rpc's `pparamsFieldSetters` (one field table serving both `PParams` via `ppLensHKD` at `Identity` and `PParamsUpdate` via `ppuLensHKD` at `StrictMaybe`).
- `AlonzoEraPParams` methods are NOT reachable via the `Cardano.Ledger.Conway.Core` re-export chain: `Cardano.Ledger.Alonzo.Core` exports the class WITHOUT `(..)` (unlike `BabbageEraPParams (..)` in Babbage.Core), and `Cardano.Ledger.Api.PParams` also exports only the class names.
  Depend on `cardano-ledger-alonzo` directly and import `Cardano.Ledger.Alonzo.PParams` for `hkdCostModelsL`, `hkdPricesL`, `hkdMaxValSizeL` etc.
- `hkdProtocolVersionL` requires `AtMostEra "Babbage" era` - it does not exist for Conway onwards (updates cannot carry the protocol version there).
  Use `ppProtocolVersionL` on the full `PParams` instead; it is unconditional.

# Ledger core type gotchas
- `PoolMetadata`'s `pmHash` is a `ByteArray`, not a `ByteString`.
  Convert with `SBS.fromShort . byteArrayToShortByteString` (from mempack's `Data.MemPack.Buffer`, requires a `mempack` build-dep) - same as cardano-api's `Cardano.Api.Certificate.Internal` does.

# Ledger aux data gotchas
- Tx metadata is uniformly accessible in all eras via `metadataTxAuxDataL` (`EraTxAuxData` class method; `EraTx` implies it).
- Auxiliary scripts line up with the era's `Script` type at concrete eras: Allegra/Mary `nativeScriptsTxAuxDataL` yields `Timelock` (= `Script`), Alonzo onwards `getAlonzoTxAuxDataScripts` merges timelocks and plutus scripts into `AlonzoScript` (= `Script`, including Dijkstra).
  So aux scripts convert through `fromShelleyBasedScript` when matching concrete `ShelleyBasedEra` constructors (see `txAuxDataScripts` in cardano-rpc's `Type.hs`).
- All of this is exported via `Cardano.Ledger.Api` (from `Cardano.Ledger.Api.Tx.AuxData`, including `Metadatum (..)`).

# Dijkstra era gotchas
- For era dispatch in cardano-rpc, match all seven `ShelleyBasedEra` constructors explicitly, never with wildcards.
  At concrete eras every type family reduces and every ledger instance resolves, including Dijkstra, so no eon constraint machinery is needed, and a new era becomes a compile error at every dispatch site.
  Do NOT use `caseShelleyToBabbageOrConwayEraOnwards` (Dijkstra `error` stub), do NOT add bespoke dispatchers to `Case.hs`, and do NOT nest `forShelleyBasedEraInEon`.
  See `txCertToUtxoRpcCertificate` and `redeemersByIndex` in cardano-rpc for the accepted pattern.
- cardano-ledger-api's `AnyEra*` classes (`AnyEraTx`, `AnyEraTxBody`, `AnyEraTxWits`) provide uniform era-gated getters (`mintTxBodyG` etc.; `Nothing` where the era predates the field) and are Dijkstra-total; cardano-rpc's `anyEraTxConstraints` brings them plus `IsShelleyBasedEra` into scope from a `ShelleyBasedEra` witness.
  `AnyEraTxCert` however CANNOT read pre-Conway stake delegations: `anyEraToDelegTxCert` is `const Nothing` before Conway and no legacy `DelegStakeTxCert` getter exists, so certificate reading needs the concrete-era matchers instead.
- ALL eon constraint bundles except `alonzoEraOnwardsConstraints` error at runtime for Dijkstra: `shelleyBasedEraConstraints`, `allegraEraOnwardsConstraints`, `maryEraOnwardsConstraints`, `babbageEraOnwardsConstraints`, `conwayEraOnwardsConstraints`, and all six `caseShelleyTo*` dispatchers in `Era/Internal/Case.hs` ("TODO Dijkstra" stubs).
  The experimental `obtainCommonConstraints` IS Dijkstra-total, but the experimental `Era` GADT only has Conway and Dijkstra constructors, so it cannot drive code that must also handle historical eras.
- `conwayEraOnwardsConstraints` also crashes for Dijkstra - never use it.
  Its constraint bundle requires `TxCert ~ ConwayTxCert` which Dijkstra cannot satisfy.
- Dijkstra has `ConwayEraTxCert DijkstraEra` (so `mkDelegTxCert` works) but NOT `ShelleyEraTxCert`.
- `TxCert DijkstraEra = DijkstraTxCert DijkstraEra` - its own concrete type, NOT `ConwayTxCert DijkstraEra`.
  It reuses `PoolCert` and `ConwayGovCert`, but has its own `DijkstraDelegCert` (deposits are mandatory `Coin`, not `StrictMaybe Coin`); convert losslessly with `dijkstraToConwayDelegCert` from `Cardano.Ledger.Dijkstra.TxCert` (package cardano-ledger-dijkstra).
