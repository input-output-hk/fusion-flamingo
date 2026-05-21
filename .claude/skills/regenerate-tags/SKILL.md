---
name: regenerate-tags
description: Regenerate the agent-tags ctags file by pulling latest default branches and running haskdogs.
---

Regenerate `/work/agent-tags` so symbol lookups stay current.

## Procedure

1. Run the script from `/work`:
   ```
   bash /work/regenerate-tags.sh agent-tags
   ```
   Use a 5-minute timeout (300000ms).

2. Verify the output file exists and is non-empty:
   ```
   ls -lh /work/agent-tags
   ```

3. Report the result: file size and whether it succeeded or failed.

## What the script does

- Saves the current branch in each repo listed in `/work/haskdogs-dirs.txt`.
- Checks out the default branch (from `origin/HEAD`) and pulls.
- Runs `haskdogs` to generate a tags file from all repos.
- Renames the output to `agent-tags`.
- Restores all repos to their original branches.
- Backs up and restores any pre-existing `tags` file.

## Notes

- The script requires `parallel`, `haskdogs`, and `hasktags` in PATH (all provided by the devshell).
- SSH access to GitHub is required for `git pull` to work.
- If pulls fail due to SSH issues, the tags are still generated from the local state.
