---
name: nix-build
description: Discover and run nix build targets for cardano-node, cardano-api, and cardano-cli submodules.
---

Build a nix target in one of the project's submodules.
The user provides a target description (e.g. "cardano-api library", "cardano-testnet tests", "cardano-cli exe").

## Nix attribute conventions

Each submodule has a different flake with different attribute naming:

### cardano-api (run from `/work/cardano-api` or its worktree)
Attributes use **colons** as separators: `package:component-type:component-name`.
Examples:
- `cardano-api:lib:cardano-api`
- `cardano-api:lib:gen`
- `cardano-api:test:cardano-api-golden`
- `cardano-api:test:cardano-api-test`
- `cardano-rpc:lib:cardano-rpc`
- `cardano-rpc:test:cardano-rpc-test`
- `cardano-api-gen:lib:cardano-api-gen`
- `cardano-wasm:exe:cardano-wasm`

### cardano-cli (run from `/work/cardano-cli` or its worktree)
Attributes use **colons** as separators.
Examples:
- `cardano-cli:lib:cardano-cli`
- `cardano-cli:lib:cardano-cli-test-lib`
- `cardano-cli:exe:cardano-cli`
- `cardano-cli:test:cardano-cli-golden`
- `cardano-cli:test:cardano-cli-test`

### cardano-node (run from `/work/cardano-node` or its worktree)
Attributes use **slashes** as separators.
Examples:
- `cardano-testnet` (library)
- `cardano-node` (executable)
- `cardano-cli` (executable, the one bundled in cardano-node)
- `tests/cardano-testnet/cardano-testnet-test`
- `tests/cardano-testnet/cardano-testnet-golden`
- `tests/cardano-node/cardano-node-test`
- `checks/cardano-testnet-10.2.0-inplace-cardano-testnet-test/cardano-testnet-test`

## Procedure

1. Determine which submodule the user wants to build in.
   If working in a worktree (path contains `@worktree`), run from the worktree directory.
   Otherwise run from the submodule root (e.g. `/work/cardano-api`).

2. Pick the correct nix attribute from the lists above based on what the user wants to build.
   If unsure, discover attributes by running:
   ```
   nix eval 'path:.#packages.x86_64-linux' --apply 'builtins.attrNames' --allow-import-from-derivation --accept-flake-config
   ```

3. **Stage changed files first** -- nix in a git repo only sees committed or staged files:
   ```
   git add <changed-files>
   ```

4. Run the build:
   ```
   nix build 'path:.#<attribute>' --allow-import-from-derivation --accept-flake-config
   ```

5. Report errors or success to the user.

## Important rules
- Always use `path:.` (not bare `.`) to bypass git submodule resolution issues.
- Always pass `--allow-import-from-derivation --accept-flake-config`.
- Always `git add` changed files before building -- nix only sees staged or committed files.
- Use a 10-minute timeout (600000ms) for builds.
- `nix develop` does NOT work inside git worktrees -- only `nix build` does.
