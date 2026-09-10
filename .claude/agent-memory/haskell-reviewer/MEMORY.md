# Haskell Reviewer Memory

- [Transitive Hash(..)/AsType(..) re-export gotcha](reference_transitive_hash_reexport.md) — don't declare a constructor "out of scope" from export-list greps alone; data-family wildcards pull in constructors transitively
- [Never solo-run subproject builds during review](feedback_no_subproject_builds_solo.md) — even to self-verify a "won't compile" claim; ask for permission or defer to a builder/verifier agent instead
- [protobuf enum value scoping](reference_protobuf_enum_value_scoping.md) — enum VALUE symbols are scoped to the enum's enclosing scope, not the enum type; easy category to miss in a hand-rolled reflection/descriptor symbol index
- [Fetch reference implementations for spec-divergence questions](feedback_fetch_reference_implementations.md) — pull the actual reference source (gh api/WebFetch); different "reference" implementations can disagree with each other
