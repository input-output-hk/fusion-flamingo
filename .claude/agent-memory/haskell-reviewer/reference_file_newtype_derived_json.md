---
name: file-newtype-derived-json
description: cardano-api's File newtype derives FromJSON/ToJSON from the wrapped FilePath, so manual unFile/File wrapping in aeson instances is not itself proof of a wrong direction/content tag
metadata:
  type: reference
---

`Cardano.Api.IO.Internal.Base`'s `File content (direction :: FileDirection) = File { unFile :: FilePath }` derives `(Eq, Ord, Read, Show, IsString, FromJSON, ToJSON)` via `newtype` deriving.
Aeson has an OVERLAPPING `FromJSON String`/`ToJSON String` instance, so `File`'s derived instances round-trip a plain JSON string with no wrapper object - identical wire format to `FilePath`.

Consequence for review: seeing `Ctor . File <$> o .: "field"` or `"field" .= unFile (someField x)` in a hand-written aeson instance is NOT automatically an "awkward shim revealing the tags don't fit" - `o .: "field"` (or bare `someField x .= ...`) would type-check identically via the derived instance, since `File`'s FromJSON/ToJSON are literally the same instance as the underlying `FilePath`.
The manual wrap/unwrap is at most a redundant-verbosity nit, not a correctness or tag-mismatch issue.
It IS necessary (not a nit) wherever the code also transforms the string content itself (e.g. `File (makeRelative outputDir (unFile x))`) - there the wrap/unwrap is unavoidable because `File` has no `fmap`-like combinator over its content.

Verified on cardano-node PR #6693's "use typed file paths in the manifest" commit (`Testnet/Manifest.hs`): `ManifestPaths . File <$> o .: "nodeConfigFile"` and `"nodeConfigFile" .= unFile (mpNodeConfigFile p)` could both be written without the explicit `File`/`unFile` and still compile identically - flagged as a minor simplification suggestion, not a bug, once this was confirmed by checking `File`'s deriving clause rather than assuming from the shim's presence alone.
See [[manifest-json-pr6693]] (cardano-testnet-reviewer's memory) for the wider PR context.
