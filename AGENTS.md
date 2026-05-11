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
- **cardano-node nix attribute paths** live under `hydraJobs`, not top-level packages.
  Use `nix build 'path:.#hydraJobs.native.<target>'` for native builds.
  Top-level categories: `native`, `musl`, `windows`, `cardano-deployment`, `required`, `nonrequired`.
  Attribute paths within categories use slashes, not colons.
  Tests: `hydraJobs.native.tests/cardano-testnet/cardano-testnet-test`, `hydraJobs.native.checks/cardano-testnet-11.0.0-inplace-cardano-testnet-test/cardano-testnet-test`.
  Libraries: `hydraJobs.native.cardano-testnet`, `hydraJobs.native.cardano-node`, `hydraJobs.native.cardano-cli`.
  Other targets: `hydraJobs.native.gen-plutus`, `hydraJobs.native.calibrate-script`, `hydraJobs.native.tx-generator`.
  Example: `nix build 'path:.#hydraJobs.native.gen-plutus' --allow-import-from-derivation --accept-flake-config`.

# Output style
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
