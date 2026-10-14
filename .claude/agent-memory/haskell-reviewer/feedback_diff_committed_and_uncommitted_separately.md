---
name: diff-committed-and-uncommitted-separately
description: when a review scope is "committed diff PLUS uncommitted working tree", diff each touched file against BOTH bases separately - a bug in the committed state can already be silently fixed locally but not yet committed
metadata:
  type: feedback
---

On cardano-cli PR #1452 (branch mgalazyn/feature/plutus-v4-scripts), reading a changed test file with `cat`/`Read` shows the CURRENT working-tree content, which already had local uncommitted fixes applied on top of the committed state.
`Test/Golden/Dijkstra/Transaction/BuildRaw.hs` on disk had a real hash and the correct Dijkstra pparams fixture path - but `git show HEAD:<path>` revealed the actually-committed version still had `let v4ScriptHash = "REPLACE_ME"` and pointed `--protocol-params-file` at the wrong (Conway-era) fixture.
Reading only the working-tree file would have missed a genuine, severe, still-unpushed defect entirely.

**How to apply:** when asked to review "committed diff + uncommitted changes", don't just `cat`/`Read` the file on disk and assume it represents what's under review - separately run `git diff origin/<default>...HEAD -- <file>` (or `git show HEAD:<file>`) for the committed state AND `git diff -- <file>` for the uncommitted delta on the SAME file, especially for any file the committed diff touches. A placeholder, TODO, or wrong path fixed only in the working tree is not yet part of the PR and must be flagged as "needs to be committed," not silently treated as resolved.
See [[feedback_verify_claimed_fixes_by_diff]] for the related habit of diffing exact lines rather than trusting framing/claims.
