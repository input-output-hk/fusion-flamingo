---
paths:
  - "**/flake.nix"
  - "**/flake.lock"
  - "**/*.nix"
  - "cabal.project"
---

# cardano-node nix attribute paths
- Attribute paths live under `hydraJobs`, not top-level packages.
  Use `nix build 'path:.#hydraJobs.native.<target>'` for native builds.
  Top-level categories: `native`, `musl`, `windows`, `cardano-deployment`, `required`, `nonrequired`.
  Attribute paths within categories use slashes, not colons.
  Tests: `hydraJobs.native.tests/cardano-testnet/cardano-testnet-test`, `hydraJobs.native.checks/cardano-testnet-11.0.0-inplace-cardano-testnet-test/cardano-testnet-test`.
  Libraries: `hydraJobs.native.cardano-testnet`, `hydraJobs.native.cardano-node`, `hydraJobs.native.cardano-cli`.
  Other targets: `hydraJobs.native.gen-plutus`, `hydraJobs.native.calibrate-script`, `hydraJobs.native.tx-generator`.
  Example: `nix build 'path:.#hydraJobs.native.gen-plutus' --allow-import-from-derivation --accept-flake-config`.

# haskell.nix gotchas
- Test fixtures inside a test suite's `hs-source-dirs` are included in nix `checks` automatically:
  haskell.nix's component source filter (`lib/clean-cabal-component.nix`) keeps entire `hs-source-dirs` trees, and the check (`lib/check.nix`) runs with CWD at the package root, so package-root-relative fixture paths resolve.
  `extra-source-files` is therefore only needed for files OUTSIDE `hs-source-dirs`, and it also controls sdist contents - never list test-only fixtures there, or they ship with the Hackage/CHaP release.

# Nix flake gotchas
- **`nix develop`/`nix build` invoked from inside a subproject that has ever had a local worktree created with a recent git (2.48+) can fail with `error: opening Git repository "..." : unsupported extension name extensions.relativeworktrees`.**
  Creating a worktree causes git to set `extensions.relativeworktrees=true` in the repo's `.git/config` (a repo-format marker, harmless to the current git binary); nix's internal git fetcher (used whenever a flake is evaluated from inside a git working tree via the implicit `git+file://` reference) is stricter and refuses to touch a repo advertising an extension it does not recognise, even though it never inspects the worktree links themselves.
  Workaround (no git config changes - `git config` edits are off-limits): pass an explicit `path:` flake reference instead of the bare directory, e.g. `nix develop "path:/work/cardano-api" --command ...` - this makes nix read the working directory directly instead of going through the git+file fetcher, and does not disturb the git-tracked/untracked file filtering that flakes normally rely on for anything actually needed here (proto regeneration, builds).
  Note that `path:` refs copy the working directory as-is, so uncommitted AND unstaged edits are visible to the build - no `git add` needed.
- **The `path:` workaround above is only safe run from INSIDE the affected subproject's own root - never apply it to the metarepo root `/work`.**
  `path:.` makes nix copy the ENTIRE flake source directory into the store to evaluate it; at `/work` that means the whole tree, including every subproject (`cardano-node`, `cardano-api`, ...) and anything else checked out alongside them (e.g. `leios-public-testnet`).
  That copy chokes on any file nix can't represent (sockets, FIFOs, device files) anywhere in that tree - observed hitting a chain of stray test-debris sockets in `cardano-node/cardano-tracer/cardano-tracer-test/` (`tracer.1.sock`, `tracer.2.sock`, `tracer.sock`) and then a live cardano-node IPC socket at `leios-public-testnet/node.socket` (do NOT delete that one - it belongs to a running node, not test debris).
  Even after clearing every such file it is still a dead end: it would copy multi-gigabyte `dist-newstyle` build directories into the store on every single `nix flake update` invocation.
  Fix instead by routing around the git fetcher for just the affected input: clone the subproject into a scratch directory (`git clone /work/cardano-api /tmp/.../cardano-api-clean` - a fresh clone has no `extensions.relativeworktrees` flag), then `nix flake update --override-input cardano-api "git+file:///tmp/.../cardano-api-clean"`.
  The resulting `flake.lock` entry's `locked.url` will point at the scratch clone path - hand-edit just that one field back to the original `"file:./cardano-api"` (keep the freshly computed `rev`/`narHash`/`lastModified`/`revCount`).
  Verify with a plain `nix flake lock` afterward: it must be a true no-op (exit 0, zero diff) - if it tries to re-lock the input, the URL fixup was wrong.
- **`error: '/work/./<subproject>' is a shallow Git repository` from nix's git fetcher means the subproject clone went shallow** (a `.git/shallow` file exists, e.g. after a depth-limited fetch); nix refuses shallow repos for flake inputs unless the input declares `shallow = true`.
  Fix with `git -C /work/<subproject> fetch --unshallow` - never add `shallow = true` to the flake input (it breaks `revCount`).
  Mind that after unshallowing, the relativeworktrees error above may surface next - it was masked by the shallow error.
- **A `git+file:./<subproject>` flake.lock pin can go ZOMBIE: the pinned rev exists only as an unreachable object in the local clone** (observed 2026-09-10: flake.lock pinned cardano-api ref `mgalazyn/fix/experimental-redeemer-pointer-indexing` rev e769c70, but the PR had been squash-merged and the branch deleted everywhere - no local or remote ref contained the rev).
  Materialising such a pin needs the scratch-clone workaround above PLUS recreating the locked ref in the scratch clone (`git branch <ref-name> <rev>`; a local `git clone /work/<subproject>` copies even unreachable objects via the objects-dir hardlink path, so the rev is present).
  This state is fragile - a `git gc` in the subproject can delete the object and make the pin unfetchable everywhere - so re-pin the input to a live ref when convenient.
- **Entering cardano-api's nix devshell from a WORKTREE writes a `pre-commit` hook into the MAIN checkout's shared `.git/hooks`** (the shellHook's pre-commit-hooks.nix install step resolves the common git dir, observed 2026-09-09: `pre-commit installed at /work/cardano-api/.git/hooks/pre-commit` while running `nix develop "path:/work/cardano-api/@worktree/..."`).
  Harmless but surprising: the hook then fires for commits made in the MAIN checkout too, not just the worktree; it is untracked and safe to leave, just don't attribute it to your own changes when auditing `git status`/hooks.
- **`nix flake show` fails outright on cardano-api's flake** - it evaluates all systems' outputs including aarch64-darwin ones that cannot be evaluated on x86_64-linux.
  Discover build attrs with `nix eval "path:<repo>#packages.x86_64-linux" --apply builtins.attrNames` (and the analogous `checks.x86_64-linux`, whose attrs actually RUN test suites; the `packages` test attrs only build the executable).
- **`source-repository-package` stanzas must use `https://github.com/...` locations, never `git@github.com:` SSH URLs.**
  Hydra/CI nix sandboxes have no SSH credentials, so haskell.nix's plan-to-nix step fails at source fetch time with an opaque "Build failed due to failed dependency" on `plan.json`, red across every platform job (observed 2026-08-13 on cardano-node PR #6602, Hydra eval 119839).
  Local nix builds do not catch this - the local sandbox can fetch over SSH.
  Match the commented-out reference stanzas in each repo's cabal.project, which all use https.

- **In cardano-api's flake, `iohkNix.utils.ciJobsAggregates` does NOT forward a `devShells` key** (its output is only `required`/`nonrequired`), and the base `cabalProject.flake` output already carries `hydraJobs.devShells.default`.
  When composing `hydraJobs` with a single merge instead of chained `recursiveUpdate`s, preserve that entry explicitly (`(flake.hydraJobs.devShells or {}) // extraShells`) both inside the `ciJobs` argument and on the final `hydraJobs` attrset - a naive `//` silently drops `devShells.default` from Hydra (caught 2026-09-11 by before/after `nix eval` attr-list comparison; always verify flake refactors that way).

- **Bumping a subproject's CHaP index-state without `cabal update`: update the flake input (`nix flake update CHaP --flake 'path:.'` in a worktree), then set `cardano-haskell-packages` to the NEWEST ENTRY inside that locked index, not to the input's `lastModified`** - the `repo` branch commit is made after the last entry, so cabal rejects the commit time with `Cabal-7159: Latest known index-state ... is older than the requested index-state` (observed 2026-09-25: lock time 01:05:00Z vs index ceiling 00:08:56Z); the error message prints the correct value to use, and a `nix build --dry-run` surfaces it in minutes.
  The `repo` branch is regenerated on every publish and shares no git ancestor with `main`, so check "is package X in the index" by downloading `01-index.tar` at the locked rev and looking for `<pkg>/<version>/`, not by comparing dates with a `main` commit.
