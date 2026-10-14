---
name: companion-pr-cross-check
description: use a companion/consumer PR in a sibling repo as ground truth when a diff's import is missing or a dependency symbol's existence can't be confirmed locally
metadata:
  type: reference
---

When a diff references a qualified module alias that has no matching import statement (e.g. `Plutus.OrdExUnits` with no `qualified as Plutus` import anywhere in the file), check whether a companion/consumer PR in a sibling repo (e.g. cardano-cli PR wired against the same not-yet-merged cardano-api API) already imports that exact symbol.
It often names the precise defining module (`import Cardano.Ledger.Plutus.ExUnits (OrdExUnits (..))`), which both confirms the type exists and gives the exact fix (add that import, qualified to match the diff's alias) instead of guessing at a plausible-looking existing alias in the same file.

Separately: an indexed sibling-repo checkout (e.g. agentix's local `cardano-ledger` clone) used to verify a ledger lens/field exists can be stale in BOTH directions, not just "newer than pinned" (the direction `.claude/rules/haskell.md`'s "Dependency version skew" gotcha already documents).
If a PR's diff uses several new lenses (e.g. Leios/endorser-block `ppu*Ls` on `DijkstraEraPParams`) and NONE of them appear anywhere in that checkout's full record definition (visible by finding a totalizing function like an `applyPPUpdates`/`downgrade*` that pattern-matches every field), that is real signal the checkout predates the upstream ledger change the PR depends on - but it is evidence to report as "please confirm the exact pinned version has these", not proof the PR itself is wrong, especially when a companion consumer PR independently reconstructs the identical field list/order/names (strong sign both PRs target a real, coordinated, just-not-yet-verified-locally upstream change).
See [[feedback_verify_claimed_fixes_by_diff]] for the related principle of not trusting a claim (fixed or existing) without checking the diff/source directly.
