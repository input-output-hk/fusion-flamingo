---
name: regenerate-tags
description: Regenerate the agent-tags ctags file by running haskdogs over the repos in haskdogs-dirs.txt as they are checked out.
---

Regenerate `/work/agent-tags` so symbol lookups stay current.

## Procedure

1. Run the script from `/work`:
   ```
   bash /work/haskdogs-regenerate-tags.sh agent-tags
   ```
   Use a 5-minute timeout (300000ms).

2. Verify the output file exists and is non-empty:
   ```
   ls -lh /work/agent-tags
   ```

3. Report the result: file size, whether it succeeded or failed, and every repo the script printed on a branch other than `master`.

## What the script does

- Prints the current branch and commit of each repo listed in `/work/haskdogs-dirs.txt`.
- Runs `haskdogs` over those repos as they are checked out; it never switches branches or pulls.
- Renames the output to `agent-tags`, keeping any pre-existing `tags` file.

## Notes

- The script requires `haskdogs` and `hasktags` in PATH (both provided by the devshell).
- For tags of the latest upstream default branches, run `/work/haskdogs-reset-to-master.sh` on the host first.
  Its `git fetch` fails in the sandbox (no git over SSH there).
