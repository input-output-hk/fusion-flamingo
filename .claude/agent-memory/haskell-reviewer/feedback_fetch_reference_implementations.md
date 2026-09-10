---
name: fetch-reference-implementations-for-spec-questions
description: when a review question is "does this diverge from the spec/reference implementation", fetch the actual reference source (gh api / WebFetch) rather than reasoning from the vendored proto comments alone - the reference implementations can disagree with each other
metadata:
  type: feedback
---

When asked to judge whether an implementation's behaviour diverges from "the reference implementation" for a semi-formal spec (e.g. gRPC Server Reflection, which has no RFC, only a doc + comments + de facto implementations), don't rely on the vendored `.proto` file's comments alone - they're often silent on error-handling specifics.
Instead fetch the actual reference source: `gh api repos/<org>/<repo>/contents/<path>` (or WebFetch on a raw.githubusercontent.com URL, though that sometimes 404s or gets summarized away by the fetch model - `gh api ... --jq '.content' | base64 -d` is more reliable for exact code).

**Why it matters:** on the cardano-rpc grpc-reflection review (2026-09-09), the two most commonly available "reference implementations" (grpc-go and the C++ core, both in `grpc/grpc`/`grpc/grpc-go`) actually DISAGREE with each other on unset-oneof handling: Go terminates the whole RPC with a gRPC-level `InvalidArgument` error, while the C++ implementation (which the vendored proto's own header names as "canonical") answers in-stream and keeps the bidi stream alive. Judging "does this diverge from the reference" without checking both would have produced a wrong or incomplete verdict - the code under review actually matched the C++-canonical behaviour despite superficially looking like it diverged from "the" reference (Go, the more commonly-known one).

**How to apply:** for any review question of the form "is diverging from X's implementation acceptable", pull X's actual source before answering, and check whether there's a more canonical alternative reference the project's own vendored files point to (e.g. a "canonical version of this proto" comment) - don't stop at the first implementation found.
