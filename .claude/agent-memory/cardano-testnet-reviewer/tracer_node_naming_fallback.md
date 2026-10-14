---
name: tracer-node-naming-fallback
description: cardano-tracer does NOT need a per-node ApplicationName/TraceOptionNodeName in each node's config to tell multiple forwarding nodes apart - port-based name fallback plus connection-keyed NodeId already prevent collisions when N testnet nodes share one TraceOptions config
metadata:
  type: reference
---

When reviewing any cardano-testnet feature that forwards traces/metrics from multiple nodes to one `cardano-tracer` instance (e.g. PR #6710, `--enable-tracer`) and all N nodes end up sharing a single rewritten `TraceOptions` config (no per-node `ApplicationName`/`TraceOptionNodeName` field set), this is NOT automatically a "metrics will collide" bug:
- `cardano-node/src/Cardano/Node/Startup.hs`'s `prepareNodeName` falls back, when `tcNodeName` is absent, to `hostname_<N2N port>` - and testnet nodes always bind distinct N2N ports, so the human-readable names differ even with zero per-node config.
- `cardano-tracer` keys its internal per-node maps (`ConnectedNodesNames`, `ConnectedNodes`, metrics stores) off `NodeId`, which is derived from the physical connection (`connIdToNodeId`, `cardano-tracer/src/Cardano/Tracer/Acceptors/Utils.hs`), not the self-reported name. Even a genuine name collision is handled gracefully: `askNodeNameRaw` (`cardano-tracer/src/Cardano/Tracer/Utils.hs:149`) explicitly falls back to the unique connection id for the second node claiming an already-used name, with an explicit comment that overlapping names are "a misconfiguration" but must not lose trace data.

So the thing actually worth checking in such a PR is whether the *tracer's own listening socket* can handle multiple concurrent client connections on one accept-only Unix socket (it can - that's cardano-tracer's whole multi-node design point), not whether the shared config needs per-node identity baked in.
