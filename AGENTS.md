# Project Instructions

<!-- Keep this file lean. Only add things that are NOT inferrable from reading
     the source code: surprising gotchas, easy-to-make mistakes, external facts,
     local workstation details, and behavioural rules for AI agents. Everything else
     (host configs, services, modules, flake inputs, etc.) lives in the code. -->

# Rules for AI agents
- When you discover a surprising gotcha, easy-to-make mistake, or non-obvious fact about this project, add it to this file (AGENTS.md) - NOT to private memory.
  This file is the shared knowledge base for the project.
- Keep all git remotes using SSH (e.g. `git@github.com:org/repo.git`), never HTTPS.
  Never add HTTPS remotes as a workaround when SSH fails - ask the user to fix SSH access instead.
  Use `gh api` for read-only GitHub queries (PRs, comments, etc.) when SSH is unavailable.
- Do NOT push to any remote - always ask the user for confirmation first.
- NEVER assume the default branch is called `main`.
  Check via `git symbolic-ref refs/remotes/origin/HEAD` or `git remote show origin | grep 'HEAD branch'` before targeting it for PRs, rebases, or diffs.

# Directory structure
- This project directory contains git submodules.
- **Always run `cabal` from `/work`** (the metarepo root where `cabal.project` lives), NEVER from inside a submodule.
  The metarepo `cabal.project` orchestrates builds across all submodules.
- Always execute nix commands in each submodule's root directory.
- Never modify the nix store.
- Worktrees ALWAYS reside in each subproject's `@worktree`.
  Each worktree has a separate folder e.g. `cardano-api/@worktree/my-feature`.
- **Always create worktrees on a branch**, never detached HEAD.
  Use `git worktree add -b <branch> <path> <start-point>` to create a local branch tracking the remote.
  Never use `git worktree add <path> <remote-ref>` without `-b` - it creates a detached HEAD.

# Nix gotchas
- `nix build path:.` in a git worktree only sees **committed or staged** files (nix detects `.git` and filters via git).
  Always `git add` changed files before building; a full commit is not required.
- haskell.nix `modules` source overrides (`packages.foo.src = mkForce ...`) only apply at **build** time.
  The **plan computation** phase fetches SRP sources independently.
  Use `inputMap` in `cabalProject'` to provide fixed sources for both phases.
- `inputMap` key must be `"url/rev"` when the value is a plain store path (no `.rev` attribute).
  Bare `"url"` makes haskell.nix try to access `.rev` on the value.
- Module overrides for packages not in the build plan fail.
  Guard with `config.packages ? ${p}`.
- `nix develop` fails inside a git worktree of a submodule - nix tries to open `.git/modules/<submodule>/@worktree/<name>/` which doesn't exist.
  Run `nix develop` from the submodule's main checkout instead, then `cd` into the worktree.
- Minimise nix build round-trips: verify types, imports, and constraints carefully before building.
- Always include a `--sha256:` comment on `source-repository-package` stanzas - nix requires it for reproducible fetching.
- **cardano-node nix attribute paths** use slashes, not colons.
  Tests: `tests/cardano-testnet/cardano-testnet-test`, `checks/cardano-testnet-10.2.0-inplace-cardano-testnet-test/cardano-testnet-test`.
  Libraries: `cardano-testnet`, `cardano-node`, `cardano-cli`.
  Example: `nix build 'path:.#tests/cardano-testnet/cardano-testnet-test' --allow-import-from-derivation --accept-flake-config`.

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

# Output style
- **Never use em dashes** (U+2014) in any output - code, documents, markdown, or prose.
  Use hyphens (`-`), commas, colons, semicolons, or parentheses instead.
- **One sentence per line in markdown files.**
  Never put multiple sentences on the same line.
  This keeps diffs clean - a change to one sentence does not touch adjacent sentences.
- **Always use British English** in all output - code comments, documentation, markdown, prose.
  E.g. "behaviour" not "behavior", "standardise" not "standardize", "favour" not "favor", "serialisation" not "serialization".
- **Never wrap description text in changelog fragments.**
  Keep the entire description on a single line after `description: |` regardless of length.
  The YAML literal block scalar preserves line breaks, so wrapping introduces unwanted newlines.

# Tool preferences for code navigation
- **ctags first** for finding definitions.
  `/work/tags` is a hasktags index covering the project and its dependencies.
  Use `grep -m5 '^SymbolName\t' /work/tags` before anything else when looking up a symbol.
  This is instant, precise, and always the first thing to try.
- **Semantic tools** for references and type info.
  For "find references", "who calls X", "find consumers/producers", or "show me the type of X" queries, prefer semantic tools over grep.
- **Serena** (any language): use `find_referencing_symbols` for reference lookups, `get_symbols_overview` and `find_symbol` for exploring types and signatures without reading whole files.
- **HLS** (Haskell only): use for go-to-definition, type info, and diagnostics in Haskell projects.
  **After every edit to a `.hs` file**, check HLS diagnostics on the changed lines before reporting the edit as complete.
- **Grep**: reserve for text-level searches - comments, string literals, non-code patterns, or when semantic tools are unavailable.
