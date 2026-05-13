---
name: proto-gen
description: Regenerate proto-lens Haskell code from .proto files using buf in the nix dev shell.
disable-model-invocation: true
argument-hint: [package-dir]
---

Regenerate proto-lens code from .proto files.

If no argument is given, default to `cardano-rpc`.

Package directory: $ARGUMENTS

## Procedure

1. Run: `nix develop --command bash -c "cd <package-dir> && buf generate proto"`
2. Verify the command succeeded.
3. Show a summary of which files were regenerated (check git status for changed files under `<package-dir>/gen/`).

## Important rules
- NEVER manually edit files under `gen/` — they are overwritten by this command.
- If buf or proto-lens-protoc are not found, it means you're not in the nix dev shell — always use `nix develop --command`.
- After regeneration, you may need to run `/build-fix` to ensure everything compiles.
