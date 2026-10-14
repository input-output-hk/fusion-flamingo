---
name: verify-srp-pinned-commit
description: How to check function behaviour at an exact source-repository-package pin without cloning or building, and why this matters when a PR's own stated root cause is suspect
metadata:
  type: reference
---

When `cabal.project` gains a `source-repository-package` stanza pinning an UNRELEASED commit (not a tagged release), the local sibling checkout (e.g. `/work/cardano-api`, usually at master) and the agentix index (usually stale, often pre-dates the feature entirely) do NOT reflect that pinned commit's code.
Do not answer "does function X exist" or "what does X actually do" from either source in that situation - both gave wrong/empty answers when checking `toLedgerBlsKey`/`createBlsKeyRegistration` for [[reference_verify_claimed_fixes_by_diff]]-style claims on cardano-cli PR #1423.

Fetch the exact pinned commit's file (or its patch vs. parent) directly via GitHub's API - no clone, no build, read-only:
```
gh api repos/<owner>/<repo>/commits/<sha> --jq '.files[].filename'          # which files changed in that commit
gh api repos/<owner>/<repo>/commits/<sha> --jq '.files[] | select(.filename=="path/To/File.hs") | .patch'   # just that file's diff
gh api repos/<owner>/<repo>/contents/path/To/File.hs?ref=<sha> --jq '.content' | base64 -d   # full file at that exact ref
```
This resolved two things statically that would otherwise have needed a build: (1) confirmed a new function (`toLedgerBlsKey`) only derives a verification key + PoP from a signing key, never leaks the raw key; (2) confirmed `Cardano.Api.Experimental.obtainCommonConstraints` DOES have a real `DijkstraEra -> id` arm (not a TODO stub) at the exact pin the PR under review uses - which contradicted both the PR's own changelog fragment and a Copilot review comment that both assumed the constraint was unimplemented for Dijkstra. A PR's changelog/commit message describing its own root cause is a claim, not ground truth - verify it the same way you'd verify a "fixed" claim on a diff ([[feedback_verify_claimed_fixes_by_diff]]), and prefer the exact pinned commit over any nearby ref when the pin is to an unreleased SHA.
