# Project Instructions

<!-- Keep this file lean. Only add things that are NOT inferrable from reading
     the source code: surprising gotchas, easy-to-make mistakes, external facts,
     local workstation details, and behavioral rules for AI agents. Everything else
     (host configs, services, modules, flake inputs, etc.) lives in the code. -->

# Rules for AI agents
- When you discover a surprising gotcha, easy-to-make mistake, or non-obvious fact about this project, add it to this file (AGENTS.md) — NOT to private memory. This file is the shared knowledge base for the project.
- Keep all git remotes using SSH (e.g. `git@github.com:org/repo.git`), never HTTPS.
- Do NOT push to any remote — always ask the user for confirmation first.
- NEVER assume the default branch is called `main`. Check the repo's actual default branch via `git symbolic-ref refs/remotes/origin/HEAD` or `git remote show origin | grep 'HEAD branch'` before targeting it for PRs, rebases, or diffs.

# Directory structure
- This project directory contains git submodules
- Always execute nix commands in each submodule's root directory
- Worktrees ALWAYS reside in each subproject's `@worktree`.
  Each worktree has a separate folder e.g. `cardano-api/@worktree/my-feature`
- After creating a git worktree inside a submodule, update its .git configuration to use relative paths.
  `git worktree add` writes absolute paths in submodules in two places that must both be fixed:
  1. `<worktree>/.git` — the `gitdir:` line pointing to the worktree metadata
  2. `.git/modules/<submodule>/worktrees/<name>/gitdir` — the back-pointer to the worktree

# Nix gotchas
- `nix build path:.` in a git worktree only sees **committed** files (nix detects `.git` and filters via git). Always commit before building.
- haskell.nix `modules` source overrides (`packages.foo.src = mkForce ...`) only apply at **build** time. The **plan computation** phase fetches SRP sources independently. Use `inputMap` in `cabalProject'` to provide fixed sources for both phases.
- `inputMap` key must be `"url/rev"` when the value is a plain store path (no `.rev` attribute). Bare `"url"` makes haskell.nix try to access `.rev` on the value.
- Module overrides for packages not in the build plan fail. Guard with `config.packages ? ${p}`.
- `nix develop` fails inside a git worktree of a submodule — nix tries to open `.git/modules/<submodule>/@worktree/<name>/` which doesn't exist. Run `nix develop` from the submodule's main checkout instead, then `cd` into the worktree.

# General rules
- Never manually edit generated code (e.g. proto-lens output in `gen/`). Use nix dev shell to run code generation tools (e.g. `nix develop --command bash -c "cd cardano-rpc && buf generate proto"`)
- Never modify the nix store
- Minimize nix build round-trips: verify types, imports, and constraints carefully before building.

# cardano-rpc patterns
- `Proto msg` is a grapesy newtype wrapper. Internal functions should use plain proto-lens types, not `Proto`-wrapped. Use `getProto`/`fmap getProto` only at the RPC handler boundary.
- RIO hides many Prelude functions. `sortBy` is NOT re-exported by RIO — import from `Data.List`. Check RIO re-exports before assuming standard functions are in scope.
- RIO's `^.` works with proto-lens van Laarhoven lenses. No need for `lens-family` dependency.
- Use `toList` (from `GHC.IsList`) instead of deprecated `valueToList` for `Value`.
- Prefer backtick-infix sections over lambdas (e.g. `` (`f` y) `` not `\x -> f x y`). hlint catches this.

# Code style
- Use readable value names, not acronyms: `shelleyBasedEra` not `sbe`, `policy` not `pid`, `network` not `nw`, `credential` not `cred`, `address` not `addr`, `value` not `val`, `tokenName` not `aname`, `quantity` not `qty`.
- Don't create trivial one-liner helpers that just wrap `defMessage & lens .~ value` — inline them at call sites.
- Use `OverloadedLists` and list literals instead of deprecated `valueFromList`.
- In Hedgehog tests, use `H.nothingFail` from hedgehog-extras instead of `case ... Nothing -> H.failure; Just x -> do`. Import convention: `import Hedgehog as H` + `import Hedgehog.Extras qualified as H`.
- Use `H.propertyOnce` (from hedgehog-extras) instead of `H.property` for tests with no generators (`forAll`) — i.e., unit tests with fixed data.
- **No staircase pattern.** Never nest `case ... of Just/Nothing` producing rightward drift. Use `MaybeT` + `Alternative` (`<|>`) to flatten sequential `IO (Maybe a)` fallbacks:
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
- **Always prefer `$` over `()`** for function application. Write `f $ g x` not `f (g x)`.
- **Prefer dots over multiple dollars** in function application chains. Write `f . g . h $ u v` not `f $ g $ h $ u v`.
- **Never modify `fourmolu.yaml`**, hlint rules, or cabal gild rules unless explicitly asked.
- **Never use `BlockArguments`** extension.
- **Never use `putStrLn`** in library code — use `Data.Text.IO.hPutStrLn stdout` for `Text` output (`say` is not available in RIO 0.1.24.0).
- **Never use em dashes** (U+2014 `—`) in any output -- code, documents, markdown, or prose. Use hyphens (`-`), double hyphens (`--`), commas, colons, semicolons, or parentheses instead.
- **One sentence per line in markdown files.** Never put multiple sentences on the same line. This keeps diffs clean -- a change to one sentence does not touch adjacent sentences.
- **Always use British English** in all output -- code comments, documentation, markdown, prose. E.g. "behaviour" not "behavior", "standardise" not "standardize", "favour" not "favor", "serialisation" not "serialization".

# Tool preferences for code navigation
- **Semantic tools first, grep last.**
  For "find references", "who calls X", "find consumers/producers", or "show me the type of X" queries, prefer semantic tools over grep.
- **Serena** (any language): use `find_referencing_symbols` for reference lookups, `get_symbols_overview` and `find_symbol` for exploring types and signatures without reading whole files.
- **HLS** (Haskell only): use for go-to-definition, type info, and diagnostics in Haskell projects.
- **Grep**: reserve for text-level searches -- comments, string literals, non-code patterns, or when semantic tools are unavailable.

# Mistakes and wrong assumptions (lessons learned)
- Assumed generated code could be patched by hand — WRONG. Always use the project's code generation pipeline.
- Assumed proto-lens types would be used wrapped in `Proto` everywhere — WRONG. `Proto` is only at the gRPC handler boundary. Internal logic uses raw proto-lens types.
- Assumed RIO re-exports all of `Data.List` — WRONG. `sortBy`, `on`, and others need explicit imports.
- Assumed I needed `lens-family` for proto-lens field access — WRONG. RIO's `^.` (from `microlens`) is compatible with proto-lens van Laarhoven lenses.
- Used deprecated `valueToList` instead of checking for the current API (`toList` via `GHC.IsList`).
- Left redundant `IsEra` constraint on `matchesTxOutputPattern` — should check if constraints are actually needed before adding them.
- Forgot `--sha256:` comment on a `source-repository-package` stanza — nix requires it for reproducible fetching. Always include `--sha256:` when adding SRPs.
- Saved a project-wide rule to private memory instead of AGENTS.md -- WRONG. Line 9 of this file says to add discoveries here, not to private memory. Always check AGENTS.md instructions before choosing where to persist new rules.

