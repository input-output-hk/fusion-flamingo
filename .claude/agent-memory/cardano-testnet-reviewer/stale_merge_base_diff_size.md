---
name: stale-merge-base-diff-size
description: when a PR's "full diff vs master" is suspiciously larger than its commit list implies, suspect the merge-base used is stale rather than scope creep - verify with git merge-base against the PR's own first commit's parent
metadata:
  type: reference
---

When asked to explain why a PR's reported "full diff against master" has grown much larger
than its own commits would suggest (e.g. IntersectMBO/cardano-node PR #6710 going from a
reported ~630 lines to a reported 5103 lines / 59 files across review rounds, with only
tracer-related commits added in between), don't assume scope creep in the PR. Check whether
the diff was computed against a stale base ref first:

1. Get the PR's own commit range: `git log --oneline <merge-base>..<pr-head>`.
2. Compute the TRUE merge-base directly from the PR's own first commit:
   `git merge-base <first-pr-commit> <pr-head>` (equivalently `<first-pr-commit>~1` if the
   first commit has exactly one parent reachable only from master).
3. Diff against THAT: `git diff <true-base> <pr-head> --stat`. Compare file list and line
   count against what the PR's commit messages/titles would predict.

In PR #6710, `git diff 4b90e7a~1 2e3bc9f --stat` gave the correct **18 files, 412 lines**
(pure tracer feature, matches the ~630-line prior estimate's order of magnitude), while the
externally-supplied `pr.diff` (reportedly diffed against "master") carried **59 files, 5103
lines**, padded with content from unrelated, already-merged master features that don't
appear in any of the PR's own commits (verified via `git show --stat` on each commit):
`Testnet/Manifest.hs` + schema + golden/workflow files (the separate manifest.json feature,
PR #6693 — see [[manifest_json_pr6693]]), `bench/cardano-profile`'s 1824-line JSON fixture,
`bench/tx-generator` source + changelog, `nix/workbench` scripts. This happens when whatever
tool/session produced the "full PR diff" resolved `master`/`origin/master` to a local ref
that was never updated after those other features merged — in this sandbox specifically,
`origin/master` was entirely absent as a local object (`git fetch` fails, no SSH access per
[[reference_sandbox_ssh_fetch]]-style constraints), so any script computing "merge-base with
master" either fails loudly or silently resolves to whatever stale ref happens to exist.

Lesson: when the sandbox can't fetch, don't trust a pre-computed "diff vs master" without
cross-checking it against `git merge-base <pr-first-commit> <pr-head>` computed from refs
that are actually present locally (e.g. `origin/pr/<n>`, which usually comes with enough
history to find its own true fork point even when `origin/master` itself isn't fetchable).
