---
name: chap-no-srp-pinned-version-check
description: when a subproject's cabal.project has NO source-repository-package override for a dependency, that dependency resolves to a real CHaP release matching the version bound - download that exact tarball to verify claims like "depends on unreleased master"
metadata:
  type: reference
---

On cardano-cli PR #1452, the PR's own framing said a `Query/Run.hs` change (`unKESPeriod . getKesPeriod`) was a "drift fix for building against unreleased cardano-api master."
Checked `cardano-cli/cabal.project`: no `source-repository-package` stanza for cardano-api at all, and `cardano-cli.cabal` bounds it `^>=11.7`.
Queried CHaP directly (`curl https://chap.intersectmbo.org/package/cardano-api/`) - only `cardano-api-11.7.0.0` exists, so that IS the real resolved dependency for anyone building this repo standalone (its own CI included), not "unreleased master".
Downloaded that exact tarball (`curl -o x.tar.gz https://chap.intersectmbo.org/package/cardano-api-11.7.0.0.tar.gz`, the foliage-style URL - see [[reference_intersectmbo_haddock_layout]]-adjacent CHaP gotchas) and read `Cardano/Api/Certificate/Internal/OperationalCertificate.hs` directly: `getKesPeriod :: OperationalCertificate -> Word` already unwraps internally, so composing `unKESPeriod` after it is a genuine type error at the pinned version - the PR's own "unreleased master" framing was correct in spirit but the diff as committed doesn't actually update the cabal bound or add an SRP pin, so it breaks the real build.

**How to apply:** never trust a PR description/comment's claim that code "requires unreleased upstream" at face value. First check the dependency's cabal.project for a `source-repository-package` override - if there isn't one, the true target is whatever the CHaP/Hackage index resolves at the stated bound and index-state, and that's very likely an already-RELEASED version with different (often older/simpler) API shapes than what a developer's local sibling checkout of unreleased upstream shows. Verify by downloading the exact release tarball and reading the real source, exactly like [[reference_verify_srp_pinned_commit]] does for the opposite case (an actual SRP pin to an exact unreleased commit).
