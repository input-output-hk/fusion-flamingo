# Project Instructions

<!-- Keep this file lean. Only add things that are NOT inferrable from reading
     the source code: surprising gotchas, easy-to-make mistakes, external facts,
     local workstation details, and behavioural rules for AI agents. Everything else
     (host configs, services, modules, flake inputs, etc.) lives in the code. -->

# Rules for AI agents
- When you discover a surprising gotcha, easy-to-make mistake, or non-obvious fact, record it in the right place:
  project-specific operational facts go in this file (AGENTS.md); language-scoped facts go in `.claude/rules/haskell.md` or `.claude/rules/nix.md`;
  on-demand domain knowledge (what a system is, its design, formats and conventions, needed only when working on that topic) goes in `.claude/knowledge/<topic>/`, linked from the "Knowledge index" section with a plain link, never an `@` import (which would load it every session);
  knowledge not specific to this project goes to private memory instead.
  Never record easily-discoverable facts (anything a quick look at docs, `--help`, or the source re-answers).
- **Never run builds (`cabal build`, `nix build`) in subprojects without explicit user permission.**
  The metarepo orchestrates builds; subproject builds can interfere. Always ask first.
  "Explicit permission" means the user names the subproject build as such ("build it inside cardano-node", "run cabal in the subproject") - a general request like "run the verification build" or "build it without nix" is NOT permission and means a `/work` metarepo build (observed 2026-08-25: an agent inferred permission from "do the verification build, don't use nix" and ran `cabal build all` inside `/work/cardano-node`, creating a stray `dist-newstyle/` there; the user's rule stands even when only a subproject build would exercise CHaP pins - leave that verification to the PR's CI).
  This applies equally to subagent briefs: never instruct a subagent to build inside a subproject.
  Trap observed: "run the tests from the package root" (needed because test fixtures resolve relative to the package root) does NOT mean `cd <subproject> && cabal test` - that solves against the subproject's own `cabal.project` and builds the world into `<subproject>/dist-newstyle`.
  Run `cabal test` from `/work` (cabal sets the test binary's CWD to the package root itself), or run the already-built test binary directly with CWD at the package root.
  `cardano-node/dist-newstyle` and `cardano-api/dist-newstyle` are `/dev/null` symlinks precisely to sabotage this mistake.
- **The Bash tool's persistent cwd can drift away from `/work` mid-session** (observed: a `cabal build` from `/work` was followed moments later, with no intervening `cd`, by a `cabal test` that had silently landed in `/work/cardano-api` and solved against the subproject's own `cabal.project` instead of the metarepo's).
  Root cause unconfirmed (possibly a shared shell backend with concurrent agents), but the fix is cheap: prefix every metarepo build/test command with `cd /work &&` rather than relying on cwd persistence, and sanity-check with `pwd` plus the printed dist-newstyle paths in the build log (`/work/dist-newstyle/...` vs `/work/<subproject>/dist-newstyle/...`) whenever the command's target set matters.
- **Never double-background long builds: `run_in_background` PLUS your own `&`/`disown` inside the command orphans the real process** - the tool reports completion while the build keeps running detached, and a Monitor until-loop cannot observe a process it is not the parent of (observed twice, 2026-09-11 and 2026-09-15, both times a Haskell scratch build "finished" invisibly and the agent idled forever).
  Use `run_in_background: true` with the command in the FOREGROUND of that background shell, and verify completion by artefact (the built binary exists, log tail) rather than by process absence.

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
  as of 2026-08-13, both cardano-node and cardano-api are standalone clones with gitdir `/work/<subproject>/.git`, but other subprojects may be submodules with gitdir `/work/.git/modules/<subproject>` (verify per subproject - the layout has changed before).
  Derive the relative paths from the real gitdir; never assume the submodule layout.
  Submodule case:
  `<subproject>/@worktree/<name>/.git` -> `gitdir: ../../../.git/modules/<subproject>/worktrees/<name>` (three `../`),
  `/work/.git/modules/<subproject>/worktrees/<name>/gitdir` -> `../../../../../<subproject>/@worktree/<name>/.git` (five `../`).
  Standalone case:
  `<subproject>/@worktree/<name>/.git` -> `gitdir: ../../.git/worktrees/<name>` (two `../`),
  `/work/<subproject>/.git/worktrees/<name>/gitdir` -> `../../../@worktree/<name>/.git` (three `../`).
  Verify with `git -C /work/<subproject> worktree list` - it must show the real worktree path, not a phantom one.
- **Never repoint `/work/cabal.project` package paths at a worktree to build it.**
  `cabal.project` stays as the user set it; verify worktree changes with nix builds run inside the worktree root instead (the worktree has its own flake).
- **Nix builds inside a worktree need `path:.` instead of `.`** (observed 2026-10-08 in `cardano-api/@worktree/<name>`: the main checkout's `.git/config` sets `extensions.relativeWorktrees`, which nix's git fetcher rejects with "unsupported extension name extensions.relativeworktrees").
  `path:.` snapshots the whole working tree, uncommitted and untracked files included, so commit first and keep the tree clean.
  `nix flake show` also fails there while evaluating `aarch64-darwin` outputs; list attributes with `nix eval --accept-flake-config --allow-import-from-derivation 'path:.#packages.x86_64-linux' --apply builtins.attrNames --json` instead.
  Working targets for cardano-api: `packages.x86_64-linux."cardano-api:lib:cardano-api"`, `"cardano-api:lib:gen"`, `"cardano-api:test:cardano-api-test"`, `"cardano-api:test:cardano-api-golden"`, and `checks.x86_64-linux."cardano-api:test:<suite>"` to run a suite; pass `--accept-flake-config --allow-import-from-derivation`.
- **`nix flake update|metadata` fails in `/work/cardano-node` and its worktrees with "unsupported extension name extensions.relativeworktrees"** (the checkout's `.git/config` sets `extensions.relativeWorktrees`, which nix's libgit2 does not know; observed 2026-10-06, cardano-cli verified unaffected).
  Work around it with the path form, e.g. `nix flake update cardano-dev --accept-flake-config --flake 'path:/work/cardano-node/@worktree/<name>'`, which skips libgit2 for the top-level flake.
- **Commits, rebases and amends in `/work/cardano-cli` fail with "empty ident name"**: its `.git/config` sets only `user.email`, and there is no global `user.name` (only `/work/.git/config` has one; observed 2026-10-14).
  Pass the name per command (`GIT_COMMITTER_NAME="Mateusz Galazyn"`, plus `GIT_AUTHOR_NAME` for new commits); never edit git config.

# Tool preferences for code navigation
- **`grep` is aliased to `ugrep --ignore-files`, and `/work/.gitignore` ignores subproject directories (e.g. `cardano-api`)** - a recursive search run from `/work` silently returns NOTHING for files under those subprojects, even though they exist.
  Run searches from inside the subproject, or use `command grep`, or the Grep tool; never conclude "no consumers/references" from a `/work`-rooted grep.
- **Semantic tools** for references and type info.
  For "find references", "who calls X", "find consumers/producers", or "show me the type of X" queries, prefer semantic tools over grep.
- **Serena** (any language): use `find_referencing_symbols` for reference lookups, `get_symbols_overview` and `find_symbol` for exploring types and signatures without reading whole files.
- **Grep**: reserve for text-level searches - comments, string literals, non-code patterns, or when semantic tools are unavailable.
- Language-specific rules in `.claude/rules/<lang>.md` may add additional navigation tooling (e.g. ctags) on top of the above.
- **Serena diagnostics go stale after out-of-band edits.**
  Serena's language server opens files once and never sees changes made on disk by other tools (Edit/Write), so `get_diagnostics_for_file` keeps reporting the old snapshot - `touch`, symbol lookups and project re-activation do NOT refresh it.
  Edit Haskell files through Serena's own tools (`replace_in_files`, `replace_symbol_body`) so the server gets change notifications.
- **Activate Serena on `/work`, never on a subproject** - activating `/work/cardano-cli` writes an untracked `.serena/` into that checkout (observed 2026-10-14).

- **agentix `get_file` reconstructions can silently drop chunks, including the module header/export list** (observed 2026-09-07 on chap::cardano-ledger-conway-1.23.0.0's `Cardano/Ledger/Conway/UTxO.hs`: the reconstructed file started mid-module, no `module ... (...) where`).
  Never answer "is X exported" from an agentix-reconstructed file; use the haskdogs cache or the release tarball as ground truth.

# GitHub gotchas
- `gh pr edit` fails against IntersectMBO repos with a `projectCards` GraphQL deprecation error (classic projects sunset).
  Update PRs via REST instead: `gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -f title=... -F body=@file`.
- `gh pr view --comments` also fails against IntersectMBO repos with the same `projectCards` GraphQL deprecation error.
  Read reviews/comments via REST instead: `gh api repos/<owner>/<repo>/pulls/<n>/reviews` (and `/comments`, `/issues/<n>/comments`).
- **The Hydra->GitHub bridge posts an individual per-job check-run ONLY when that job FAILS**; passing jobs are silent under the aggregate `ci/hydra-build:*.required` checks.
  So "the failing check is absent on master" does not mean the job was skipped there - green aggregate + no per-job check-run means it passed.
  Check-runs are pinned per commit SHA to a specific Hydra build attempt: a red required check on a tag stays red forever until someone RESTARTS those Hydra builds for that exact SHA (master later going green never propagates back).
  Hydra per-job history and raw logs are at `https://ci.iog.io` (`/build/<id>`, raw log at `/build/<id>/nixlog/1/raw`), reachable from the sandbox.
- **Identical git trees can produce different Hydra derivation hashes across evaluations** (floating non-git input, likely IFD cabal-plan resolution), so "same source, different build outcome" needs no code change to explain - mind this before hunting for a fixing commit.
- **cardano-cli release tags are signed annotated tags since the herald-release bump `978aa19e` (2026-10-06), and the Hydra bridge's tag jobset then evaluates the tag object SHA, so no `ci/hydra-build` check-runs reach the release commit.**
  `release-upload.yml` polls `commits/<tag>/check-runs` (resolved to the commit), finds nothing, and waits until its 120-minute timeout (observed 2026-10-07 on cardano-cli-11.3.0.0; the lightweight 11.2.x tags were unaffected).
  Workaround: push any branch at the peeled commit (e.g. `ci/<tag>` at `<tag>^{}`); the bridge's branch jobset then posts the check-runs to the commit.
  Separately, the gate can pass while a `.required` check is still queued (null conclusions vanish in `$(...)`), so a green Release Upload does not prove that every `.required` check passed.
- **`cardano-cli --version` reports the git rev of the FLAKE it was built from, so binaries from the usual SPO route (`nix profile install github:IntersectMBO/cardano-node/...`) print cardano-node commits that do not exist in the cardano-cli repo** (observed 2026-09-25 on IntersectMBO/cardano-cli#1442: "cardano-cli 11.1.0.0, git rev 3cc6340a" was cardano-node@3cc6340a).
  Rebuild a reporter's exact binary with `nix build --accept-flake-config github:IntersectMBO/cardano-node/<rev>#hydraJobs.native.cardano-cli` from the scratchpad (Hydra-cached, seconds); and mind that cardano-cli tags without a GitHub Release (11.1.0.0, 11.2.0.0) have no downloadable assets, `gh release download` 404s on them.
- **To test a cardano-cli commit without building inside the subproject, `nix build --accept-flake-config github:IntersectMBO/cardano-cli/<sha>#cardano-cli` from the scratchpad is Hydra-cached for master commits (seconds, verified 2026-10-02 for both a 2025-05 and a 2025-09 commit)**; the resulting binary prints `git rev 0000000000000000000000000000000000000000`, so record the SHA you built yourself rather than reading it from `--version`.
  Keep the `--out-link` under the scratchpad and never point it into `/work`.
- **cardano-node pins cardano-dev actions by commit SHA with a `# <tag>` comment; take the SHA from the `^{}` line of `git ls-remote <repo> "refs/tags/<tag>" "refs/tags/<tag>^{}"`.**
  The plain line is the annotated tag object, and `uses: owner/repo@<tag-object-sha>` fails to resolve (caught 2026-10-06 before commit: an agent had pasted the tag-object SHAs for herald-release-0.0.3.1 and herald-validate-0.0.1.1).
- **An ad-hoc URL fetch into `refs/remotes/origin/*` deletes the other origin tracking refs when `fetch.prune=true` is set globally** (observed 2026-10-07 in cardano-api: `git fetch https://github.com/... '+master:refs/remotes/origin/master' ...` pruned `origin/<branch>` refs not named in the refspecs, which breaks a later `git push --force-with-lease` that relies on them).
  Run such fetches with `git -c fetch.prune=false fetch https://... <refspecs>`, and confirm the tracking refs with `git rev-parse origin/<branch>` afterwards.

# GitHub Actions
- Use `cachix/install-nix-action@v30` with IOG trusted keys and substituters.
  Pattern: `nix run github:input-output-hk/cardano-dev#<app> -- <args>`.
  Reference: cardano-api's `check-cabal-files.yml`.

# Knowledge index
- **cardano-rpc** (gRPC server, UTxO RPC, N2C IPC, node kernel access, ADR-018, ADR-019, roadmap, FieldMask, WatchMempool, node-kernel-access branch): [.claude/knowledge/cardano-rpc/README.md](.claude/knowledge/cardano-rpc/README.md)
- **cardano-config** (IntersectMBO/cardano-config, config format v1/v2 envelope, GenesisHash keys, migrate, POM parser, stale local checkout, 2021 cardano-config naming trap): [.claude/knowledge/cardano-config/README.md](.claude/knowledge/cardano-config/README.md)
- **herald** (changelog fragments, release automation, herald-validate / herald-release actions, herald-ref, .herald.yml kinds, `--diff` fork point, cardano-dev flake): [.claude/knowledge/herald/README.md](.claude/knowledge/herald/README.md)
- **utxorpc-spec** (utxorpc/spec fork, gen/haskell, proto-lens-protoc, buf generate, Proto modules, codegen artifact, publish-* actions): [.claude/knowledge/utxorpc-spec/README.md](.claude/knowledge/utxorpc-spec/README.md)
- **Dijkstra era** (ledger: sub-transactions / nested transactions / CIP-118, guards / RequireGuard / CIP-112, direct deposits and account balance intervals / CIP-159, PlutusV4, pool BLS key, Dijkstra protocol parameters; consensus: Leios / endorser blocks / CIP-164, Peras / CIP-140): [.claude/knowledge/dijkstra/README.md](.claude/knowledge/dijkstra/README.md)

# Project context

## cardano-rpc
- **The quickstart CI workflow `rpc-quickstart-examples.yml` waits for cardano-testnet's `<output-dir>/manifest.json` as the ready signal** (written last, once the cluster is ready; cardano-node master since 2026-09-24, PR IntersectMBO/cardano-node#6693, in no cardano-node release tag as of 2026-09-25).

## herald
- **`herald validate --diff` fails with "Could not determine fork point - is this branch tracking a remote?" inside a git worktree** (gitdir file), even with `refs/remotes/origin/HEAD` set and upstream tracking configured; the same binary works in the main clone (observed 2026-09-25 in cardano-api/@worktree). The error message is misleading, so do not add upstream tracking to fix it - validate fragments by passing their paths explicitly (`herald -c .herald.yml validate .changes/<file>.yml`) and leave the `--diff --pr` check to CI.
- **`herald validate` rejects `pr: 0`** (the placeholder `herald init` scaffolds), so a fragment written before its PR exists needs a predicted positive number.
  Issues and PRs share one number space: use the number after the latest issue or PR, and correct it once the PR is opened (observed 2026-10-06 on cardano-dev#48: an agent put the issue's own number in `pr:`).

## Metarepo dependency solve
- **`/work/cabal.project` builds cardano-node, cardano-api and cardano-cli from the local checkouts, so all three branches must sit on one compatible stack.**
  cardano-node master lags cardano-api and cardano-cli master by about a release (2026-10-19: node master needs cardano-api `^>=11.7` and cardano-cli `^>=11.2.2`, while cardano-api master is 11.9 and cardano-cli master is 11.4), so rebasing a cardano-api feature branch onto cardano-api master breaks the solve with `cardano-node => cardano-api^>=...`.
  Base the cardano-api branch on the last cardano-api commit whose own version, cardano-rpc version and consensus/network bounds match cardano-node's `.cabal` files, and check out the matching cardano-cli tag.
- **CHaP metadata revisions can break an older stack at a newer index-state** (observed 2026-10-19: `cardano-keys-11.0.0.0` revision 1 at 2026-10-02T10:22Z raised its bounds to `cardano-ledger-core ^>=1.22` and `cardano-crypto-class ^>=2.6`, so cardano-api 11.7 no longer solves at CHaP index-state 2026-10-13).
  Find the revision by listing the package's entries in CHaP's `01-index.tar`; its CHaP PR shows which bounds it raised.
  Relax every raised bound with `allow-older: <pkg>:<dep>` in `/work/cabal.project` instead of moving the index-state back (cardano-keys needed all five: crypto-class, crypto-wrapper, ledger-core, ledger-shelley, cardano-protocol).
- **`/installed-<hash>` instances in solver output come from the devshell's haskell.nix `shellFor` package database**, built for the cardano-api flake input pinned in `/work/flake.lock`.
  They only bias the solver and are not the cause of a conflict; when the local checkouts are on an older stack, cabal builds those dependencies from source instead.
- **cardano-api master can break its API without bumping its version, so a cardano-cli release tag or cardano-node master may not compile against a cardano-api master commit with the same version label** (observed 2026-10-20: cardano-api master after the 11.7.0.0 release, still labelled 11.7.0.0, removed `caseShelleyToBabbageOrConwayEraOnwards` and moved `HasTextEnvelope` and `getKesPeriod` to cardano-keys, so tag cardano-cli-11.2.3.1 and cardano-node master both failed to compile).
  Use the newest cardano-cli master commit that still has the matching cardano-api bound, port only the missing hunks from the later upstream commit (cardano-cli `a69c0fa0e` for `unKESPeriod`), and take cardano-node fixes from the open PR that moves node to the next cardano-api (IntersectMBO/cardano-node#6677 for 11.8); keep these as uncommitted local build fixes.
- **Hackage drift hits unbounded dependencies the same way** (observed 2026-10-20: cardano-rpc at cardano-api `0f98cc7cc` lists `grapesy` with no bound, and the metarepo index-state picked grapesy 1.2.0, whose `serverExceptionToClient` takes `ExactException`).
  Pin it in `/work/cabal.project` (`constraints: grapesy <1.2`) instead of patching the branch.

## cardano-node CI checks
- **cardano-node's stylish-haskell CI pins a prebuilt 0.14.4.0 binary that does not run in this sandbox** (exit 127: UPX-packed, missing libraries), and the nixpkgs version formats differently.
  To check formatting locally, unpack the pinned binary with upx in the scratchpad and supply the missing libraries from nixpkgs, or leave the check to CI.
  Local packages build with `-Werror` under nix (`nix/haskell.nix:361`), so a green `path:.` nix build is warning-free.

# cardano-testnet run gotchas
- **Start ad-hoc `cardano-testnet cardano` runs from a SHORT output directory (e.g. `/tmp/rt-<name>`), never under the session scratchpad.**
  The scratchpad path is ~86 chars and the default N2C socket path `<outdir>/socket/poolN/sock` then exceeds the AF_UNIX 108-byte sun_path limit, so nodes fail to start.
  This deliberately overrides the "use the scratchpad for temporary files" default; remove the /tmp directory after teardown, and kill spawned nodes by matching YOUR output dir in their command line (never a blanket `pkill cardano-node`).
- **`pkill -f '<pattern containing your output dir>'` matches the shell that runs it** when the pattern text appears literally in your own `bash -c '...'` command line, so the teardown command kills itself (exit 144) before the rest of the line runs (observed 2026-09-25 tearing down `/tmp/rt-qs`).
  Break the self-match with a bracket, e.g. `pkill -f 'cardano-node.*/tmp/rt-[q]s'`, or kill the recorded pid/process group (`kill -- "-$(cat <pidfile>)"`) and only then `pgrep -af` to verify.

