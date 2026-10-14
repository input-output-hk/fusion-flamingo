# Forum announcement strategy for cardano-rpc

PUBLISHED 2026-09-17: <https://forum.cardano.org/t/cardano-node-now-speaks-utxo-rpc-typed-streaming-chain-data-straight-from-the-node/156854> (final text in [announcement-draft.md](announcement-draft.md); Slack companion in [announcement-slack.md](announcement-slack.md)).

Target: a first public announcement on forum.cardano.org (developers category).
As of 2026-09-16 no IOG blog post, Essential Cardano article or forum thread about cardano-rpc exists; release notes are the only public trace, so this post sets the narrative from scratch.
All factual claims below were verified against the code and public sources on 2026-09-16; see [cardano-rpc-status.md](cardano-rpc-status.md) and [ecosystem.md](ecosystem.md).

## Audience, in order

1. Infrastructure providers (Blockfrost, Demeter, TxPipe).
2. Tooling providers (MeshJS, Evolution SDK, Yaci, Blaze).
3. Existing dApps (Sundae, Minswap); they follow once the first two integrate.

Not SPOs.
Write for people who run nodes and build providers, not for end users.

## Timing gates

1. The features the post leans on have not shipped in a node release yet: node 11.1.1 carries cardano-rpc 11.2.0.0, the TCP/TLS flags are in cardano-rpc 11.3.0.0 (unreleased), and server reflection, ReadEraSummary and the quickstarts landed on master after the 11.3.0.0 cut, so they need the version after that.
   The grpcurl-via-reflection call to action therefore requires a node release carrying a cardano-rpc version cut after 2026-09-08; announce right after that release for a clean "available now in release X" line.
2. The published MeshJS and Evolution u5c providers fail against cardano-rpc today (v1alpha pin, see [sdks.md](sdks.md)), so the call to action cannot be "swap your provider".
   Either wait for utxorpc/spec#209 plus provider bumps, or scope the call to action to what works now: grpcurl via server reflection, and the Rust and Python quickstarts in `cardano-rpc/quickstart/`.

## Framing

Lead: cardano-node now speaks UTxO RPC natively.
Frame cardano-rpc as one more server implementation of an open, community-born spec (TxPipe's Catalyst Fund 11 project, Dolos as reference implementation, servers by TxPipe, Blink Labs and Demeter already listed on utxorpc.org), not as an IOG invention and not as a replacement for anything.
Frame the demand as community-proven: the ecosystem standardised on node bridges (Ogmios) and u5c providers in every major SDK; embedding a u5c server in the node is the node catching up with how people actually consume it.
Own the coexistence question explicitly and by name: Ogmios and Kupo are actively maintained, widely used, and not deprecated by anything IOG does; critics will quote issues #1302/#1229 if the post pretends otherwise (see [ecosystem.md](ecosystem.md)).

## Claims: say this, not that

| Say | Do not say | Why |
|---|---|---|
| Built on cardano-api; the whole hand-written server is ~6k lines of proto mapping and plumbing; era handling, CBOR, queries, evaluation and submission come from cardano-api | "cardano-api absorbed a significant part of the codebase" | Delegation is what the code shows; "absorbed" (code moved) is unevidenced |
| Compiled into the cardano-node binary, same repo, same release train; a new era is a compile error next to the era's own PR, not an external catch-up race | "In-process, no IPC" or "Ogmios lags hard forks" | Query/eval/submit still use N2C internally; Ogmios v7 already has preliminary Dijkstra support |
| One protocol, multiple interchangeable servers (Dolos, Dingo, Demeter, cardano-rpc): same SDK provider code against any of them once providers reach v1beta | "Easily swappable back and forth with Ogmios and Kupo" | Ogmios is a different protocol (JSON-RPC) and wire compatibility is an explicit non-goal (#1302); swappability is u5c-server-level and today still gated on the SDK v1alpha fix |
| Experimental interface, breaking changes between releases are expected | Anything implying production-ready | Every flag is marked EXPERIMENTAL and 11.1.1 shipped breaking changes |

Decision 2026-09-16: Mateusz dropped the explicit experimental/maturity paragraph (and the word "experimental") from the draft; the node options still print EXPERIMENTAL, so early replies may raise it.

## Post outline

1. What shipped: gRPC/UTxO-RPC server embedded in cardano-node, method list, transports (unix socket, TCP, TLS), server reflection, experimental status.
2. Try it in five minutes: config flags, grpcurl with reflection, links to Rust/Python quickstarts.
3. Why we built it into the node: the spec already won (SDK providers, multiple servers), infra providers hand-roll this exact interface today, and in-tree means era support arrives compile-checked with the era itself.
4. How it relates to Ogmios, Kupo and Dolos: coexistence paragraph, by name, plus what cardano-rpc will NOT do (indexing, broad queries; that is sieve/indexer territory).
5. Roadmap and invitation: WaitForTx and mempool methods in review (PR #1222), node kernel access, links to #1302 for the parity roadmap, ask for feedback and integration reports.

## Evidence: hard-fork tooling breakage is real (researched 2026-09-17)

The draft's "patched your own node integration in a hurry at a hard fork" anchor is citable, not rhetorical.
Chang (Sept 2024) is the strong case: cardano-db-sync issues #1841 (ledger-state parse failure), #1852 (genesis-resync crash), #1836 (~35% memory jump) and #1853 (stuck at slot) all within ten days of the fork, plus the same-day cardano-node 9.1.1 hotfix for the post-fork replay bug.
Same pattern in 2026: Musashi testnet's Dijkstra fork broke pallas block decoding (txpipe/pallas PRs #799/#800).
Usage rules: cite Chang narrowly (Alonzo/Vasil breakage could not be substantiated), lean on our own tooling's incidents (db-sync, node), and never cite Ogmios #415 (Conway blocks misreported) publicly; the Ogmios argument stays structural.

## Counterargument prep

1. "Why not contribute to Ogmios/Kupo instead?"
   Different layer, not a fork of effort: Ogmios is a JSON-RPC bridge and stays; cardano-rpc implements the typed gRPC spec the SDK ecosystem already adopted, inside the node where era handling is compile-time checked.
   Never mention maintainer bandwidth; Benkort is CF's open-source Technical Director and both tools are actively maintained.
2. "Doesn't this deepen Haskell-node/IOG dependence?"
   The opposite: u5c is the portability layer.
   The same client code runs against Dolos (Rust), Dingo (Go), Demeter (hosted) or cardano-rpc (Haskell node); picking the node-embedded server is a deployment choice, not a lock-in.
   Amaru alignment on mempool semantics reinforces this.
3. "More tooling fragmentation?"
   This is consolidation on a spec, not a new bespoke API: no new protocol, no new SDKs, one more server behind an existing multi-vendor interface.
   IOG adopting the community's spec is the anti-fragmentation move.

## Open decisions (Mateusz/team, not mine)

1. Pre-brief Matthias Benkort before publishing, given the public replacement-language issues and the fresh Acropolis narrative; his public silence on cardano-rpc means the story is currently unset.
2. Publish timing: after the next cardano-node release (11.3.0.0 features), and before or after the SDK v1beta fix lands.
3. Whether IOG requests a cardano-rpc entry on utxorpc.org/servers before the post, so the "one of several servers" claim is visibly true.

## Thread replies posted

2026-09-23, correction reply (post author is TL0 and cannot edit the original; wolf31o2's remark came via Discord, not the forum):

> A correction to the post above: Blink Labs' UTxO RPC server worth naming is Dingo, their Cardano node written in Go, which serves the spec natively through a built-in API plugin. The post credits their Node API instead; that is a multi-protocol sidecar over a local Haskell node, and for the UTxO RPC part cardano-rpc now does the same job in-process. Thanks to wolf31o2 of Blink Labs for the catch. It makes the wider point nicely: two independent node implementations, Dingo in Go and cardano-node in Haskell, now speak the same interface natively, so client code written against the spec is not tied to either node. I will fix the wording in the post itself as soon as the forum lets me edit it.
