# Project Instructions

<!-- Keep this file lean. Only add things that are NOT inferrable from reading
     the source code: surprising gotchas, easy-to-make mistakes, external facts,
     local workstation details, and behavioral rules for AI agents. Everything else
     (host configs, services, modules, flake inputs, etc.) lives in the code. -->

# Rules for AI agents
- When you discover a surprising gotcha, easy-to-make mistake, or non-obvious fact about this project, add it to this file (AGENTS.md) — NOT to private memory. This file is the shared knowledge base for the project.
- Keep all git remotes using SSH (e.g. `git@github.com:org/repo.git`), never HTTPS.
- Do NOT push to any remote — always ask the user for confirmation first.

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

# Mistakes and wrong assumptions (lessons learned)
- Assumed generated code could be patched by hand — WRONG. Always use the project's code generation pipeline.
- Assumed proto-lens types would be used wrapped in `Proto` everywhere — WRONG. `Proto` is only at the gRPC handler boundary. Internal logic uses raw proto-lens types.
- Assumed RIO re-exports all of `Data.List` — WRONG. `sortBy`, `on`, and others need explicit imports.
- Assumed I needed `lens-family` for proto-lens field access — WRONG. RIO's `^.` (from `microlens`) is compatible with proto-lens van Laarhoven lenses.
- Used deprecated `valueToList` instead of checking for the current API (`toList` via `GHC.IsList`).
- Left redundant `IsEra` constraint on `matchesTxOutputPattern` — should check if constraints are actually needed before adding them.

