---
name: check-insertwith-arg-order
description: Map/KeyMap.insertWith and unionWith apply the merge function as f new old (insertWith) / f leftVal rightVal (unionWith) - a "copy if missing" helper that checks the wrong side silently overwrites instead of preserving
metadata:
  type: feedback
---

`Data.Map`/`Data.Aeson.KeyMap`'s `insertWith f k new m` calls `f new old` when `k` is already present (new value first); `unionWith f m1 m2` calls `f v1 v2` for keys in both maps (left map's value first). A merge helper that's supposed to be "preserve the existing value, only fill gaps from the template" must branch on whether the *existing/old* map has the key - not on whether the *template/new* value has it.

Concretely wrong pattern (seen on cardano-node PR #6710, `Testnet/Start/Cardano.hs`'s `enableTraceForwarding`/`mergeNamespace`): `copyIfMissing key = maybe id (KeyMap.insert key) $ KeyMap.lookup key forwarding` - this checks the hard-coded template (`forwarding`), which always has the key, so it unconditionally overwrites the user's existing value every time, despite the name and intent being "don't touch it if the user already set it". The fix checks `KeyMap.member key existing` (or whichever side is the "don't clobber" side) instead.

When reviewing any `insertWith`/`unionWith`-based config-merge logic, always re-derive which argument is "new" and which is "old" from the type signature docs, don't trust a locally-chosen variable name (`forwarding`/`existing`, `template`/`user`, etc.) - and check whether such logic is actually exercised by the PR's own tests before calling it low-severity (a merge-with-nonempty-existing-config path with no test coverage is easy to get backwards and ship undetected).
