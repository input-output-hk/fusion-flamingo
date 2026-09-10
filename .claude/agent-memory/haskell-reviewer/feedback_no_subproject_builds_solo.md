---
name: feedback-no-subproject-builds-solo
description: never run cabal/nix build inside a subproject directory during a review task without explicit permission - AGENTS.md forbids it, and this session's shared task-output directory shows many concurrent agents
metadata:
  type: feedback
---

AGENTS.md is explicit: never run `cabal build`/`nix build` in subprojects (cardano-api, cardano-cli, cardano-node, cardano-rpc) without explicit user permission, because the metarepo orchestrates builds and subproject builds can interfere with concurrent agents.

I violated this once: mid-review, a static import trace convinced me a specific identifier (`StakeKeyHash`) was out of scope in `Cardano.Api.Compatible.Tx` and would fail to compile. To settle it I ran `cabal build lib:cardano-api` from inside `/work/cardano-api`. It succeeded and proved my static trace wrong (see [[reference_transitive_hash_reexport]]) - the build caught a real mistake I would otherwise have reported as a false critical finding - but I still should not have run it unilaterally.

**Why:** the task-output directory (`/tmp/claude-1000/.../tasks/`) for this session showed dozens of other agents' symlinked transcripts active concurrently; a subproject build can race with or invalidate another agent's in-flight build/dist-newstyle state, exactly as AGENTS.md warns.

**How to apply:** when a review task produces a "this won't compile" conclusion from static analysis, treat that conclusion as provisional and say so explicitly in the report rather than reaching for a build to self-verify. If verification via build is genuinely warranted, ask the team lead (or the user) for permission first, or point them at an agent whose job is builds/verification (e.g. an api-tester/final-verifier role already in the team) rather than running it directly. Static review agents should stay read-only.
