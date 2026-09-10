---
name: protobuf-enum-value-scoping
description: protobuf enum VALUE names are scoped to the enum's ENCLOSING scope, not the enum type itself - a common miss when building a symbol index over FileDescriptorProto (e.g. for gRPC Server Reflection)
metadata:
  type: reference
---

Protobuf's "C++ scoping" rule: an enum value's fully-qualified symbol name has the ENUM'S ENCLOSING scope as its prefix (package or containing message), not the enum type's own name as prefix.
E.g. for `package cardano.rpc; enum Era { byron = 0; ...; conway = 6; }`, the value `conway`'s fully-qualified symbol is `cardano.rpc.conway` (a SIBLING of `cardano.rpc.Era`), not `cardano.rpc.Era.conway`.
This mirrors how C++ unscoped enums leak their enumerators into the enclosing namespace - hence the name.

Verified against the canonical C++ gRPC reflection implementation (`grpc/grpc`'s `src/cpp/ext/proto_server_reflection.cc`, `GetFileContainingSymbol` delegates to `DescriptorPool::FindFileContainingSymbol`, which resolves enum values this way).

**Why it matters for review:** a hand-rolled symbol index walking `FileDescriptorProto`/`DescriptorProto`/`EnumDescriptorProto` (e.g. for implementing `grpc.reflection.v1`'s `file_containing_symbol`) that maps only `enumType ^. name` to build the enum TYPE's symbol, but never walks `enumType ^. value` to register each `EnumValueDescriptorProto`'s name at the SAME enclosing-scope prefix, will silently answer NOT_FOUND for enum-value symbol lookups that a conformant client (or the canonical reference server) would resolve.
Found this exact gap in cardano-rpc's `Cardano.Rpc.Server.Internal.Reflection.DescriptorTable` (`fileSymbolNames`/`messageSymbolNames`) during the grpc-reflection feature review, 2026-09-09.

**How to apply:** when reviewing any hand-rolled protobuf descriptor/symbol-table code (reflection servers, codegen, linters), check that enum VALUES get their own symbol entries at the enum's enclosing scope, separate from the enum TYPE's own entry - it's an easy category to forget since it's asymmetric with how messages/services nest (those DO use their own name as the prefix for their children).
