---
name: integration-retry-workspace-fresh-dirs
description: integrationRetryWorkspace gives each retry attempt a freshly-suffixed workspace directory, so "stale state from a previous failed attempt in the same directory" concerns do not apply within a single Hedgehog property's retries
metadata:
  type: reference
---

`integrationRetryWorkspace n workspaceName f` (cardano-testnet/src/Testnet/Property/Util.hs) runs `H.retry n $ \i -> H.runFinallies $ H.workspace (workspaceName <> "-" <> show i) f`.
Each retry index `i` gets a distinct, freshly created workspace directory (`H.workspace` creates a new unique-ish dir), never the same directory as a prior failed attempt.
So when reviewing a feature that worries about "leftover file from a previous run in the same directory" (e.g. a stale manifest, stale lock file, stale socket), that risk does NOT materialise for callers going through this helper or `createAndRunTestnet` inside a Hedgehog property - only for callers that manage their own directory across separate invocations (CLI users reusing `--output-dir`, or library callers outside the retry-workspace pattern).
Found while reviewing PR #6693's manifest.json feature: see [[manifest_json_pr6693]].
