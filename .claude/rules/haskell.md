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
  Use `Proto`-wrapped messages throughout, including internal conversion functions.
  Handler boundary types, the `Inject` orphans and nested fields of `Proto` messages all expect `Proto` values, so wrapping throughout eliminates `getProto`/`Proto` shims.
- Don't create trivial one-liner helpers that just wrap `defMessage & lens .~ value` - inline them at call sites.
- When sending raw CBOR over RPC, use `readTextEnvelopeFromFile` + `textEnvelopeRawCBOR` instead of `readFileTextEnvelope` + `serialiseToCBOR`.
  The latter round-trips through CBOR deserialisation/serialisation unnecessarily.
  If you also need the decoded Haskell value, call `deserialiseFromTextEnvelope` on the same `TextEnvelope`.
- RIO's `^.` works with proto-lens van Laarhoven lenses; no `lens-family` dependency is needed.

# cardano-api era constraints
- `IsEra` (from `Cardano.Api.Experimental`) only provides `useEra :: Era era` and does NOT imply `IsShelleyBasedEra`.
  For `Tx era` operations (`HasTextEnvelope`, `SerialiseAsCBOR`, `getTxBody`, etc.) use `IsShelleyBasedEra era` as the constraint.
  `EraCommonConstraints` includes `IsShelleyBasedEra` but is a large constraint synonym; prefer the minimal constraint.
- **There is no `Convert ConwayEraOnwards MaryEraOnwards` instance, and a `convert` chain through an unannotated intermediate eon (`beo = convert ceo; meo = convert beo`) is ambiguous for GHC** (both cost a build cycle on 2026-10-02).
  In tests, start from the concrete constructor you need (`meo = MaryEraOnwardsConway`) and `convert` outward to the wider eons (`sbe = convert meo`).
- **Constraint-provider helpers (`maryEraOnwardsConstraints w`, `shelleyBasedEraConstraints sbe`, `obtainCommonConstraints e`, ...) take a rank-2 argument and cannot be composed with `.`**: `provider w . f $ x` fails with "Couldn't match type `C => T` with `T`" because `(.)` cannot instantiate its type variable to a constrained type, while `$` has special treatment (observed 2026-10-05, cost a build cycle).
  Apply them directly: `provider w $ f x`; this is the one exception to the dots-over-dollars rule.
- **A constraint-provider wrap used as a bare `do` statement (`maryEraOnwardsConstraints w $ do { ...; unless c $ Left e }`) compiles on GHC 9.12 but fails on GHC 9.10 and older with "Couldn't match type 'a0' with '()' ... 'a0' is untouchable inside the constraints"** (observed 2026-10-06 on cardano-api PR 1366: nix build green on 9.12.4, GHA wasm job on 9.10.3 red).
  Fix the result type from outside the implication: pattern-bind or annotate the constrained expression (`let L.MaryValue c ma = provider w value :: L.MaryValue`) and keep the `unless`/`when` in the outer monad, or wrap the whole function body so the signature fixes the type; CI compiles with several GHC versions, so a passing default nix build is not proof.
  Same family: `fromEitherIOCli $ shelleyBasedEraConstraints sbe $ readFileTextEnvelope (File f)` compiles on 9.12 but GHC 9.6/9.10 report "Could not deduce Show e0 ... e0 is ambiguous"; pin the error type with `fromEitherIOCli @(FileError TextEnvelopeError)` (precedent `fromEitherIOCli @(FileError ())` in cardano-cli's `Compatible/Governance/Run.hs`; observed 2026-10-16 on cardano-cli PR 1408).

# Haskell style
- Use readable value names, not acronyms: `shelleyBasedEra` not `sbe`, `policy` not `pid`, `network` not `nw`, `credential` not `cred`, `address` not `addr`, `value` not `val`, `tokenName` not `aname`, `quantity` not `qty`.
- Always use `GHC.Exts`' `IsList` methods (`fromList`/`toList`) instead of specialised variants (`Map.fromList`, `Set.fromList`, `Map.toList`, ...) whenever possible.
  Exception: don't use them on list comprehensions.
- Conversion helpers take plain values, never `Maybe`/`StrictMaybe`.
  Handle optionality at the call site with `fmap`/`strictMaybe`; a helper that absorbs a `Maybe` hides the default and breeds near-duplicate variants.
- **Never use `putStrLn`** in library code - use `Data.Text.IO.hPutStrLn stdout` for `Text` output.
- In Hedgehog tests, use `H.nothingFail` from hedgehog-extras instead of `case ... Nothing -> H.failure; Just x -> do`.
  Import convention: `import Hedgehog as H` + `import Hedgehog.Extras qualified as H`.
- In Hedgehog tests, write `===` unqualified (import it from Hedgehog), never `H.===`.
- Never use haddock markers (`-- |`, which fourmolu escapes to `-- \|`) on `where`-bound or other local definitions - plain `--` comments only; haddock belongs on top-level declarations.
- Never reference design docs in code (`docs/` paths, `*.md` file names, AC numbers, ADR numbers) in comments or haddocks.
  Restate the relevant fact inline instead - design docs move and rot independently of the code.
- In Hedgehog tests, use `H.leftFail` / `H.leftFailM` from hedgehog-extras instead of `case ... Left err -> H.annotateShow err >> H.failure; Right x -> do`.
  Only applies to success cases where any `Left` is unexpected; keep the explicit `case` when specific `Left` patterns are valid outcomes.
- In Hedgehog tests, never use `H.assert` - always use `H.assertWith` from hedgehog-extras.
  `assertWith v (p -> Bool)` reports the value on failure via `noteShow_`, subsuming a separate `H.annotate`.
- Use `H.propertyOnce` (from hedgehog-extras) instead of `H.property` for tests with no generators (`forAll`) - i.e., unit tests with fixed data.
- In `retryUntilJustM`, match the guard condition to the expected postcondition exactly.
  A weaker guard (e.g. `> 0` when the assertion expects `=== 2`) causes the retry to exit early and the assertion to fail.

# Build gotchas (moved from AGENTS.md)
- **Never add CPP (`{-# LANGUAGE CPP #-}`) without explicit user permission.**
  Find a CPP-free solution or ask; mind that CI builds with multiple GHC versions (9.6 upwards), so version-gated syntax needs a different approach.
- **`plutus-scripts-bench` (cardano-node bench/) is `buildable: False` outside GHC 9.6** (`if (impl(ghc <9.6) || impl(ghc >=9.7))` in its cabal file, mirroring plutus-tx-plugin's supported range), so metarepo builds with the pinned ghc-9.12.4 fail on it with `Cabal-7127: none of the components are available to build`.
  This is pre-existing and unrelated to whatever change is under test - drop the package from the target list (never change `with-compiler`) and let the PR's CI 9.6 variant exercise it.
- **cardano-cli is NOT a metarepo package (`cardano-cli/*/*.cabal` is commented out in /work/cabal.project), and its exe cannot be targeted directly.**
  `cabal build cardano-cli:exe:cardano-cli` (and `exe:cardano-cli`) fails with `Cabal-7130: Internal error in target matching` (cabal bug haskell/cabal#8684, triggered because /work/cardano-cli exists on disk without being a project package), and `cardano-cli-<ver>:exe:cardano-cli` fails with `Cabal-7129: Unrecognised target`.
  To get the pinned CHaP exe (e.g. for cardano-testnet's runtime `procFlex "cardano-cli"` dependency), build it as a tool dependency: `cd /work && cabal build cardano-testnet:test:cardano-testnet-golden --only-dependencies` produces `/work/dist-newstyle/build/.../cardano-cli-<pinned>/x/cardano-cli/build/cardano-cli/cardano-cli` (the test-suite stanzas declare `build-tool-depends: cardano-cli:cardano-cli`; the exe stanza does not, so building `cardano-testnet:exe:cardano-testnet` alone does NOT produce it).
  Mind stale exes from older plans (observed: cardano-cli-11.1.0.0 next to the pinned 11.2.3.1) sitting in dist-newstyle - check the version in the path, and mind that `cabal list-bin cardano-cli` prints the planned path even when the binary does not exist yet.
- **`gcc: fatal error: cannot execute 'cc1'` during a `cabal build` is a transient toolchain flake, not a code error - retry once before concluding the commit is broken.**
  Observed on the autogenerated `Paths_<pkg>.hs` (`\`cc' failed in phase \`Haskell C pre-processor'`), which is the CPP-using file cabal compiles first, so the failure surfaces before any project module and reads like the package itself is broken.
  Tell-tale signs: the failing file is an autogen `Paths_*.hs` rather than a project source, the message is an exec failure rather than a GHC type error, the same file compiled fine in an immediately preceding build, and a direct `gcc -c` on a trivial `.c` file succeeds.
  Root cause unconfirmed (possibly concurrent nix activity from other agents); the identical command succeeded on retry with no changes.
- **`cabal build <target> --ghc-options=-Werror` from /work is NOT a reliable warning check.**
  When the target is already built, cabal reports "Up to date" without recompiling anything (the command-line flag does not invalidate the build plan), and `cabal.project.local`'s global `program-options: ghc-options: -Wwarn` neutralises `-Werror` even on a genuine rebuild (both observed 2026-09-07 while verifying cardano-rpc; confirmed with `-v3`).
  To genuinely verify warning-cleanliness: temporarily add a `package <target>` stanza with `ghc-options: -Werror` to `cabal.project.local`, delete the package's `dist-newstyle/build/.../<pkg>-<version>` directory to force a from-scratch recompile, build from /work, then revert the stanza and confirm `git diff` is empty.
  The staleness is not limited to flags: an edited SOURCE FILE can also keep reporting "Up to date" (observed 2026-09-11, cabal-install 3.16.1.0 in the cardano-api devshell, single-package project: sed-edited Main.hs, then `touch`, then `--ghc-options=-fforce-recomp` - all three still "Up to date"; root cause unconfirmed).
  The dist-newstyle build-dir deletion is the one reliable recompile trigger; treat any "Up to date" after an edit as suspect until the build log shows the module compiling.
- **Run `scripts/devshell/prettify`** on changed Haskell files after edits, but only in subprojects that have this script.
  Check the script exists before running it - not every repo has one (e.g. cardano-node does not).
  It lives at the REPO root (sibling of `cabal.project`/`flake.nix`), one level above package dirs like `cardano-api/cardano-api/` - check with `git ls-files scripts/` from the repo/worktree root before concluding it does not exist.
- **`timeout N cabal test/build/repl ...` kills only the `cabal` wrapper process, not the GHC or test-binary children it spawned.**
  The orphans keep running (or hang) silently and accumulate as zombies; they hold no locks but corrupt any process-based diagnosis of "is something building".
  After any timed-out Haskell command, check `ps` for stragglers and kill them explicitly.

# HLS and cabal repl gotchas
- **Phantom "duplicate/overlapping instances" and missing-interface-file errors from HLS mean ghcide double-loaded the package**, not broken code.
  Tell-tale signs: the same instance listed twice at the identical source location, and two different `cardano-api-<ver>-inplace-<hash>` variants in the errors; happens after out-of-band cabal builds or when two HLS instances run at once.
  Ignore those diagnostics, restart HLS in the background, and trust `cabal build` from `/work` as ground truth.
- **A `cabal repl` session snapshots its in-project package dependencies.**
  `:reload` recompiles only the target component's modules; edits to a dependency package (e.g. cardano-api under a `lib:cardano-rpc` session) are invisible until the session is RESTARTED, and its errors then point at exports that already exist.
  After changing a dependency package, restart the repl session; trust `cabal build` from `/work` in the meantime.
- **Never wait on HLS warming up.**
  If HLS is running and responsive, use it for diagnostics.
  If it is not running, restart it in the background (fire and forget) so it is warm later, and carry on without it.
  Whenever HLS is not available or returns stale or empty results, verify with `cabal build <target>` / `cabal test <target>` from `/work` - never block on HLS.
  Verification builds from the metarepo root `/work` are always permitted; the no-builds rule above is about building inside subproject directories.
- **`dist-newstyle/tmp/src-*/` contains stale unpacked source tarballs of dependency releases - never read project sources from there.**
  A repo-wide grep or file search can land in e.g. `/work/cardano-node/dist-newstyle/tmp/src-33347/cardano-api-11.3.0.0/`, which is the pinned RELEASE of cardano-api, not the live `/work/cardano-api` checkout - analysis based on it silently describes outdated code (observed 2026-08-13: an agent answered a duplication question from the tarball copy).
  Search from inside the intended subproject and treat any path containing `dist-newstyle` as build output, never as source of truth.
- **CHaP package tarballs live at the foliage URL `https://chap.intersectmbo.org/package/<pkg>-<ver>.tar.gz`** - the Hackage-style path `/package/<pkg>-<ver>/<pkg>-<ver>.tar.gz` returns an HTML page, not a tarball.
  Useful for checking a pinned version's exact source (e.g. export lists) when haskdogs has a different version indexed.

# Haskell test gotchas
- **QuickCheck's `Arbitrary UTCTime` can produce Julian day numbers that are cheap thunks but pathologically expensive to force**: Data.Time's Gregorian conversion (`show`, `iso8601Show`) effectively hangs on them, which looks like a test-suite deadlock.
  `mod`/`truncate` clipping does not help - it forces the same value.
  Generate small dates independently (e.g. `ModifiedJulianDay <$> Gen.integral (Range.linear 0 1_000_000)`) instead of transforming the arbitrary one.
- **The `clipI` helper pattern from `Test.Cardano.Rpc.ProtocolParameters` is only valid for SIGNED types.**
  On `Natural` it throws arithmetic underflow; on `Word64` it wraps around and turns the clip into an infinite loop.
  Use a dedicated unsigned clip for unsigned fields.

# Dependency version skew gotchas
- **The `/work/cardano-ledger` (and other sibling) checkouts can be NEWER than the versions pinned by the metarepo's cabal.project index-state.**
  API details read from those checkouts (constructor names, signatures, pragmas) may not exist in the pinned build - e.g. `AlonzoScript`'s `TimelockScript` constructor is `NativeScript` at the pinned cardano-ledger-alonzo 1.15.0.1, renamed later upstream.
  Verify against the pinned version: the haskdogs cache (`~/.cache/haskdogs/<pkg>-<version>/`, which pins real versions) or `cabal build`'s errors - never trust the sibling checkout alone.

# Ledger native script gotchas
- **Native script patterns (`RequireSignature`, `RequireGuard`, ...) have no working `COMPLETE` pragma** (verified 2026-10-12 against cardano-ledger-allegra 1.10.2.0, -shelley 1.20.0.0, -dijkstra 0.4.0.0 on GHC 9.6/9.10/9.12): GHC silently ignores the per-era sets annotated `:: ShelleyEra` / `:: AllegraEra` ... `:: ConwayEra`, and Dijkstra declares none, so every match needs a `_ -> error` catch-all.
  Still match on the patterns, never on the raw constructors (`DijkstraNativeScriptRaw`, `TimelockRaw`) via `getMemoRawType`: the patterns are the ledger's public interface.
  A working set must be annotated `:: NativeScript` (or left unannotated) and live upstream next to the patterns: GHC rejects orphan `COMPLETE` pragmas, so cardano-api cannot add one.

# HLS CI gotchas
- **cardano-api's `test-hls-works` job type-checks EVERY `.hs` file in the tree** (`.github/workflows/hls.yml` writes a root `hie.yaml` with a bare `cradle: cabal:` as a workaround for haskell-language-server#3735, then runs `haskell-language-server` with no file arguments), so ANY file the root cabal cradle cannot load fails the job - e.g. a deliberately standalone example project that is not a package in the repo's `cabal.project` (observed 2026-09-11: `cardano-rpc/quickstart/haskell/app/Main.hs` gave "Loading the module ... failed. It may not be listed in your .cabal file!" and "296 files worked, 1 file failed").
- **A `none` cradle does NOT exempt a file from that job.** HLS's check mode tallies results with `partition fst $ zip (map isJust results) absoluteFiles` (`ghcide/src/Development/IDE/Main.hs`), and a None-cradle file yields no `TypeCheck` result, so it counts as FAILED even though HLS logs "None cradle found ..., ignoring the file" (verified empirically at hie-bios 0.21.0, exit code still 1).
  Neither placement nor cradle flavour makes any difference: a `none` sub-cradle inside a `multi` cradle fails identically (tested 2026-09-11 with the exact YAML from hie-bios's own "combine the multi-cradle with a none-cradle to ignore all source files in a certain directory" example), and hie-bios's `findCradle` walks upward from the source file to the filesystem root with no concept of a workspace root, so a `hie.yaml` above a subdirectory applies to anyone opening that subdirectory alone.
  Two hie-bios facts worth keeping even though they do not rescue this case: `none:` IS a documented `multi` sub-cradle, and multi-cradle matching is MOST-SPECIFIC-PREFIX wins, not first-match-wins, so entry order in the list is irrelevant.
  Keep such paths out of the sweep instead, and the simplest way is to DELETE them from the ephemeral CI checkout before the bare invocation (`rm -rf cardano-rpc/quickstart`), which is exactly what the step already does one line above for dist-newstyle's autogen `Paths_*`/`PackageInfo_*` files.
  Passing an explicit file list (`git ls-files -z -- '*.hs' '*.lhs' ':!:<path>' | xargs -0 haskell-language-server`) also works but is strictly worse here: it drags in xargs's default 128KB command buffer (NOT ARG_MAX), above which xargs splits into several invocations, each repeating HLS's expensive cradle setup.
- **`haskell-language-server` cannot take include-then-exclude pathspecs as separate arguments**: `expandFiles` runs an independent `git ls-files` per argument and UNIONS the results, so `<dir> ':!:<dir>/sub'` expands to far more files than intended (observed: 602 instead of ~16). Pre-compute the list in one `git ls-files` call and pass the resulting paths, which hit `expandFiles`'s `doesFileExist` fast path.

# hedgehog-extras gotchas
- For platform checks in test code use `isWin32` from `Hedgehog.Extras.Stock.OS` - never hand-roll `System.Info.os == "mingw32"`.
- **`sprocketNamedPipeName` is NOT exported** from `Hedgehog.Extras.Stock.IO.Network.Sprocket` (export list: `Sprocket (..)`, `doesSprocketExist`, `sprocketArgumentName`, `sprocketSystemName`, `maxSprocketArgumentNameLength`), so consumers cannot classify or build `\\.\pipe\` paths through it.
  On Windows `sprocketSystemName`/`sprocketArgumentName` already RETURN the named-pipe form, so code holding a `Sprocket` needs no pipe-specific handling at all; only code holding an already-rendered `FilePath` with the `Sprocket` erased has to recognise pipe paths (as cardano-testnet's `makeManifestRelPath` does, and see the filepath gotcha below for why even that guard is redundant).
- **filepath's `makeRelative`/`normalise` pass Windows named-pipe paths (`\\.\pipe\...`) through byte-for-byte unchanged**, on BOTH the `System.FilePath.Windows` and `.Posix` flavours: `splitDrive` parses `\\.\` as a synthetic drive (via the `readDriveShare` fallback), `makeRelative` short-circuits on the drive mismatch against any real base dir, and `normalise` round-trips the device prefix.
  Verified empirically on filepath-1.5.5.0 (GHC 9.12.4) and by source inspection on filepath-1.4.200.1 (GHC 9.6 boot lib, `System/FilePath/Internal.hs:941` drive-equality guard) - identical behaviour, so an explicit "keep pipe paths as-is" guard before `makeRelative` is dead code across the whole CI GHC matrix.
  Handy for tests: `System.FilePath.Windows` is importable and fully functional on Linux, so Windows path semantics can be unit-tested without a Windows machine.
- `watchdogProp`-style watchdogs (`runWithWatchdog_`) wrap Hedgehog's `propertyTest`, which reruns per generated case AND per shrink - the timeout budget is per case, not per property.

# GHC gotchas
- **GHC 9.10 rejects let-bound tuple patterns whose type is only pinned by later uses** when the components come out of an eon-constraint continuation (MonoLocalBinds).
  GHC 9.12 infers these; CI builds 9.6/9.10/9.12, so give such pattern bindings explicit component type signatures (with a scoped `era` via explicit `forall`).
  This also bites on GHC 9.12 for let/where-bound values built from a case over an era/eon witness and used later - apply the constraint-provider at the function's outermost defining equation, not inside a where-bound sub-value.
  A narrow inner constraint application (e.g. `shelleyBasedEraConstraints sbe (toList propMap)` covering only one subexpression) can silently piggyback on an enclosing wrapper and stop compiling only when the code is hoisted to `where` - re-wrap the WHOLE hoisted arm, and drop the now-redundant inner call (observed 2026-09-01 hoisting createCompatibleTx's ProposalProcedures arm: `fromList`'s `Ord (ProposalProcedure era)` needs `ProtVerLow <= ProtVerHigh`, reproduced on GHC 9.12).
- **A non-final do-statement that cases on a GADT scrutinee needs its result type pinned** (e.g. an exploded `ShelleyBasedEra` dispatch mid-property): `>>` desugaring leaves the result type a free variable, and GHC 9.6/9.10 refuse to unify it inside the era-constrained arms ("untouchable" under MonoLocalBinds).
  Bind the case as a local with an explicit signature (`checkX :: PropertyT IO ()`) and call that.
  Same family: `let x = anyEraTxConstraints sbe $ ...` needs an explicit type on `x` when its type is only pinned by later uses.
  GHC 9.12 infers all of these, so local 9.12 builds do not catch them - they surface only in CI.
- **Subclassing a ledger era class (e.g. `class L.AlonzoEraScript era => MyClass era`) needs `UndecidableSuperClasses`** - the superclass chain contains a type-family-headed constraint (`ProtVerLow era <= ProtVerHigh era`), which GHC rejects as a potential superclass cycle without the extension.
- **GHC flags a constraint used only as a caller restriction as `-Wredundant-constraints`** (e.g. `L.AlonzoEraScript (ShelleyLedgerEra era)` on a function whose body resolves instances at concrete eras anyway).
  If the constraint is meant as a static proof, either make it load-bearing (class method - but mind `UndecidableSuperClasses`/`AllowAmbiguousTypes` and constraint propagation) or replace it with an eon value witness argument (e.g. `AlonzoEraOnwards era ->`), which restricts callers AND pins the era with zero extensions.
- **EmptyCase cannot discharge values of stuck type families** (e.g. `L.PlutusPurpose L.AsIx (ShelleyLedgerEra ShelleyEra)` in a pre-Alonzo era arm): GHC's coverage checker will not assume a stuck family is uninhabited (open world - an instance could exist elsewhere), so `\case {}` triggers `-Wincomplete-patterns`, fatal under cardano-api's `-Werror` (set in `cardano-api/flake.nix`, not visible in plain `cabal build`).
  To exclude such eras statically, use a narrower witness type (`AlonzoEraOnwards era`) instead; the only alternatives are `Maybe` results or error stubs.
- **Unreachable GADT case arms under unsatisfiable constraint bundles trigger `-Woverlapping-patterns`.**
  While an era's wiring is unfinished upstream (e.g. Dijkstra), a concrete-era case arm inside `shelleyBasedEraConstraints` scope can be provably dead and must be omitted; the case stays exhaustive, and becomes non-exhaustive (a compile warning) exactly when the era lands - a useful tripwire.
- **`NoFieldSelectors` also does not allow a top-level function to share a field's name IN THE DEFINING MODULE'S own package**: any module that has both the field (via `Type (..)` import or local definition) and a same-named top-level binding in scope gets "Ambiguous occurrence" at every use site, pun or explicit `field = value` binding alike (empirically verified 2026-09-03 in cardano-rpc's NodeKernelAccess accessor refactor).
  Fix: import the record's defining module qualified-only (`qualified as Type`), reference `Type.NodeKernelAccess{Type.field = ...}` in construction/destructuring, and re-export the type abstractly via the qualified name in the export list (`module X (Type.NodeKernelAccess, ...)` - qualified names are legal in export lists and export the unqualified name).
  Do NOT use an unqualified import with `hiding (field, ...)` of the colliding fields - hiding a NoFieldSelectors-suppressed name triggers `-Wdodgy-imports`, fatal under cardano-api repo CI's `-Werror` (`program-options ghc-options: -Werror` in cardano-api's own cabal.project, which the metarepo /work builds do NOT apply - always re-verify warning-cleanliness from /work before calling a cardano-api-repo change warning-clean (mind the -Werror verification gotcha in Rules for AI agents - a naive `--ghc-options=-Werror` invocation is a silent no-op)).
- **`NoFieldSelectors` does not fix record-field name collisions for `{ }` syntax** - it only suppresses the generated selector function; GHC resolves record-update and record-construction field labels independently of whether selectors exist, so a field name colliding with another in-scope record (e.g. one re-exported by `Cardano.Api`) stays ambiguous at consumer sites on GHC 9.6/9.10/9.12 alike.
  Record UPDATE on such a field is unfixable (with `DuplicateRecordFields` it compiles but emits `-Wambiguous-fields`, a mechanism GHC has scheduled for removal); construction is fixable only by `DuplicateRecordFields` at every consumer site; `OverloadedRecordDot` reads work unconditionally.
  Inside the defining module itself the selectors are suppressed too, so internal code must pattern-match or use dot syntax.
  Empirically verified 2026-08-10 on GHC 9.6.7/9.10.3/9.12.3 (identical behaviour); this is why `CompatibleTxBodyContent` uses `compatibleTx`-prefixed field names instead of bare experimental-vocabulary names.
- **A derived `Read` instance on a fixed-width numeric type (e.g. `Word16`) silently WRAPS out-of-range literals instead of failing** (`readMaybe "70000" :: Maybe Word16` gives `Just 4464`, via `fromInteger`'s modular wraparound), so any range check placed AFTER such a read is dead code - it can never see an out-of-range value to reject.
  Read the input as `Integer` first and range-check that, before narrowing.
  Separately, `readMaybe :: Maybe Integer` accepts the full Haskell numeric-literal grammar, not just plain decimal digits - hex/octal (`"0x1F"` -> 31) and surrounding whitespace all parse - so a parser that must reject non-decimal input needs an explicit digit prefilter (e.g. `all isDigit`) before the `Integer` read, not after.
  Both empirically verified 2026-08-28 while fixing `cardano-node`'s CLI port parsers (`parsePort`/`parseHostPort` in `Cardano/Node/Parsers.hs`, which had exactly this pair of defects).

# Cardano.Api.Consensus gotchas
- **`Cardano.Api.Consensus` does NOT re-export the hard-fork history summary vocabulary**: `Ouroboros.Consensus.HardFork.History.Summary`'s `Summary (..)`/`EraSummary (..)`/`Bound (..)`/`EraEnd (..)`, `Ouroboros.Consensus.Cardano.Block.CardanoEras`, `Data.SOP.NonEmpty.nonEmptyToList`, and `Cardano.Slotting.Time.fromRelativeTime` all need direct imports (deps: `ouroboros-consensus` + `ouroboros-consensus:cardano`, `sop-extras`, `cardano-slotting`).
  It DOES re-export `HasHardForkHistory (..)` (so `hardForkSummary` works), and `mkInterpreter`; but the `Interpreter` inside cardano-api's `EraHistory` is opaque (constructor not exported by consensus), so per-era data must be taken from the `Summary` BEFORE `mkInterpreter` wraps it - see `readHardForkSummary` in cardano-rpc's `NodeKernelAccess.hs`.
  At the pinned ouroboros-consensus-3.0.1.0, `Bound` has a FOURTH field `boundPerasRound :: PerasEnabled PerasRoundNo` - use record syntax when constructing fixtures.
- **`Cardano.Api` re-exports the WHOLE of `Cardano.Api.Consensus`** (`, module Cardano.Api.Consensus` in `Cardano/Api.hs`), so anything added to `Cardano.Api.Consensus.Internal.Reexport` lands in every module that does a bare `import Cardano.Api`.
  Two consequences: adding an operator there is a downstream ambiguity hazard (re-exporting sop-core's `NP (..)` collides with grpc-spec's unrelated `:*` in cardano-rpc), and an explicit `import Cardano.Api.Consensus (Foo)` next to `import Cardano.Api` is reported redundant by `-Wunused-imports`.
  For operator-shaped names prefer depending on the defining package directly (e.g. `strict-sop-core` for `Data.SOP.Strict (NP (..))`).
- **Extracting per-era genesis from a `TopLevelConfig (CardanoBlock StandardCrypto)` only needs `configLedger`**, never `configBlock`.
  `PartialLedgerConfig` already holds the complete genesis and translation context - `completeLedgerConfig` only patches the epoch info - and the Byron `LedgerConfig` IS the `Cardano.Chain.Genesis.Config` that `configBlock`'s `ByronConfig` wraps, so one `getPerEraLedgerConfig . hardForkLedgerConfigPerEra` walk yields Byron genesis data and hash, the compacted Shelley genesis, and `shelleyLedgerTranslationContext` at Alonzo (`= AlonzoGenesis`) and Conway (`= ConwayGenesis`).
  Match the `NP` positionally and exhaustively down to `Nil` (8 eras: Byron, Shelley, Allegra, Mary, Alonzo, Babbage, Conway, Dijkstra) - GHC accepts that as complete, so a new era becomes a compile error rather than a silent off-by-one.
  The Dijkstra slot works exactly the same way (`TranslationContext DijkstraEra = DijkstraGenesis`), so the walk yields a REAL Dijkstra genesis from the running node.
- **`TopLevelConfig` does NOT retain the `TransitionConfig` it was built from.**
  `CardanoProtocolParams` takes `cardanoLedgerTransitionConfig`, but `protocolInfoCardano` decomposes it in a `where` clause and stores only the compacted per-era `ShelleyLedgerConfig`s.
  To get a `TransitionConfig LatestKnownEra` back at runtime, rebuild it with `mkLatestTransitionConfig` from the per-era translation contexts recovered by the `configLedger` walk above.
- The `blk ~ CardanoBlock StandardCrypto` equality needed for that walk comes from matching the `CardanoBlockType` constructor of cardano-api's `BlockType` GADT.
  There is no `withBlockTypeConstraints` helper anywhere in cardano-api or cardano-node, despite what some docs claim.

# cardano-api import gotchas
- **`Cardano.Api` re-exports the whole of `Cardano.Api.Monad.Error`**, which in turn re-exports `Control.Monad.Except`, `Control.Monad.Trans.Except` and `Control.Monad.Trans.Except.Extra`.
  So `ExceptT`, `runExceptT`, `MonadError`, `liftEither` and friends are already in scope after a bare `import Cardano.Api` - do NOT add `import Control.Monad.Trans.Except (runExceptT)`, which fails with "member of the hidden package transformers" unless the package also depends on `transformers` directly.
  Same trap for `Data.Text (Text)`: several `Cardano.Api.*` modules re-export it, so an explicit import is flagged redundant under `-Wunused-imports`.
- `Cardano.Api` also re-exports the whole of `Cardano.Api.LedgerState`, so `GenesisHashShelley (..)`, `ShelleyConfig (..)`, `readShelleyGenesis` and `renderShelleyGenesisError` are reachable from a bare `import Cardano.Api`.
- **`RIO` (cardano-rpc's prelude) re-exports `Proxy (..)` unqualified** (via `RIO.Prelude.Types`), so `import Data.Proxy (Proxy (..))` next to `import RIO` is redundant - fatal `-Wunused-imports` under the repo flake's `-Werror`, and invisible to plain /work cabal builds (observed 2026-09-09, cost a full nix verification cycle).
  Same family as the `Cardano.Api`/`Text` trap above; RIO also covers `Map`, `Set`, `Text`, `ByteString`, `Word*`/`Int*` and friends - check RIO's re-export surface before adding an explicit base/containers import in cardano-rpc.

# Ledger TransitionConfig gotchas
- `Cardano.Ledger.Api.Transition` exports only THREE lenses: `tcShelleyGenesisL`, `tcPreviousEraConfigL` and `tcTranslationContextL`.
  There is no `tcAlonzoGenesisL`/`tcConwayGenesisL`/`tcDijkstraGenesisL` at the api level - reach those by chaining `tcPreviousEraConfigL` down to the era you want, then `tcTranslationContextL` (whose result is that era's genesis).
  A `tcConwayGenesisL` does exist in `Cardano.Ledger.Conway.Transition`'s `ConwayEraTransition` class, but cardano-ledger-api neither imports nor re-exports it.
- `mkLatestTransitionConfig` takes FOUR genesis arguments - Shelley, Alonzo, Conway, Dijkstra - because `LatestKnownEra = DijkstraEra` at the pinned cardano-ledger-api 1.13; Allegra, Mary and Babbage get `NoGenesis`.
  `DijkstraGenesis` has no `Default` instance and no genesis-file plumbing, which is why cardano-api's `readCardanoGenesisConfig` hand-rolls `exampleDijkstraGenesis`; code with access to a live `TopLevelConfig` should use the real one from the ledger config instead.

# cardano-node golden test gotchas
- **Bumping cardano-api/cardano-rpc/cardano-cli versions in cardano-node breaks `golden_VersionCmd`** (`cardano-testnet-golden` suite): `cardano-testnet/test/cardano-testnet-golden/files/golden/version_cmd.cli` pins the exact "built against" versions printed by `cardano-testnet version`.
  Update that golden file in the same commit as the bump; local `cabal test cardano-node` does not catch it (the test lives in `cardano-testnet-golden`, a separate suite CI runs but "test cardano-node" does not).

# cardano-node tracing gotchas
- The "Configuration Consistency" golden tests (`Test.Cardano.Tracing.NewTracing.Consistency`, run by `cabal test cardano-node-test`) only check that namespaces MENTIONED in `configuration/cardano/mainnet-config.json`, `goodConfig.yaml` and `badConfig.yaml` are legal.
  They do not assert a complete namespace list, so adding or removing a trace namespace does not touch any golden file.
  `bench/trace-schemas/newNamespaces.txt` is a checked-in generated snapshot of all namespaces, but it is already stale and no CI workflow regenerates or validates it.
- Every `MetaTrace`/`LogFormatting` clause list in `Cardano/Node/Tracing/Tracers/*.hs` is hand-maintained.
  A new trace constructor needs adding to `forMachine`, `namespaceFor`, `severityFor`, `documentFor`, `allNamespaces` and (where relevant) `asMetrics`/`metricsDocFor` - GHC only catches the first two, the rest silently fall through to their `_ -> Nothing` / `_ -> []` default.
- **New `TraceRpcSubmit` constructors in cardano-rpc REQUIRE updating cardano-node's `Cardano/Node/Tracing/Tracers/Rpc.hs` in the same change** - the hand-maintained `LogFormatting`/`MetaTrace` instances there hit a non-exhaustive case at runtime otherwise, and the resulting `PatternMatchFail` is caught by the RPC server's top-level handler and surfaced to gRPC clients as an opaque `GrpcUnknown "Internal error while processing the request."` on the affected method (observed 2026-09-07: the ReadMempool E2E failed on every call because the three new mempool span constructors were missing from Rpc.hs; the node log only reveals the real exception at `["Error"]` severity Notice or above, default Debug hides it).

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
- **`datumTxOutL` lens for attaching datum hashes only works Babbage-onwards** (`BabbageEraTxOut`); at Alonzo the TxOut has only a bare datum-hash field.
  Use `dataHashTxOutL` (`AlonzoEraTxOut`) for Alonzo, then split on `AlonzoEraOnwards` for code era-generic over Alonzo-onwards (see mkUTxOScript in tx-generator's UTxO.hs).
- **`shelleyBasedEraConstraints` gained a real Dijkstra arm in cardano-api 11.6.0.0** (`ShelleyBasedEraDijkstra -> id`, verified 2026-08-25), so it is safe in all 7 eras when building against >= 11.6.
  Against cardano-api <= 11.5 it errors at runtime for Dijkstra: there, either match all 7 `ShelleyBasedEra` constructors explicitly to get the narrow constraint needed, or use a narrower always-total helper like `eraTxOutConstraints` (tx-generator's Utils.hs, which provides just `EraTxOut` for all 7 eras).
- cardano-api symbol reachability depends on export-list chains, not module names or paths: `Cardano.Api.Tx.Internal.Output` is `other-modules` in 11.3 (so `toBabbageTxOutDatum` and the `ScriptDataHash` constructor are unreachable outside the package), yet `AlonzoEraOnwards (..)` IS in scope via plain `Cardano.Api` despite living in an `Internal` other-module, because the exposed `Cardano.Api.Era` re-exports it.
  Verify against the package's cabal `exposed-modules` and export lists, never path names.
- There is NO experimental analogue of `toBabbageTxOutDatum` (checked cardano-api 11.3 and current master): the ledger-lens recipe above IS the idiomatic way (cardano-api's own `FromJSON (Exp.TxOut era)` instance uses it internally).
  False friend: the experimental `Datum ctx era` GADT in `Cardano.Api.Experimental.Tx` has TxOut-flavoured constructor names (`TxOutDatumHash`/`TxOutDatumInline`/`TxOutSupplementalDatum`) but is ONLY for reference-input datum collection (`TxInsReference`), not for attaching datums to a `TxOut` under construction.
  Supplemental datums pair the TxOut's `DatumHash` with `setTxSupplementalDatums` on the `TxBodyContent`.
- Native script patterns (`RequireAllOf` etc.) are NOT in `Cardano.Api.Ledger`.
  Import `Cardano.Ledger.Shelley.Scripts` (and `Allegra`/`Dijkstra` variants) for them.
  **Import standalone pattern synonyms ONLY via list-free (wildcard) qualified imports** - it is the only form valid across the whole CI matrix:
  a bare `Foo` in an explicit import list fails on GHC <= 9.12 ("module does not export", misleading), `pattern Foo` is deprecated on GHC 9.14 (`-Wpattern-namespace-specifier`, fatal under `-Werror`), and the replacement `data Foo` keyword is 9.14-only syntax that breaks older GHC.
  Matching pattern synonyms needs no `PatternSynonyms` pragma - after switching to wildcard imports, hlint flags the pragma as unused; remove it.
- **GHC 9.12 does not honour era-indexed `COMPLETE` pragmas through a type-family-typed scrutinee**: matching the four `MultiSig` patterns on `NativeScript ShelleyEra` still warns non-exhaustive despite ledger's `COMPLETE ... :: ShelleyEra` pragma (empirically verified) - keep a defensive wildcard.
- `PolicyAssets`' Show instance prints `policyAssetsFromList`, but no such function exists.
  Use `GHC.Exts.fromList` (`IsList` instance); `valueFromList` for `Value` is deprecated in favour of `fromList` too.
- Era TAG types (`BabbageEra` etc.) and `CardanoEra` constructors pun the same names in different namespaces.
  Importing `CardanoEra (..)` without the tag types makes a type-position `BabbageEra` resolve to the DataKinds-promoted constructor, giving a baffling kind error ("'BabbageEra' has kind 'CardanoEra BabbageEra'").
  Import the tag types explicitly alongside `CardanoEra (..)` in explicit import lists.

- **Reading-direction redeemer pointer classification lives in `toPlutusScriptPurposeIndex`** (`Cardano.Api.Experimental`): `ShelleyBasedEra era -> L.PlutusPurpose L.AsIx (ShelleyLedgerEra era) -> (PlutusScriptPurpose, Word32)`, the inverse of `toPlutusScriptPurpose`.
  The witness argument pins the era, so call sites need no constraints and no type applications; unlike old-API `toScriptIndex` it handles `DijkstraGuarding` (old `toScriptIndexDijkstra` errors on it).
  The pre-Alonzo arms are `error` stubs that are semantically unreachable (`PlutusPurpose` is a stuck family there, no argument can exist) but unprovable to GHC - callers are safe because pre-Alonzo redeemer getters yield nothing.
  Rejected alternatives: `Maybe` result (pushes unwrapping onto every caller), empty case (`-Wincomplete-patterns`, fatal under `-Werror`), bare `AlonzoEraScript` constraint (`-Wredundant-constraints`), a class (`UndecidableSuperClasses` + `AllowAmbiguousTypes` + constraint propagation), `AlonzoEraOnwards` witness (eons are being phased out).
  The ledger-side building blocks are the per-tier projections: `to{Spending,Minting,Certifying,Rewarding}Purpose` (`AlonzoEraScript`), `to{Voting,Proposing}Purpose` (`ConwayEraScript`), `toGuardingPurpose` (`DijkstraEraScript`) - no single ledger class covers all tiers.

# Ledger stake pool params gotchas
- **`StakePoolParams (..)` (fields `sppId`/`sppOwners`/`sppVrf`/...), `toVRFVerKeyHash` and `AccountAddress (..)` come from cardano-api's `Cardano.Api.Ledger.Internal.Reexport`, NOT from `Cardano.Ledger.Api`** (checked cardano-ledger-api 1.13: its Tx.Cert module uses `StakePoolParams` in signatures but never re-exports it).
  Both `Fee.hs` estimator modules import BOTH modules under the same `L` alias, so `L.sppOwners` resolving there does not mean `Cardano.Ledger.Api` exports it - check which module behind a merged alias actually provides a symbol before copying an import pattern.
  `AccountId` and the deprecated `RewardAccount` pattern are NOT reachable via `Cardano.Api.Ledger`; for test fixtures use `def` (`Data.Default`) for `sppAccountAddress` instead of constructing an `AccountAddress` by hand.

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
- **The `StakeCredential` in `TxCertificates`' `(StakeCredential, witness)` pairing is always DERIVED from the certificate, never caller-supplied.**
  Every construction path (`mkTxCertificates` in both the legacy and experimental cardano-api builders, and cardano-cli's own `mkTxCertificatesSbe`) computes it via `getTxCertWitness`, which wraps ledger's `getVKeyWitnessTxCert`/`getScriptWitnessTxCert`; callers supply only cert and witness.
  Consequently the credential is redundant, recomputable data wherever the `TxCert` is in hand - this is why `Witnessable`'s `WitTxCert` needs no credential field.
  Mind the ledger-inherited simplification: `getVKeyWitnessTxCert` returns a SINGLE key hash, so pool registration certs surface only the operator key (`sppId`) - the owners (`sppOwners`) never enter this pipeline and are handled by the general signing machinery; pool certs also cannot be script-witnessed.

# Ledger PParams HKD gotchas
- The `hkd*L` class lenses (e.g. `hkdMaxTxSizeL`) always need explicit type applications `@era @f` at use sites.
  `PParamsHKD` and `HKD` are non-injective type families, so GHC cannot infer `f` from a `PParamsHKD f era` value; a signature abstracting over `f` also needs `AllowAmbiguousTypes` in the defining module.
  Pattern: cardano-rpc's `pparamsFieldSetters` (one field table serving both `PParams` via `ppLensHKD` at `Identity` and `PParamsUpdate` via `ppuLensHKD` at `StrictMaybe`).
- `AlonzoEraPParams` methods are NOT reachable via the `Cardano.Ledger.Conway.Core` re-export chain: `Cardano.Ledger.Alonzo.Core` exports the class WITHOUT `(..)` (unlike `BabbageEraPParams (..)` in Babbage.Core), and `Cardano.Ledger.Api.PParams` also exports only the class names.
  Depend on `cardano-ledger-alonzo` directly and import `Cardano.Ledger.Alonzo.PParams` for `hkdCostModelsL`, `hkdPricesL`, `hkdMaxValSizeL` etc.
- `hkdProtocolVersionL` requires `AtMostEra "Babbage" era` - it does not exist for Conway onwards (updates cannot carry the protocol version there).
  Use `ppProtocolVersionL` on the full `PParams` instead; it is unconditional.

# Ledger core type gotchas
- **`TxOut` is NOT memoised - `serialize'` of a decoded `TxOut` is a canonical re-encoding, not the original chain bytes.**
  Only `TxBody`, `Data` and scripts carry `MemoBytes`/`SafeToHash` originals; TxOut decoders accept non-canonical input (Babbage+ TxOut is a CBOR map with free key order, plus indefinite-length/non-minimal-int freedom), so decode-then-encode can differ from the submitter's bytes on historical outputs.
  Consequently spec fields demanding on-chain byte fidelity (utxorpc `original_cbor`/`native_bytes`) can only be populated faithfully from memoised values (`originalBytes`, `getOriginalScriptDataBytes`) or raw fetched bytes (ChainDB block fetch); anything built via `toShelleyTxOut` + `serialize'` is a re-encoding and must be documented as such (see `txOutToUtxoRpcTxOutput`).
  The UTxO-set case is unfixable in principle: the node stores compacted TxOuts and N2C re-serialises, so original bytes for query responses do not exist anywhere in the node.
  The same applies to WHOLE SIGNED TXS taken from the mempool: the ledger `Tx` inside a consensus `GenTx` is a plain data type (not MemoBytes-backed, checked cardano-ledger-alonzo AlonzoTx), so `serialiseToCBOR` after `fromConsensusGenTx` is a canonical re-encoding of the submitted tx, never the submitter's original bytes.
- `PoolMetadata`'s `pmHash` is a `ByteArray`, not a `ByteString`.
  Convert with `SBS.fromShort . byteArrayToShortByteString` (from mempack's `Data.MemPack.Buffer`, requires a `mempack` build-dep) - same as cardano-api's `Cardano.Api.Certificate.Internal` does.
- **`KeyRole` (`Cardano.Ledger.Keys.Internal`) is declared with `type data KeyRole = ... | DRepRole | StakePool | HotCommitteeRole | ...`** (GHC's `TypeData` extension), not a normal `DataKinds`-promoted `data` declaration.
  Role types are therefore written WITHOUT a promotion tick - `L.Credential L.DRepRole`, not `L.Credential 'L.DRepRole` - and `KeyRole (..)` is fully reexported by `Cardano.Api.Ledger`, so the role names are reachable via the conventional `qualified as L` alias.
  `HasKeyRole`/`coerceKeyRole` is a different story: `Cardano.Api.Ledger` reexports the class name `HasKeyRole` WITHOUT `(..)`, so `coerceKeyRole` itself is not reachable through it - import `Cardano.Ledger.Keys (coerceKeyRole)` directly if role-coercion is actually needed.
  Usually it isn't: `Cardano.Api.Key` (reexported by bare `Cardano.Api`) already provides one `Hash <Role>Key` newtype per governance/pool role, each with its own unwrapper straight to the ledger `KeyHash` of that role - e.g. `unDRepKeyHash :: Hash DRepKey -> L.KeyHash L.DRepRole`, `unStakePoolKeyHash :: Hash StakePoolKey -> L.KeyHash L.StakePool`.
  In Hedgehog tests, generating `unXKeyHash <$> genVerificationKeyHash AsXKey` (`Test.Gen.Cardano.Api.Typed`) is the idiomatic way to get a role-correct ledger key hash for constructing e.g. `L.Voter`/`L.Credential` values, no `coerceKeyRole` needed.

# Consensus genesis gotchas
- **The full uncompacted genesis DOES survive node startup - in cardano-node's `runP`, not in consensus.**
  `mkSomeConsensusProtocolCardano` embeds the full `ShelleyGenesis` (plus Alonzo/Conway/Dijkstra genesis) in the `TransitionConfig` inside `CardanoProtocolParams`, wrapped as `SomeConsensusProtocol`/`ProtocolInfoArgsCardano`; Run.hs threads that value (`runP`) into `handleSimpleNode`, whose scope covers the whole node lifetime including the `rnNodeKernelHook` lambda.
  Compaction (`compactGenesis`, erasing `sgInitialFunds`/`sgStaking`) happens afresh inside every `Api.protocolInfo runP` call when it builds a `TopLevelConfig` - `runP` itself stays pristine, so code at the hook site can take the genesis from `runP` instead of re-reading the file.
  The Shelley `GenesisHash` itself is no longer unrecoverable either: `readGenesisAny` computes it at boot (folding it into the Praos initial nonce via `genesisHashToPraosNonce` as before), and that same hash is now returned from `mkConsensusProtocol`/`mkSomeConsensusProtocolCardano` as a plain `GenesisHashShelley` alongside `SomeConsensusProtocol` (a tuple - the `SomeConsensusProtocol` constructor keeps its upstream 2-field shape), threaded through `Run.hs` into cardano-rpc; the other eras' hashes are still bound to `_`-names and discarded.
- **The in-memory `ShelleyGenesis` from `TopLevelConfig` has `sgInitialFunds` and `sgStaking` erased**: `ShelleyLedgerConfig` stores only a `CompactGenesis` (`Ouroboros.Consensus.Shelley.Ledger.Config`), whose `compactGenesis` wipes exactly those two fields, and `shelleyLedgerGenesis` unwraps that compacted value.
  Recover them from the on-disk genesis JSON: `"initialFunds"` is a mandatory `FromJSON` key, `"staking"` is optional (defaults to `emptyGenesisStaking`); mainnet and the testnet template have both empty/absent anyway - only custom networks populate them, and cardano-testnet's genesis does so via `sgExtraConfig`, NOT `sgInitialFunds` (see the create-testnet-data gotcha below).
  The Shelley genesis HASH is no longer in that boat: `mkConsensusProtocol`/`mkSomeConsensusProtocolCardano` now return it as a plain `GenesisHashShelley` in a tuple alongside `SomeConsensusProtocol`, set at boot time from the hash `Cardano.Node.Protocol.Shelley.readGenesis` already computes, and `Run.hs` threads it into cardano-rpc.
  There is no `Maybe` and no extra constructor field: only the Cardano protocol has a boot-time hash to return, the Byron-only and Shelley-standalone protocols never reach a cardano-rpc `GenesisBundle` at all, so the optionality is gone end-to-end.
  Alonzo/Conway genesis HASHES are still not recoverable from `TopLevelConfig` - hash the raw file bytes with Blake2b-256, as `Cardano.Node.Protocol.Shelley.readGenesis` does at startup; the file paths live in cardano-node's `NodeConfiguration` (`ncProtocolConfig` -> `npc*GenesisFile`).
- **`cardano-cli create-testnet-data` (used by cardano-testnet's `createSPOGenesisAndFiles`) leaves the legacy `sgInitialFunds` field EMPTY and puts the funded addresses in `sgExtraConfig.secInitialFunds` instead** (cardano-cli 11.2.1.0, `Cardano.CLI.EraBased.Genesis.CreateTestnetData.Run`).
  The ledger reconciles the two only at NewEpochState construction (`resolveInjectionSource` in `Cardano.Ledger.Shelley.Transition`) and never writes back into the `ShelleyGenesis` value, so the chain boots funded while every direct read of `L.sgInitialFunds` - even on the full uncompacted on-disk genesis - sees `mempty`.
  Mind that `resolveInjectionSource` is NOT a preference order: it takes whichever single source is populated and throws `InjectionConflictingSources` when both are (verified 2026-09-09 at ledger commit ae2c8912; flagged by review on cardano-node PR #6657).
  Any consumer wanting initial funds (e.g. cardano-rpc's `shelleyGenesisToProto`) must resolve like the ledger does, minding that `InjectionData` also has an `InjectionFromFile` (hash-verified external JSON) constructor besides `EmbeddedInjection`.
  Discovered via cardano-node PR #6655: the `hprop_rpc_read_genesis` assertion that `ReadGenesis` returns non-empty `initialFunds` fails deterministically on every platform.
  On-disk JSON shapes differ between the two locations (verified at pinned cardano-cli 11.2.2.0 / cardano-ledger-shelley 1.19.0.0): `extraConfig.initialFunds` wraps the map in an `InjectionData` object (`{"data": {"<hex-serialiseAddr>": <lovelace>}}` for `EmbeddedInjection`; `{"file": [...], "hash": "..."}` for `InjectionFromFile`), while the legacy top-level `initialFunds` is the flat unwrapped map.
  cardano-cli PR #1420 (which would have moved create-testnet-data's funds back to the top-level `initialFunds`) was closed won't-fix (per review on cardano-node PR #6657, 2026-09-08), so funds stay in `sgExtraConfig`; consumers should still fall back on key absence for legacy genesis layouts, since `sgExtraConfig` is a `StrictMaybe` whose `SNothing` OMITS the whole `"extraConfig"` key (see `hprop_rpc_read_genesis`'s expected-funds oracle).

# Consensus state query gotchas
- **Every Ogmios-parity ledger query has an existing `BlockQuery` constructor** at pinned ouroboros-consensus 3.0.1.0 (`Ouroboros.Consensus.Shelley.Ledger.Query`, 40 constructors): pool distribution is `GetPoolDistr2` (filtering via its `Maybe (Set PoolId)` argument, there is no separate Filtered constructor and plain `GetPoolDistr` is deprecated), treasury/reserves is `GetAccountState` (`ChainAccountState`), rewards provenance is `GetRewardProvenance`/`GetRewardInfoPools` (the former is known-heavy), and the Conway governance queries (`GetGovState`, `GetConstitution`, `GetCommitteeMembersState`, `GetDRepState`, `GetDRepStakeDistr`, `GetProposals`) are Conway-onwards by constraint.
- **Nonces and opcert counters have no stable N2C query** - only `DebugChainDepState`, whose encoding carries no cross-version compatibility guarantee.
  With node kernel access they are reachable fully typed instead: `headerStateChainDep . headerState` of the `ExtLedgerState` returned by `getCurrentLedger chainDb` (the same STM read `readEraHistory` in cardano-rpc's `NodeKernelAccess.hs` already performs); Praos (`PraosState`) keeps `praosStateOCertCounters` plus six nonce fields, TPraos wraps the ledger-level `ChainDepState`.
- **`executeLocalStateQueryExpr` already takes a `Net.Query.Target ChainPoint`** (`VolatileTip` or `SpecificPoint`); every cardano-rpc call site currently hardcodes `VolatileTip`, so point-pinned queries need no new machinery, just a point threaded through.
  Both `SpecificPoint` acquisition and `ChainDB.getPastLedger` go through the same LedgerDB forker and share the same hard retention window: the last k blocks of the current chain.
- **The N2C LocalTxMonitor protocol is acquire-snapshot-then-query** - a watcher built on it must poll by re-acquiring.
  Event-driven mempool streaming needs the kernel path: `getMempool` on `NodeKernel`, `Mempool.getSnapshot` is a plain STM read (so blocking watchers use ordinary STM retry), and `snapshotTxsAfter` keyed by ticket number gives incremental delivery for a watch stream.

# Ledger native script gotchas
- **The native-script view patterns (`RequireSignature`, `RequireAllOf`, ..., `RequireTimeStart`) have era-indexed `COMPLETE` pragmas** for Shelley through Conway (none for Dijkstra, checked cardano-ledger-dijkstra 0.2.0.1).
  In practice GHC 9.12 does not honour them when the scrutinee's type is the `NativeScript` type-family application (see GHC gotcha above), so matches need a defensive wildcard in ALL eras regardless.

# Ledger aux data gotchas
- Tx metadata is uniformly accessible in all eras via `metadataTxAuxDataL` (`EraTxAuxData` class method; `EraTx` implies it).
- Auxiliary scripts line up with the era's `Script` type at concrete eras: Allegra/Mary `nativeScriptsTxAuxDataL` yields `Timelock` (= `Script`), Alonzo onwards `getAlonzoTxAuxDataScripts` merges timelocks and plutus scripts into `AlonzoScript` (= `Script`, including Dijkstra).
  So aux scripts convert through `fromShelleyBasedScript` when matching concrete `ShelleyBasedEra` constructors (see `txAuxDataScripts` in cardano-rpc's `Type.hs`).
- All of this is exported via `Cardano.Ledger.Api` (from `Cardano.Ledger.Api.Tx.AuxData`, including `Metadatum (..)`).

# Dijkstra era gotchas
- For era dispatch in cardano-rpc, match all seven `ShelleyBasedEra` constructors explicitly, never with wildcards.
  At concrete eras every type family reduces and every ledger instance resolves, including Dijkstra, so no eon constraint machinery is needed, and a new era becomes a compile error at every dispatch site.
  Do NOT use `caseShelleyToBabbageOrConwayEraOnwards` (Dijkstra `error` stub up to cardano-api 11.5; real arm since 11.6.0.0), do NOT add bespoke dispatchers to `Case.hs`, and do NOT nest `forShelleyBasedEraInEon`.
  See `txCertToUtxoRpcCertificate` and `redeemersByIndex` in cardano-rpc for the accepted pattern.
- cardano-ledger-api's `AnyEra*` classes (`AnyEraTx`, `AnyEraTxBody`, `AnyEraTxWits`) provide uniform era-gated getters (`mintTxBodyG` etc.; `Nothing` where the era predates the field) and are Dijkstra-total; cardano-rpc's `anyEraTxConstraints` brings them plus `IsShelleyBasedEra` into scope from a `ShelleyBasedEra` witness.
  `AnyEraTxCert` however CANNOT read pre-Conway stake delegations: `anyEraToDelegTxCert` is `const Nothing` before Conway and no legacy `DelegStakeTxCert` getter exists, so certificate reading needs the concrete-era matchers instead.
- Dijkstra eon wiring COMPLETED in cardano-api 11.6.0.0 (verified 2026-08-25): all eon constraint bundles and all `caseShelleyTo*` dispatchers in `Era/Internal/Case.hs` now have real Dijkstra arms, and no "TODO Dijkstra" error stubs remain; `conwayEraOnwardsConstraints` works too (its bundle now uses the `L.ConwayEraTxCert` class constraint, not `TxCert ~ ConwayTxCert`).
  Up to cardano-api 11.5, ALL eon constraint bundles except `alonzoEraOnwardsConstraints` error at runtime for Dijkstra - mind this when reading code or building against older pinned versions.
  Flip side of the completion: era case expressions that had to OMIT a provably-dead Dijkstra arm under 11.5 become non-exhaustive (fatal under `-Werror`) on the 11.6 bump - the documented tripwire; e.g. cardano-cli's `mkTxOut` needed a `ShelleyBasedEraDijkstra` arm mirroring Conway, which is correct because ledger models `TxOut DijkstraEra = BabbageTxOut DijkstraEra` with Babbage's lenses.
  The experimental `obtainCommonConstraints` IS Dijkstra-total, but the experimental `Era` GADT only has Conway and Dijkstra constructors, so it cannot drive code that must also handle historical eras.
- Dijkstra has `ConwayEraTxCert DijkstraEra` (so `mkDelegTxCert` works) but NOT `ShelleyEraTxCert`.
- `TxCert DijkstraEra = DijkstraTxCert DijkstraEra` - its own concrete type, NOT `ConwayTxCert DijkstraEra`.
  It reuses `PoolCert` and `ConwayGovCert`, but has its own `DijkstraDelegCert` (deposits are mandatory `Coin`, not `StrictMaybe Coin`); convert losslessly with `dijkstraToConwayDelegCert` from `Cardano.Ledger.Dijkstra.TxCert` (package cardano-ledger-dijkstra).

# grapesy client-streaming gotchas
- **`Network.GRPC.Client.StreamType.IO.serverStreaming`'s `recv` action swallows the gRPC error status.**
  It is grapesy's `recvNextOutputElem`, which maps both a clean end of stream AND an error-terminated stream to the same `NoNextElem` value - it never calls `responseTrailingMetadata`, so a server that throws before sending any message (e.g. cardano-rpc's `FollowTip` with an unmatched intersect list, expected to fail with `NOT_FOUND`) is observed by the client as a stream that succeeded with zero elements, not as a `GrpcException`.
  `nonStreaming`'s equivalent (`recvFinalOutput`) does not have this problem: it goes through `recvOutput`, which does check trailers and throws.
  To assert a streaming RPC fails before yielding anything, bypass `serverStreaming`/`clientHandler` helpers and drive the call directly: `Rpc.withRPC conn def (Proxy @(Rpc.Protobuf Service "method")) $ \call -> Rpc.sendFinalInput call request >> Rpc.recvOutput call` - `recvOutput` raises `GrpcException` on a non-OK terminal status even when zero messages were sent.
  All these (`withRPC`, `sendFinalInput`, `recvOutput`) are already re-exported by `Cardano.Rpc.Client` via `Network.GRPC.Client`, no extra import needed.
  See `followTipExpectingError` in cardano-node's `Cardano.Testnet.Test.Rpc.FollowTip`.
- **A grapesy server-streaming HANDLER that returns normally must send the terminal `NoNextElem` (`NoMoreElems`) marker first** - otherwise the HTTP2 stream is cancelled instead of closed with proper trailers (verified against grapesy's Server/Call.hs, 2026-09-07).
  There was no in-tree precedent before cardano-rpc's `waitForTxStream`: `followTipStream` never returns normally, so the requirement never surfaced.
  Unit-test the exact final element (see `hprop_wait_for_tx_stream_*` in cardano-rpc's `Test.Cardano.Rpc.WaitForTxStream`).
  The SAME applies to BIDI-streaming handlers: grapesy-1.1.1's `FromStreamingHandler BiDiStreaming` and `FromStreamingHandler ServerStreaming` route through byte-identical `sendOutput call . fromNextElem call` code (verified in Server/StreamType.hs, 2026-09-09), so a bidi handler must also push `NoNextElem` before returning (precedent: cardano-rpc's reflection handler, tested by `hprop_server_reflection_info_v1_sends_terminal_marker`).

# http2 / time-manager server gotchas (verified against http2-5.3.9, time-manager-0.3.2, http2-tls-0.4.9 sources, 2026-08-31)
- **Passing a live (positive-timeout) `confTimeoutManager` to http2's server `run` kills server-streaming handlers that go quiet between chunks.**
  The `T.pause`/`T.resume` in `Network/HTTP2/Server/Worker.hs` brackets ONLY the `outBodyPush` write into a 10-element TBQueue (to survive backpressure), NOT the wait while the handler computes or blocks (e.g. an STM retry awaiting the next chain tip) - such a handler sits Active and gets `TimeoutThread` thrown into it.
  This is why grapesy hardcodes a disabled manager (`disableTimeout = 0` in its private Util/HTTP2.hs); an idle-connection reaper must therefore live OUTSIDE http2 (own manager keyed per connection, tickled from wrapped send/recv), never on `confTimeoutManager`.
- **time-manager's `withHandle` does NOT kill the registering thread on timeout** - it only runs the supplied action and returns `Nothing`; only `withHandleKillThread` throws `TimeoutThread`.
  network-run's timeout server variant uses `withHandle` with a no-op action, so the handle it passes down reaps nothing at all.
- **http2-tls's `tcpIOBackend` uses a PARTIAL write (`void . NSB.send`) for its `send`** - do not use it to build an http2 `confSendAll` (grapesy uses `sendAll`; reimplement with `sendAll`).

# proto-lens gRPC method registration gotchas
- **grapesy's `Methods` GADT has an `UnsupportedMethod` constructor - use it for spec methods without handlers.**
  It registers nothing for that RPC path, and grapesy answers unregistered paths with the `UNIMPLEMENTED` gRPC status automatically, so no `Method (mkNonStreaming $ const $ throwIO GrpcException{grpcError = GrpcUnimplemented, ...})` boilerplate is needed (cardano-rpc's `Server.hs` used to hand-roll exactly that for `dumpHistory`).
  It also works for any streaming shape, since it takes no handler.
- **Setting a proto ENUM field on a grapesy `Proto`-wrapped message needs the enum VALUE wrapped in `Proto` too** (e.g. `U5c.vote .~ Proto U5c.VOTE_YES`): grapesy's `RewrapField` classifies enums as non-scalar, so the field lens exposes `Proto EnumType`, and a bare enum value fails with a confusing functional-dependency error.
  Precedent: `plutusScriptPurposeToRedeemerPurpose` in cardano-rpc's `TxEval.hs`.
- **grapesy wraps oneof SUM types in `Proto` too, but pattern-matching the sum yields UNWRAPPED payloads**: `msg ^. maybe'oneofField` returns `Maybe (Proto TheOneofSum)` (RewrapField treats the sum as non-scalar, like enums), so matching needs `Just (Proto variant) -> case variant of ...` with `Proto (..)` imported from Network.GRPC.Spec; the values bound out of the sum's constructors (e.g. a `StakeDelegationCert`) are raw generated types - re-wrap locally at each field access (`Proto delegCert ^. UtxoRpc.stakeCredential`).
  Matching all of a oneof's constructors exhaustively (no wildcard arm) makes a proto regen that adds a variant a compile error under -Werror - the accepted drift tripwire; precedent: `certificateCredentials` in cardano-rpc's `Predicate.hs`.
- **Adding same-named oneofs/fields to two different proto files can break cardano-rpc's hand-written re-export modules** (e.g. `Cardano.Rpc.Proto.Api.UtxoRpc.Query` re-exports both `Cardano_Fields` and `Query_Fields` wholesale): the new colliding lenses (e.g. `maybe'query`, `maybe'result`) surface as conflicting-export errors, fixed by extending the `hiding` list on one import.
- **A service's generated `type ServiceMethods` list (`gen/Proto/.../<Service>.hs`) is sorted ALPHABETICALLY by method name, not in `.proto` declaration order** - but the `Methods`/`Method` chain built in `Server.hs` (e.g. `methodsUtxoRpc`, `methodsSyncRpc`) must be in `ServiceMethods` order, since grapesy resolves handlers positionally against that type-level list.
  Concretely: `QueryService`'s methods are declared `ReadParams, ReadUtxos, SearchUtxos, ReadGenesis` in `query.proto`, but proto-lens emits `ServiceMethods QueryService = '["readGenesis", "readParams", "readUtxos", "searchUtxos"]` (readGenesis sorts first, 'g' < 'p') - so `methodsUtxoRpc` in `Server.hs` must list the `readGenesis` handler FIRST, even though it is the last RPC added to the proto file.
  Always grep the regenerated module for `type ServiceMethods <Service>` and read off the literal list order after every proto change that adds/removes/renames a method; never assume it matches declaration order (existing precedent: the `methodsSyncRpc` haddock already documents this for `SyncService` - `dumpHistory, fetchBlock, followTip, readTip`, also alphabetical).

# proto-lens genesis / cardano-rpc field-mapping gotchas
- **Names hidden from the `U5c` (`Cardano.Rpc.Proto.Api.UtxoRpc.Query`) re-export are still reachable as bare qualified lenses - no `OverloadedLabels` needed.**
  `Cardano.Rpc.Proto.Api.UtxoRpc.Query` imports `...Cardano.Cardano_Fields hiding (hash, height, index, items, key, slot, timestamp, tx, values, ...)`, but every one of those names is ALSO defined (polymorphically, via `HasField`) in `...Query.Query_Fields`, which is NOT hidden.
  So `U5c.values`/`U5c.hash` resolve to the `Query_Fields` lens and work on ANY message that has a `values`/`hash` field (e.g. `CostModel`, `Constitution`) - proven by existing use in `Type/ProtocolParameters.hs` (`U5c.values`) and `Type/Certificate.hs` (`U5c.hash`).
  Do not reach for `#values`/`#hash` OverloadedLabels; the plain `U5c.name` form is correct and matches the rest of cardano-rpc.
- **`CostModelMap` (the `Genesis` message's `cost_models`) and `CostModels` (the `PParams` message's) are DISTINCT generated proto types with identical shape.**
  Both have `plutusV1..plutusV4 :: CostModel` and `CostModel` has `values :: [Int64]`, but a helper typed for one will not fit the other - build each with its own `defMessage`.
- **proto-lens `map<K,V>` fields are plain `Data.Map.Map K V` set directly with `.~` - there is no `Maybe` and no per-entry key/value message.**
  Build the whole map with `Map.fromList` and set it in one go (e.g. `U5c.genDelegs .~ Map.fromList [...]`); the generated `Genesis'FooEntry` types are internal and never constructed by hand.
- **Projecting per-era genesis out of a `TransitionConfig LatestKnownEra` (= Dijkstra) needs exact `tcPreviousEraConfigL` hop counts.**
  Shelley from any era: `^. tcShelleyGenesisL`. Conway: `^. tcPreviousEraConfigL . tcTranslationContextL` (one hop, Dijkstra to Conway). Alonzo: THREE `tcPreviousEraConfigL` hops (Dijkstra to Conway to Babbage to Alonzo) then `tcTranslationContextL`. All three from `Cardano.Ledger.Api.Transition`; they reduce at the concrete era with no type applications.
- **Byron `unLovelacePortion` and `lovelacePortionDenominator` are NOT exported** (only the abstract `LovelacePortion` type, `rationalToLovelacePortion` and `lovelacePortionToRational` are, from `Cardano.Chain.Common`).
  The Byron genesis JSON emits a `LovelacePortion` as its raw `Word64` numerator over a fixed 1e15 denominator, so recover it with `round (lovelacePortionToRational x * 1e15) :: Word64`.
- **Faithful Byron genesis rendering uses the ledger's own canonical-JSON formatters, which live in `Cardano.Crypto`/`Cardano.Chain.Common` and need a `formatting` build-dep** (`sformat`).
  Key hash -> hex: `sformat hashHexF . unKeyHash`; verification key -> base64: `fullVerificationKeyF`; signature -> base16: `fullSignatureHexF`; address -> base58: `addressF`; AVVM redeem key -> base64url: `redeemVKB64UrlF . fromCompactRedeemVerificationKey`.
  These match the on-disk genesis because they ARE what the ledger's `Text.JSON.Canonical` instances call; the aeson `ToJSON` instances on the same Byron types are "for debugging only" and must not be used as the reference.
- **`ppMinFeeAL`/`ppMinFeeBL` are deprecated** (`-Wdeprecations`, fatal under cardano-api's `-Werror`) in favour of `ppTxFeePerByteL`/`ppTxFeeFixedL`.
  Note the types differ: `ppTxFeePerByteL :: Lens' (PParams era) CoinPerByte` (and `CoinPerByte` wraps `CompactForm Coin`, so unwrap with `fromCompact . unCoinPerByte`), whereas `ppTxFeeFixedL :: Lens' (PParams era) Coin` (plain). Both are era-generic `EraPParams` methods, so they read a `PParams ShelleyEra` without needing `ConwayEraPParams`.
- **The `NominalDiffTimeMicro` (Shelley `sgSlotLength`) converter is `fromNominalDiffTimeMicro :: NominalDiffTimeMicro -> NominalDiffTime`, exported from `Cardano.Ledger.Shelley.Genesis`** (there is no `nominalDiffTimeMicroToSeconds`).
  For slot length in milliseconds: `round (1000 * fromNominalDiffTimeMicro sgSlotLength)` (mainnet's 1 s yields 1000).
- **RIO does not re-export `?~`** (its whole lens surface is `view`/`preview`/`^.`/`^?`/`^..`/`%~`/`.~` plus the types - checked `RIO.Prelude.Lens`), so hlint's "Use ?~" hint on `maybe'foo .~ Just x` setters cannot be satisfied from RIO alone.
  The fix is NOT an HLINT ignore: `microlens` is already in the build plan (RIO depends on it, and RIO's own operators are microlens re-exports, so it composes with the same proto-lens lenses).
  Add `microlens` to build-depends and `import Lens.Micro ((?~))`.

# optparse-applicative gotchas
- **Wrapping a required option group in a single `Opt.optional` DOES correctly enforce all-or-nothing on that group** - a partially-supplied group is a hard `Missing: --x` parse error, not a silent fallback to the "absent" case. This is easy to get wrong by reading the combinator source alone: `Parser`'s `Alternative` instance is `AltP p1 p2` with `evalParser (AltP p1 p2) = evalParser p1 <|> evalParser p2`, which superficially suggests a partially-matched branch (`evalParser p1 = Nothing`) just falls through to the other branch (`evalParser p2 = Just Nothing` for `optional`'s `pure Nothing` arm). That is NOT what happens: `searchParser` (`Options.Applicative.Common`), which matches an incoming command-line argument against the live parser tree, resolves `searchParser f (AltP p1 p2) = msum [searchParser f p1, searchParser f p2]` - and once an argument matches an option somewhere inside `p1`, the reconstructed replacement returned for that `AltP` node is the modified `p1` ALONE, not `AltP p1' p2`. The untaken alternative (including `optional`'s fallback) is discarded from the tree for the rest of parsing. So once any option in a group has matched once, the whole group's other options become mandatory for the remainder of the parse; if one is still missing when args run out, `exitP` reports `MissingError`.
  Verified empirically with a standalone `runghc` script (`Options.Applicative`, ambient nix-store package, version 0.19.0.0) reproducing cardano-node's unix-socket-vs-TCP-vs-TLS `RpcEndpoint` parser shape: giving `--grpc-listen-port` + `--grpc-tls-certificate` without `--grpc-tls-private-key` fails with `Missing: --grpc-tls-private-key KEY`, and giving only a chain-certificate flag without cert+key fails with both missing. Confirmed against the pinned `optparse-applicative-fork-0.18.1.0` source (haskdogs cache) too - `searchParser`/`evalParser` are unchanged in the relevant respect - so the conclusion holds for the actual pinned version, not just the ambient one used to run the quick check.
  Practical upshot: to require "these N flags together, or none", parse them as ONE combined sub-parser (`Ctor <$> flagA <*> flagB <*> ...`) and wrap THAT whole thing in a single `Opt.optional`, rather than wrapping each flag in its own separate `Opt.optional` and validating the combination after the fact (the `Parser` type has no `Monad`/`MonadFail` instance, so there is no way to fail mid-parse based on already-parsed values the way aeson's `Parser` can with `fail`).
