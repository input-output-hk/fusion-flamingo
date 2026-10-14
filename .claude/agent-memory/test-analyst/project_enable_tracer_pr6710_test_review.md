---
name: enable-tracer-pr6710-test-review
description: PR #6710 (cardano-testnet --enable-tracer) test-side review findings, reviewed at head bc0438d5 2026-10-01, updated through round 3 (head 2e3bc9f8b6, 2026-10-05)
metadata:
  type: project
---

Reviewed IntersectMBO/cardano-node PR #6710 "Add prometheus support to cardano-testnet" (adds `--enable-tracer`, spawns `cardano-tracer`, forwards node traces to it). Single test module `cardano-testnet/test/cardano-testnet-test/Cardano/Testnet/Test/EnableTracer.hs`.

**Core finding**: the test (`H.assertFilesExist` on the tracer's config/stdout/stderr files, `EnableTracer.hs:34-38`) only proves cardano-tracer was launched, not that it stayed up or that Prometheus/forwarding actually work. A real probe (HTTP GET on the Prometheus endpoint) is *currently impossible to write* because the allocated Prometheus port (`CardanoTracer.hs:96`) is never surfaced anywhere outside that function - `startCardanoTracer` returns only `(socketFile, hProcess)`, and `TestnetRuntime` (`Testnet/Types.hs:126-133`) has no tracer field at all. This is the kind of gap worth checking first on any "does X work" test: trace whether the value a stronger assertion would need is even reachable from the test, before proposing the assertion.

**Useful HTTP-assertion pattern found**: `cardano-testnet/test/cardano-testnet-test/Cardano/Testnet/Test/SubmitApi/Transaction.hs:35,142-148` does `Network.HTTP.Simple`'s `parseRequest`/`httpLbs` wrapped in `H.evalM` - the template to point to whenever a test needs an HTTP assertion against a testnet-spawned service.

**Resource-cleanup pattern confirmed sound**: `Testnet.Process.Run.initiateProcess` (`Process/Run.hs:289`) registers `cleanupProcessBounded` via resourcet's `register`, and `integrationRetryWorkspace`/`integrationWorkspace` (`Testnet/Property/Util.hs:46-59`) wrap the whole property in `H.runFinallies`, so any process started via `initiateProcess` (nodes, tracer, anything) gets killed on test end *or* failure automatically - no need for tests to manually track/kill child processes started this way. Worth checking this chain before flagging "process X is never killed" as a leak.

Full ranked review sent to team-lead inline and at (session-scratchpad, not durable) `scratchpad/pr6710/review-tests.md`.

**Round 2 (new head 072e506, same day)**: author addressed both of reviewer palas's src-level asks (pre-bind `Ping.waitForPortClosed` and post-start `Ping.waitForTcpPort` readiness probe on the Prometheus port, `CardanoTracer.hs:106-109,126-129`) by copy-pasting the exact bounded-retry pattern already used for node ports in `Runtime.hs:170-175` (same 45s/0.1s timeout, same dangling/truncated comment - pre-existing quirk, not newly introduced). This downgrades my blocker 1 to should-fix: a crashed/dead Prometheus now fails the whole test loudly (via `throwString` propagating through `createAndRunTestnet`), even though `EnableTracer.hs` itself is byte-identical (still only `H.assertFilesExist` on 3 files - diff-the-two-heads before re-flagging "the test wasn't improved", the *test* often won't change when the *guarantee* improves at the src level). Blocker 2 (Prometheus port not in `TestnetRuntime`) is unchanged/still open. New in this round: `enableTraceForwarding` (`Start/Cardano.hs:591-629`) now copies to a `.tracer`-suffixed file instead of mutating in place, and correctly threads the new path into node-start args, `waitForBlockThrow`, and `TestnetRuntime.configurationFile` together - good pattern to check (grep all three use-sites) whenever a PR switches a "mutate in place" helper to "copy and return new path".

**Round 3 (new head 2e3bc9f8b6, 2026-10-05)**: blocker 2 now fixed - `Testnet/Types.hs:134` adds
`prometheusPort :: !(Maybe PortNumber)` to `TestnetRuntime`, populated at `Start/Cardano.hs:506` from a
new `CardanoTracerRuntime` record (`CardanoTracer.hs`, replaces the old `(FilePath, ProcessHandle)` tuple
return of `startCardanoTracer`). `EnableTracer.hs:46-48` now reads it with `H.nothingFail` and asserts
`Ping.waitForTcpPort 45 0.1 "127.0.0.1" port` succeeds. **Residual gap**: this is still only a raw TCP
connect (`Testnet/Ping.hs:107-119`'s `checkTcpPort`), never an HTTP GET - it cannot tell "a socket is
listening" from "Prometheus is serving correct content", and it exactly duplicates a guarantee the src
already enforces twice over (CardanoTracer.hs's own post-start probe with identical 45/0.1 params, plus a
new `Ping.waitForSprocket 120 0.2` in `Start/Cardano.hs` for the forwarder socket) - both already fail
`createAndRunTestnet` loudly before the test body even runs. The test's own comment
(`EnableTracer.hs:44-45`, "confirms... is up and serving metrics") overstates what the check verifies.
**cardano-tracer's Prometheus route shape** (useful for writing the real assertion, from
`cardano-tracer/src/Cardano/Tracer/Handlers/Metrics/{Prometheus,Utils}.hs`): `GET /` with
`Accept: application/json` returns `renderJson` - a flat JSON object `{"<nodeName>": "/<slug>", ...}`,
one entry per connected node; `nodeName` defaults to cardano-node's `prepareNodeName` fallback
`<hostname>_<N2N port>` (see [[tracer_node_naming_fallback]] in the cardano-testnet-reviewer memory),
`slug = Text.Slugify.slugify nodeName`. `GET /<slug>` returns that node's Prometheus/OpenMetrics text
exposition. `GET /targets` + the JSON Accept header returns Prometheus HTTP service-discovery JSON.
Without the JSON Accept header, `/` returns an HTML list instead (`contentHdrUtf8Html`). Proposed concrete
assertion: HTTP GET `/` with the JSON Accept header (reuse the `Network.HTTP.Simple` pattern from
[[enable-tracer-pr6710-test-review]]'s own earlier note on `SubmitApi/Transaction.hs:35,142-148`), decode
to `Map Text Text`, assert non-empty, optionally follow one value and assert its body is non-empty too.
**Also found**: `enableTraceForwarding`/`mergeBackends` (`Start/Cardano.hs:598-654`) was rewritten this
round from `nub`-based list dedup to a `Map`-keyed merge that re-derives a dedup key by
`Text.words`-splitting each backend's rendered-YAML string - a correctness-sensitive text-parsing change
with zero direct unit-test coverage (`grep -rl mergeBackends cardano-testnet/test/` is empty); only
exercised indirectly through this one integration property.
