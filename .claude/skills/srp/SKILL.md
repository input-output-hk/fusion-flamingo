---
name: srp
description: Add or update source-repository-package stanzas in cabal.project with correct sha256 hashes.
argument-hint: <repo-url> <tag> [subdirs...]
---

Add or update a `source-repository-package` stanza in a `cabal.project` file, computing the correct sha256 hash.

Arguments: $ARGUMENTS

## Procedure

1. **Parse arguments.** Expect at minimum a repo URL and a git tag/commit.
   Optional trailing arguments are subdirectory names.
   If the user gives a submodule path (e.g. `cardano-api`) instead of a URL, resolve the remote URL via `git -C <path> remote get-url origin`.
   If the user gives a submodule path without a tag, use `git -C <path> rev-parse HEAD` for the tag.

2. **Compute the sha256 hash:**
   ```bash
   HASH=$(nix run nixpkgs#nix-prefetch-git -- --quiet <url> --rev <tag> 2>/dev/null \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['sha256'])")
   SRI=$(nix hash convert --hash-algo sha256 --to sri "$HASH")
   ```

3. **Build the stanza:**
   ```
   source-repository-package
     type: git
     location: <url>
     tag: <tag>
     --sha256: <SRI hash>
     subdir:
       <subdir1>
       <subdir2>
   ```
   Omit the `subdir:` block if no subdirectories were specified.

4. **Insert or update in cabal.project.**
   - If a stanza with the same `location:` already exists, replace it entirely (tag, hash, subdirs).
   - Otherwise append after the last existing `source-repository-package` block, or before the end of file if none exist.
   - Preserve the comment above the SRP section if present (the "IMPORTANT: Do NOT add more..." comment).

5. **Report** the stanza that was written, including the computed hash.

## Flake lock updates after SRP changes
When SRPs are updated, the user may also need flake lock updates to match the new index-states.
The hackage.nix input name varies by flake - check `nix flake metadata <flake-dir> | grep -i hackage` to find the correct path (e.g. `haskellNix/hackage`, `hackageNix`, etc.).
Update with: `nix flake lock <flake-dir> --update-input <hackage-input> --update-input CHaP`

## Important rules
- NEVER use placeholder hashes. Always compute the real hash.
- NEVER omit the `--sha256:` line. Nix requires it for reproducible fetching.
- Use SRI format (`sha256-...=`) not base32 nix format.
- The `--sha256:` line is a cabal comment (starts with `--`) that nix's haskell.nix reads.
- Always write `https://github.com/...` in the stanza location, even when the local remote is SSH - CI cannot fetch SSH.
  SSH may only be used for the hash computation fetch if https fails locally.
