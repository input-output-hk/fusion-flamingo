# Project Instructions

<!-- Keep this file lean. Only add things that are NOT inferrable from reading
     the source code: surprising gotchas, easy-to-make mistakes, external facts,
     local workstation details, and behavioural rules for AI agents. Everything else
     (host configs, services, modules, flake inputs, etc.) lives in the code. -->

# Rules for AI agents
- When you discover a surprising gotcha, easy-to-make mistake, or non-obvious fact about this project, add it to this file (AGENTS.md) - NOT to private memory.
  This file is the shared knowledge base for the project.
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

# Tool preferences for code navigation
- **Semantic tools** for references and type info.
  For "find references", "who calls X", "find consumers/producers", or "show me the type of X" queries, prefer semantic tools over grep.
- **Serena** (any language): use `find_referencing_symbols` for reference lookups, `get_symbols_overview` and `find_symbol` for exploring types and signatures without reading whole files.
- **Grep**: reserve for text-level searches - comments, string literals, non-code patterns, or when semantic tools are unavailable.
- Language-specific rules in `.claude/rules/<lang>.md` may add additional navigation tooling (e.g. ctags) on top of the above.

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

# Dijkstra era gotchas
- `caseShelleyToBabbageOrConwayEraOnwards` crashes at runtime for Dijkstra (`error "TODO Dijkstra"`).
  Use `caseShelleyToBabbageOrConwayOrDijkstra` instead and pattern match on `ConwayEraOnwards` constructors in the right arm to get concrete-era instance resolution (the bare `ConwayEraOnwards era` carries no constraints).
- `conwayEraOnwardsConstraints` also crashes for Dijkstra - never use it.
  Its constraint bundle requires `TxCert ~ ConwayTxCert` which Dijkstra cannot satisfy.
- Dijkstra has `ConwayEraTxCert DijkstraEra` (so `mkDelegTxCert` works) but NOT `ShelleyEraTxCert`.
