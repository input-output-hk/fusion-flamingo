---
name: verify-claimed-fixes-by-diff
description: when asked to re-verify "claimed fixed" review items, diff the exact lines across all fix commits - commit messages and claims can be wrong for some items while right for others
metadata:
  type: feedback
---

On cardano-node PR #6693 (manifest.json feature), asked to re-verify 3 previously-flagged items after the author pushed 6 "fix" commits (afb216252c..5a76c6794b).
Diffing each item individually against the very first commit showed a MIXED result, not a uniform "all fixed" or "all still broken":
1. Base `Control.Exception` import in `Testnet/Manifest.hs` -> switched to `Control.Exception.Safe` - genuinely fixed (verified via `git diff <first-commit> HEAD -- <file>`).
2. `evalEither` (Hedgehog) vs the codebase's more common `H.leftFail` (hedgehog-extras) in the two new test files - NOT touched by any of the 6 commits; `git log -p --follow` on both test files showed zero diff lines mentioning `leftFail` ever. Still `evalEither` at HEAD.
3. Record field-prefix naming (`mnMagic`/`mpNodeConfigFile`/`mgfByron` etc.) - NOT touched either; identical field names from the very first commit to HEAD, confirmed by grepping the first commit's tree (`git show <first-commit>:<file>`).

Lesson: don't trust "previously flagged, claimed fixed" framing as evidence the fix happened. For each numbered item, actually diff that item's specific lines between the pre-fix and post-fix commit (`git show <old-sha>:<file> | grep ...` vs current), independent of what the commit messages claim to have done. A PR can genuinely fix some items while silently dropping others, and a re-reviewer who only skims commit subjects (e.g. "cardano-testnet: harden the manifest tests") will miss that the specific ask inside that commit was never actioned.

Also worth generalising: this same PR's fix commits introduced several new em-dashes (U+2014) into Haskell source comments (not just prose docs) across multiple files, despite the project's explicit "no em dash" rule - a reminder to grep changed `.hs`/`.md` files for U+2014 specifically on every review pass, since authors reliably reintroduce it in freshly-written comments even after being told about the rule once.

See [[reference_manifest_field_naming]] if that memory exists for the field-naming specifics.
