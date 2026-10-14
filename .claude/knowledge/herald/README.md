# herald

Domain knowledge about the herald changelog and release tooling, moved out of AGENTS.md.
The operational traps for `herald validate` stay in AGENTS.md.

- Changelog/release automation CLI in `/work/cardano-dev/herald/`.
- Nix flake at `/work/cardano-dev/flake.nix` (top level), exposed as `apps.herald`.
  External ref: `github:input-output-hk/cardano-dev#herald`.
- GHA composite actions at `actions/{herald-validate,herald-release}/action.yml` (top level of cardano-dev, NOT `.github/actions/`), versioned independently via per-action `version.txt` and git tags like `herald-release-0.0.2.0`; consumers reference them as `uses: input-output-hk/cardano-dev/actions/<name>@<tag>`.
- **Both herald actions' default `herald-ref` input is a hard-coded herald tag that goes stale between herald releases** (herald-release-0.0.2.0 and herald-validate-0.0.1.0 still defaulted to herald-0.1.1.0 while herald was at 0.1.2.0; as of 2026-10-06 herald-release-0.0.3.1 and herald-validate-0.0.1.1 default to herald-0.2.0.0, the current herald).
  Consumer workflows should pass `herald-ref: github:input-output-hk/cardano-dev/herald-<version>` explicitly to control which herald binary CI runs; bumping the action tag alone does not update the binary unless the new action tag also carries a new default. Check the default in `actions/<name>/action.yml` at the tag before relying on it.
- **Changelog fragments are user-facing release notes**, aimed at end users and library users.
  Describe the observable change - fixed behaviour, new/changed/removed API - never implementation internals (record field names, private helpers, how the fix works).
  Write full prose sentences, not bullet lists; if a reader must know the codebase to parse it, rewrite it.
- **`herald validate --diff` only counts fragments ADDED since the fork point.**
  Modifying a fragment that already exists on the base branch (e.g. reusing a merged PR's fragment by bumping its `pr:` field) does not count - the check fails with "has modified files but no changelog fragment".
  Each PR needs its own new fragment file; never repurpose merged fragments.
- **Always check the target repo's `.herald.yml` for valid `kinds:` before writing a changelog fragment** - kinds are project-specific (e.g. breaking, bugfix, compatible, documentation, feature, maintenance, refactoring), and guessing one (e.g. "compatibility") produces an invalid fragment.
