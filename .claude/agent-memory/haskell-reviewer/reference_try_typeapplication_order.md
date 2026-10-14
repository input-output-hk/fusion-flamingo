---
name: try-typeapplication-order
description: safe-exceptions' try has implicit forall order (m, e, a) - TypeApplications must be written `try @m @e`, not `@e @m`
metadata:
  type: reference
---

`Control.Exception.Safe.try :: (MonadCatch m, Exception e) => m a -> m (Either e a)` (safe-exceptions 0.1.7.4, verified from source).
With no explicit `forall`, GHC's implicit type-variable order is left-to-right first-occurrence over the WHOLE signature including the constraint context: `m` (from `MonadCatch m`) first, then `e` (from `Exception e`), then `a` (first seen in the body).
So `try @IO @IOError $ someAction` correctly binds `m := IO`, `e := IOError` - equivalent to the older `(try someAction :: IO (Either IOError ()))` idiom, not a typo-prone reversed application.

Confirms this pattern is correct wherever seen (e.g. cardano-node PR #6693's manifest temp-file cleanup, `void . try @IO @IOError $ hClose tmpHandle`) - don't flag it as suspicious without checking the actual constraint order in the library source; guessing the order from call-site intuition alone risks a false "this looks backwards" comment.
