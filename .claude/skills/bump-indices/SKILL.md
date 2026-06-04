---
name: bump-indices
description: Bump hackage and/or CHaP index-state in cabal.project (and flake.lock for subprojects).
argument-hint: "[hackage|chap|both] [cardano-api|cardano-cli|cardano-node|all]"
---

Bump package index timestamps in `cabal.project` files and corresponding nix flake inputs.

Arguments: $ARGUMENTS

## Layout

The **metarepo** is `/work` - it has a `cabal.project` that orchestrates builds across all subprojects.
The **subprojects** each have their own `cabal.project` and `flake.nix` with `flake.lock`:

| Subproject   | Path               |
|--------------|--------------------|
| cardano-api  | `/work/cardano-api`  |
| cardano-cli  | `/work/cardano-cli`  |
| cardano-node | `/work/cardano-node` |

Each subproject's `flake.nix` has two relevant inputs: `CHaP` and `hackageNix`.

## Procedure

### 1. Parse arguments and ask if needed

If the user didn't specify which indices or which repos, ask them:
- **Which indices?** hackage, chap, or both
- **Which repos?** cardano-api, cardano-cli, cardano-node, metarepo, or all

### 2. Fetch latest timestamps

Run `cabal update` from `/work` (the metarepo) and parse the output:
```bash
cd /work && cabal update 2>&1
```

This prints lines like:
```
The index-state is set to 2026-05-21T02:42:03Z.   # for hackage.haskell.org
The index-state is set to 2026-05-20T06:15:42Z.   # for cardano-haskell-packages
```

Use these as the new timestamps. NEVER use GitHub API commit dates or any other source - only `cabal update` output gives the actual available index-state values. A timestamp from `gh api` may be newer than what the CHaP mirror has published, causing CI to fail with "index-state is older than requested".

### 3. Update cabal.project index-state

For each selected target, edit the `index-state:` block in its `cabal.project`:

```
index-state:
  , hackage.haskell.org YYYY-MM-DDTHH:MM:SSZ
  , cardano-haskell-packages YYYY-MM-DDTHH:MM:SSZ
```

Only update the lines for the selected indices (hackage, chap, or both).

Targets and their `cabal.project` paths:
- metarepo: `/work/cabal.project`
- cardano-api: `/work/cardano-api/cabal.project`
- cardano-cli: `/work/cardano-cli/cabal.project`
- cardano-node: `/work/cardano-node/cabal.project`

### 4. Update flake.lock (subprojects only)

For each **subproject** (cardano-api, cardano-cli, cardano-node), also bump the corresponding nix flake inputs. The metarepo does NOT have its own flake.lock to bump.

**CHaP:**
```bash
nix flake update CHaP --flake 'path:/work/<subproject>'
```

**Hackage:**
```bash
nix flake update hackageNix --flake 'path:/work/<subproject>'
```

Use `--flake 'path:<dir>'` (not bare `.`) to avoid git submodule resolution issues.
Use 120s timeout for `nix flake update` commands.

### 5. Report

Show what was bumped:
- Old and new index-state values for each target
- Old and new flake.lock revisions for subprojects

## Important rules
- **Only bump what the user asked for.** "metarepo" means `/work/cabal.project` only - do NOT touch subprojects. "cardano-api" means only cardano-api. "all" means everything.
- Always use `path:<dir>` for nix flake commands.
- Flake input names are `CHaP` (capital C-H-A-P) and `hackageNix` (camelCase). Getting the case wrong silently creates a new input.
- The metarepo (`/work`) has no flake.lock to bump - only its `cabal.project`.
- All three subprojects (cardano-api, cardano-cli, cardano-node) have both `cabal.project` AND `flake.lock` to bump.
